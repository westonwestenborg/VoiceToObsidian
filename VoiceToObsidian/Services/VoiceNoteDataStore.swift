import Foundation
import Combine
import OSLog

/// A service that manages the persistence and retrieval of voice notes.
///
/// `VoiceNoteDataStore` provides functionality for storing, loading, updating, and deleting
/// voice notes. It handles the serialization and deserialization of voice note data to and from disk,
/// and provides pagination support for efficiently loading large collections of notes.
///
/// The class is designed to work with the MVVM architecture and is marked with `@MainActor`
/// to ensure all UI updates happen on the main thread. It uses pagination to efficiently
/// load voice notes in batches, which improves performance when dealing with a large number of notes.
///
/// - Important: This class performs file I/O operations, which are potentially expensive.
///              These operations are performed on background threads to avoid blocking the UI.
///
/// ## Example Usage
/// ```swift
/// let dataStore = VoiceNoteDataStore(preloadData: true)
///
/// // Load voice notes
/// dataStore.loadMoreVoiceNotes()
///
/// // Add a new voice note
/// let newNote = VoiceNote(title: "Meeting Notes", transcript: "Discussed project timeline...")
/// dataStore.addVoiceNote(newNote)
///
/// // Update a voice note
/// var updatedNote = dataStore.voiceNotes[0]
/// updatedNote.title = "Updated Title"
/// dataStore.updateVoiceNote(updatedNote)
///
/// // Delete a voice note
/// dataStore.deleteVoiceNote(dataStore.voiceNotes[0])
/// ```
@MainActor
class VoiceNoteDataStore: ObservableObject {
    /// The collection of voice notes currently loaded in memory.
    ///
    /// This published property contains all voice notes that have been loaded from disk
    /// through pagination. UI components observe this property to display the notes.
    @Published var voiceNotes: [VoiceNote] = []
    
    /// Indicates whether voice notes are currently being loaded from disk.
    ///
    /// This property is used by UI components to show loading indicators when appropriate.
    @Published var isLoadingNotes: Bool = false
    
    /// Indicates whether all available voice notes have been loaded.
    ///
    /// When this is `true`, there are no more notes to load from disk. UI components
    /// can use this to determine whether to show a "Load More" button or indicator.
    @Published var loadedAllNotes: Bool = false
    
    // MARK: - Pagination Properties
    
    /// The current page of voice notes that has been loaded.
    ///
    /// This is used for pagination when loading notes from disk. The first page is 0.
    private var currentPage = 0
    
    /// The number of voice notes to load in each page.
    ///
    /// This determines how many notes are loaded at once when calling `loadMoreVoiceNotes()`.
    private let pageSize = 10
    
    /// A cached count of the total number of voice notes available on disk.
    ///
    /// This is used to estimate whether there are more notes to load without loading them all.
    private var cachedNoteCount: Int = 0
    
    /// Logger for structured logging of data store operations.
    ///
    /// Uses OSLog for efficient and structured logging throughout the data store operations.
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "VoiceNoteDataStore")
    
    // MARK: - Initialization
    
    /// Initializes a new VoiceNoteDataStore instance.
    ///
    /// - Parameter preloadData: If `true`, the initializer will check for the existence of
    ///                          voice notes on disk and cache metadata about them. It will not
    ///                          actually load the notes into memory until `loadMoreVoiceNotes()`
    ///                          is called. Default is `false`.
    init(preloadData: Bool = false) {
        logger.debug("VoiceNoteDataStore initialized")
        
        if preloadData {
            // Just check if we have notes, but don't load them yet
            Task(priority: .utility) {
                await checkVoiceNotesFileAsync()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Loads the next page of voice notes from disk.
    ///
    /// This method implements pagination to efficiently load voice notes in batches.
    /// It loads the next page of notes based on the current page and page size,
    /// and appends them to the `voiceNotes` array. If all notes have been loaded,
    /// it sets `loadedAllNotes` to `true`.
    ///
    /// - Note: This method does nothing if notes are currently being loaded or if
    ///         all notes have already been loaded.
    ///
    /// ## Example
    /// ```swift
    /// // Load the first page of notes
    /// dataStore.loadMoreVoiceNotes()
    ///
    /// // Later, load the next page
    /// if !dataStore.loadedAllNotes {
    ///     dataStore.loadMoreVoiceNotes()
    /// }
    /// ```
    func loadMoreVoiceNotes() {
        guard !isLoadingNotes && !loadedAllNotes else { return }
        
        isLoadingNotes = true
        
        Task(priority: .userInitiated) {
            await loadVoiceNotesPageAsync(page: currentPage)
            isLoadingNotes = false
        }
    }
    
    /// Resets pagination and reloads notes from the beginning.
    ///
    /// This method clears all currently loaded notes, resets the pagination state,
    /// and loads the first page of notes from disk. It's useful for refreshing the
    /// data when changes might have occurred outside the app.
    ///
    /// ## Example
    /// ```swift
    /// // Refresh notes after importing new ones from another source
    /// dataStore.refreshVoiceNotes()
    /// ```
    func refreshVoiceNotes() {
        currentPage = 0
        loadedAllNotes = false
        voiceNotes = []
        loadMoreVoiceNotes()
    }
    
    /// Adds a new voice note to the store and persists it to disk.
    ///
    /// This method adds the provided voice note to the in-memory collection and
    /// then saves all voice notes to disk. The note is added at the end of the
    /// collection.
    ///
    /// - Parameter voiceNote: The voice note to add
    ///
    /// ## Example
    /// ```swift
    /// let newNote = VoiceNote(title: "Meeting Notes", transcript: "Discussed project timeline...")
    /// dataStore.addVoiceNote(newNote)
    /// ```
    func addVoiceNote(_ voiceNote: VoiceNote) {
        voiceNotes.append(voiceNote)
        saveVoiceNotes()
    }
    
    /// Updates an existing voice note and persists the changes to disk.
    ///
    /// This method finds the voice note with the same ID as the provided note,
    /// replaces it with the updated version, and saves all voice notes to disk.
    /// If no note with the matching ID is found, this method does nothing.
    ///
    /// - Parameter voiceNote: The updated voice note
    ///
    /// ## Example
    /// ```swift
    /// var noteToUpdate = dataStore.voiceNotes[0]
    /// noteToUpdate.title = "Updated Title"
    /// dataStore.updateVoiceNote(noteToUpdate)
    /// ```
    func updateVoiceNote(_ voiceNote: VoiceNote) {
        if let index = voiceNotes.firstIndex(where: { $0.id == voiceNote.id }) {
            voiceNotes[index] = voiceNote
            saveVoiceNotes()
        }
    }
    
    /// Deletes a voice note and its associated audio file.
    ///
    /// This method removes the voice note from the in-memory collection,
    /// deletes the associated audio file from disk if it exists, and
    /// saves the updated collection to disk.
    ///
    /// - Parameter voiceNote: The voice note to delete
    ///
    /// - Note: This operation cannot be undone. The audio file is permanently deleted.
    ///
    /// ## Example
    /// ```swift
    /// // Delete the first voice note
    /// if !dataStore.voiceNotes.isEmpty {
    ///     dataStore.deleteVoiceNote(dataStore.voiceNotes[0])
    /// }
    /// ```
    func deleteVoiceNote(_ voiceNote: VoiceNote) {
        // Remove the audio file
        if let audioURL = voiceNote.audioURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        
        // Remove from the array and save
        if let index = voiceNotes.firstIndex(where: { $0.id == voiceNote.id }) {
            voiceNotes.remove(at: index)
            saveVoiceNotes()
        }
    }
    
    // MARK: - Private Methods
    
    /// Saves voice notes to disk asynchronously.
    ///
    /// This method creates a background task to save the current collection of voice notes
    /// to disk without blocking the main thread. It uses the `.utility` priority to
    /// indicate that this is a background operation that should not impact UI responsiveness.
    private func saveVoiceNotes() {
        Task(priority: .utility) {
            await saveVoiceNotesAsync()
        }
    }
    
    /// Performs the actual work of saving voice notes to disk asynchronously.
    ///
    /// This method serializes the voice notes array to JSON and writes it to a file
    /// in the app's documents directory. It uses `Task.detached` to avoid actor isolation
    /// when performing file I/O operations.
    ///
    /// - Note: This method updates the `cachedNoteCount` property after saving.
    private func saveVoiceNotesAsync() async {
        // Detach this task to avoid actor isolation when performing file I/O
        await Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(await self.voiceNotes)
                let url = await self.getVoiceNotesFileURL()
                try data.write(to: url)
                
                // Update cached count on the main actor
                await MainActor.run {
                    self.cachedNoteCount = self.voiceNotes.count
                }
                
                await self.logger.debug("Voice notes saved successfully")
            } catch {
                await self.logger.error("Failed to save voice notes: \(error.localizedDescription)")
            }
        }
    }
    
    /// Checks if the voice notes file exists and retrieves its metadata.
    ///
    /// This method is used during initialization with `preloadData: true` to check
    /// if voice notes exist on disk without actually loading them. It estimates the
    /// number of notes based on the file size and updates the `cachedNoteCount` property.
    ///
    /// - Note: This is a lightweight operation compared to actually loading the notes.
    private func checkVoiceNotesFileAsync() async {
        let url = await getVoiceNotesFileURL()
        
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? Int {
                    self.logger.debug("Voice notes file exists, size: \(fileSize) bytes")
                    
                    // Estimate number of notes based on file size
                    // This is a rough estimate - average note might be around 1KB
                    let estimatedCount = max(1, fileSize / 1024)
                    cachedNoteCount = estimatedCount
                }
            } catch {
                self.logger.error("Failed to get voice notes file attributes: \(error.localizedDescription)")
                cachedNoteCount = 0
            }
        } else {
            self.logger.info("No voice notes file found")
            cachedNoteCount = 0
        }
    }
    
    /// Loads a specific page of voice notes from disk asynchronously.
    ///
    /// This method implements the pagination logic for loading voice notes. It:
    /// 1. Reads the voice notes file from disk
    /// 2. Decodes all notes (future versions will implement true server-side pagination)
    /// 3. Extracts the subset of notes for the requested page
    /// 4. Updates the in-memory collection and pagination state
    ///
    /// - Parameter page: The zero-based page number to load
    ///
    /// - Note: This method updates the `loadedAllNotes` property if all notes have been loaded.
    private func loadVoiceNotesPageAsync(page: Int) async {
        await logger.debug("Loading voice notes page \(page)")
        let url = await getVoiceNotesFileURL()
        
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                // Use a file handle for more efficient reading
                let fileHandle = try FileHandle(forReadingFrom: url)
                let data = fileHandle.readDataToEndOfFile()
                try fileHandle.close()
                
                await self.logger.debug("Voice notes file size: \(data.count) bytes")
                
                // Decode all notes (we'll implement true pagination in a future version)
                let allNotes = try JSONDecoder().decode([VoiceNote].self, from: data)
                
                // Calculate pagination
                let startIndex = page * pageSize
                let endIndex = min(startIndex + pageSize, allNotes.count)
                
                // Check if we've reached the end
                if startIndex >= allNotes.count {
                    await MainActor.run {
                        self.loadedAllNotes = true
                    }
                    return
                }
                
                // Get the subset of notes for this page
                let pageNotes = Array(allNotes[startIndex..<endIndex])
                
                await MainActor.run {
                    // Append to existing notes
                    self.voiceNotes.append(contentsOf: pageNotes)
                    self.currentPage += 1
                    
                    // Check if we've loaded all notes
                    if endIndex >= allNotes.count {
                        self.loadedAllNotes = true
                    }
                    
                    self.logger.info("Loaded page \(page) with \(pageNotes.count) notes. Total: \(self.voiceNotes.count)")
                }
            } catch {
                await self.logger.error("Failed to load voice notes: \(error.localizedDescription)")
                await MainActor.run {
                    self.loadedAllNotes = true
                }
            }
        } else {
            await self.logger.info("No voice notes file found")
            await MainActor.run {
                self.loadedAllNotes = true
            }
        }
    }
    
    /// Gets the URL for the voice notes file in the app's documents directory.
    ///
    /// This method returns the URL where voice notes are stored on disk. It creates
    /// a consistent location in the app's documents directory for storing the notes.
    ///
    /// - Returns: The URL for the voice notes JSON file
    private func getVoiceNotesFileURL() async -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("voiceNotes.json")
    }
}
