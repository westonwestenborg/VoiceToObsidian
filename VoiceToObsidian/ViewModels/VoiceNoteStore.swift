import Foundation
import Combine
import SwiftUI
import OSLog

/// A data store responsible for managing the persistence and retrieval of voice notes.
///
/// `VoiceNoteStore` handles the complete lifecycle of voice note data persistence, including:
/// - Loading voice notes from disk with pagination support
/// - Saving voice notes to disk
/// - Adding new voice notes to the collection
/// - Deleting voice notes and their associated files
/// - Managing the in-memory cache of voice notes
///
/// This class is designed to be efficient with memory and disk operations by implementing:
/// - Lazy initialization to defer loading until needed
/// - Pagination to load voice notes in batches
/// - Asynchronous I/O operations using Swift concurrency
/// - Task detachment for file operations to avoid actor isolation issues
///
/// The store does not handle recording or transcription - it focuses solely on data persistence.
///
/// ## Example Usage
/// ```swift
/// // Create a store with lazy initialization
/// let store = VoiceNoteStore(lazyInit: true)
///
/// // Load the first page of voice notes
/// store.loadMoreVoiceNotes()
///
/// // Add a new voice note
/// store.addVoiceNote(newVoiceNote)
///
/// // Delete a voice note
/// store.deleteVoiceNote(existingVoiceNote)
/// ```
@MainActor
class VoiceNoteStore: ObservableObject, ErrorHandling {
    /// The collection of voice notes currently loaded in memory.
    ///
    /// This property is marked with `@Published` to notify SwiftUI views when the
    /// collection changes. It's populated incrementally through pagination as the
    /// user requests more voice notes.
    @Published var voiceNotes: [VoiceNote] = []
    
    /// Indicates whether voice notes are currently being loaded from disk.
    ///
    /// This property is marked with `@Published` to allow UI components to show
    /// loading indicators when appropriate.
    @Published var isLoadingNotes: Bool = false
    
    /// Indicates whether all available voice notes have been loaded.
    ///
    /// This property is marked with `@Published` and becomes `true` when the store
    /// has loaded all available voice notes from disk. UI components can use this
    /// to determine whether to show "Load More" buttons or indicators.
    @Published var loadedAllNotes: Bool = false
    
    // MARK: - Error Handling Properties
    
    /// The current error state, if any.
    ///
    /// Part of the `ErrorHandling` protocol. This property holds the current error
    /// that needs to be displayed to the user.
    @Published var errorState: AppError?
    
    /// Indicates whether an error is currently being shown to the user.
    ///
    /// Part of the `ErrorHandling` protocol. This property controls the visibility
    /// of error UI components like alerts or banners.
    @Published var isShowingError: Bool = false
    
    // MARK: - Logging
    
    /// Logger for structured logging of store operations.
    ///
    /// This logger uses the OSLog system for efficient and structured logging
    /// of data operations, errors, and loading events.
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "VoiceNoteStore")
    
    // MARK: - State Management
    
    /// Tracks whether initialization has been completed.
    ///
    /// This flag helps implement lazy initialization by tracking whether the store
    /// has already checked for existing voice notes files and metadata.
    private var hasInitialized = false
    
    // MARK: - Pagination
    
    /// The current page of voice notes being displayed.
    ///
    /// This counter is incremented each time a new page of voice notes is loaded,
    /// starting from 0 for the first page.
    private var currentPage = 0
    
    /// The number of voice notes to load in each pagination request.
    ///
    /// This constant defines how many voice notes are loaded at once when the user
    /// requests more notes. A smaller value improves initial load time but requires
    /// more frequent loading operations.
    private let pageSize = 10
    
    /// The estimated total number of voice notes available on disk.
    ///
    /// This value is used to provide hints to the UI about how many notes exist
    /// without loading them all into memory.
    private var cachedNoteCount: Int = 0
    
    /// Initializes a new VoiceNoteStore instance.
    ///
    /// This initializer provides several options for how the store should be initialized:
    /// - With sample data for previews and testing
    /// - With lazy initialization that defers all work until explicitly needed
    /// - With standard initialization that checks for existing files but doesn't load them yet
    ///
    /// The lazy initialization option is particularly useful when the store is created
    /// as part of a larger component (like a coordinator) but might not be immediately used.
    ///
    /// - Parameters:
    ///   - previewData: If `true`, initializes the store with sample voice notes for previews.
    ///     Default is `false`.
    ///   - lazyInit: If `true`, defers all initialization until voice notes are explicitly
    ///     requested. Default is `false`.
    ///
    /// ## Example
    /// ```swift
    /// // For UI previews
    /// let previewStore = VoiceNoteStore(previewData: true)
    ///
    /// // For production use with lazy initialization
    /// let store = VoiceNoteStore(lazyInit: true)
    /// ```
    init(previewData: Bool = false, lazyInit: Bool = false) {
        logger.debug("VoiceNoteStore initialization started")
        
        if previewData {
            voiceNotes = VoiceNote.sampleNotes
            hasInitialized = true
            logger.debug("VoiceNoteStore initialized with preview data")
        } else if lazyInit {
            // Super lazy initialization - do nothing until explicitly needed
            logger.debug("VoiceNoteStore using lazy initialization")
            // We'll load notes only when they're requested
        } else {
            // Only check if we have notes, but don't load them yet
            Task(priority: .utility) {
                await checkVoiceNotesFileAsync()
                hasInitialized = true
                logger.debug("VoiceNoteStore initialized with metadata only")
            }
        }
    }
    
    /// Performs initialization that was deferred during object creation.
    ///
    /// This private method is called when voice notes are requested but the store
    /// was created with lazy initialization. It checks for existing voice note files
    /// and gathers metadata about them without actually loading the notes into memory.
    ///
    /// The method is idempotent - it checks the `hasInitialized` flag to ensure
    /// initialization is only performed once.
    ///
    /// - Returns: Void
    private func performDeferredInitialization() async {
        logger.debug("Performing deferred initialization")
        guard !hasInitialized else { 
            logger.debug("Already initialized, skipping")
            return 
        }
        
        // Just check if we have notes, but don't load them yet
        await checkVoiceNotesFileAsync()
        
        hasInitialized = true
        logger.debug("Deferred initialization complete")
    }
    
    // MARK: - Voice Note Management
    
    /// Deletes a voice note and its associated files.
    ///
    /// This method removes a voice note from both memory and persistent storage.
    /// It performs the following operations:
    /// - Deletes the associated audio file from the file system if it exists
    /// - Removes the voice note from the in-memory collection
    /// - Persists the updated collection to disk
    ///
    /// - Parameter voiceNote: The voice note to delete
    ///
    /// ## Example
    /// ```swift
    /// // Delete a voice note when the user confirms deletion
    /// store.deleteVoiceNote(selectedVoiceNote)
    /// ```
    func deleteVoiceNote(_ voiceNote: VoiceNote) {
        // Remove the audio file
        if let audioURL = voiceNote.audioURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        
        // TODO: Remove the Obsidian note if it exists
        
        // Remove from the array and save
        if let index = voiceNotes.firstIndex(where: { $0.id == voiceNote.id }) {
            voiceNotes.remove(at: index)
            saveVoiceNotes()
        }
    }
    
    // MARK: - Pagination and Loading
    
    /// Loads the next page of voice notes from persistent storage.
    ///
    /// This method implements pagination to efficiently load voice notes in batches.
    /// It performs the following operations:
    /// - Checks if loading is already in progress or if all notes have been loaded
    /// - Performs deferred initialization if needed
    /// - Loads the next page of voice notes asynchronously
    /// - Updates the UI state when loading completes
    ///
    /// The method is designed to be called when the user scrolls near the end of the
    /// current list of voice notes or explicitly requests to load more notes.
    ///
    /// ## Example
    /// ```swift
    /// // When user scrolls to bottom of list
    /// if !store.loadedAllNotes {
    ///     store.loadMoreVoiceNotes()
    /// }
    /// ```
    func loadMoreVoiceNotes() {
        guard !isLoadingNotes && !loadedAllNotes else { return }
        
        isLoadingNotes = true
        logger.debug("Starting to load more voice notes")
        
        // Notify UI that loading has started
        objectWillChange.send()
        
        Task(priority: .userInitiated) {
            // Ensure initialization is complete
            if !hasInitialized {
                await performDeferredInitialization()
            }
            
            await loadVoiceNotesPageAsync(page: currentPage)
            
            // Update UI state
            isLoadingNotes = false
            // Force another UI update when loading completes
            objectWillChange.send()
            logger.debug("Voice notes loading complete, sent objectWillChange notification")
        }
    }
    
    /// Resets pagination and reloads voice notes from the beginning.
    ///
    /// This method provides a way to completely refresh the voice notes collection.
    /// It performs the following operations:
    /// - Resets the pagination state to start from the first page
    /// - Clears the current in-memory collection of voice notes
    /// - Initiates loading of the first page of voice notes
    ///
    /// This is useful when the underlying data may have changed outside of the normal
    /// app flow, or when the user explicitly requests a refresh.
    ///
    /// ## Example
    /// ```swift
    /// // When user pulls to refresh
    /// store.refreshVoiceNotes()
    /// ```
    func refreshVoiceNotes() {
        currentPage = 0
        loadedAllNotes = false
        voiceNotes = []
        loadMoreVoiceNotes()
    }
    
    // MARK: - Persistence
    
    /// Saves the current collection of voice notes to persistent storage.
    ///
    /// This method creates a background task to asynchronously save the voice notes
    /// collection to disk. It uses a utility priority to minimize impact on UI performance
    /// and delegates to the async version of the save method for the actual file operations.
    ///
    /// Any errors during the save operation are logged but not propagated to the caller,
    /// as this method is typically called as part of other operations where immediate
    /// error handling isn't required.
    private func saveVoiceNotes() {
        Task(priority: .utility) {
            do {
                try await saveVoiceNotesAsync()
            } catch {
                await logger.error("Failed to save voice notes: \(error.localizedDescription)")
            }
        }
    }
    
    /// Asynchronously saves the voice notes collection to disk.
    ///
    /// This method handles the actual file I/O operations for saving voice notes.
    /// It detaches a task to perform the file operations outside of the actor context,
    /// which avoids potential deadlocks when performing blocking I/O operations.
    ///
    /// The method performs the following operations:
    /// - Encodes the voice notes collection to JSON data
    /// - Writes the data to the voice notes file
    /// - Updates the cached note count for future reference
    ///
    /// - Throws: An error if encoding or writing to disk fails
    private func saveVoiceNotesAsync() async throws {
        // Detach this task to avoid actor isolation when performing file I/O
        try await Task.detached(priority: .utility) {
            let data = try JSONEncoder().encode(await MainActor.run { return self.voiceNotes })
            let url = await self.getVoiceNotesFileURL()
            try data.write(to: url)
            
            // Update cached count on the main actor
            await MainActor.run {
                self.cachedNoteCount = self.voiceNotes.count
            }
        }.value
    }
    
    /// Checks if the voice notes file exists and gathers metadata about it.
    ///
    /// This method is part of the lazy initialization process. It checks for the
    /// existence of the voice notes file and estimates the number of notes based on
    /// the file size, without actually loading the notes into memory.
    ///
    /// The method detaches a task to perform the file operations outside of the actor
    /// context, which avoids potential deadlocks when performing blocking I/O operations.
    private func checkVoiceNotesFileAsync() async {
        // Detach this task to avoid actor isolation when performing file I/O
        await Task.detached(priority: .utility) {
            let url = await self.getVoiceNotesFileURL()
            
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    if let fileSize = attributes[.size] as? Int {
                        self.logger.debug("Voice notes file exists, size: \(fileSize) bytes")
                        
                        // Estimate number of notes based on file size
                        // This is a rough estimate - average note might be around 1KB
                        let estimatedCount = max(1, fileSize / 1024)
                        
                        // Update on the main actor
                        await MainActor.run {
                            self.cachedNoteCount = estimatedCount
                        }
                    }
                } catch {
                    await self.logger.error("Failed to get voice notes file attributes: \(error.localizedDescription)")
                    // Update on the main actor
                    await MainActor.run {
                        self.cachedNoteCount = 0
                    }
                }
            } else {
                await self.logger.info("No voice notes file found")
                // Update on the main actor
                await MainActor.run {
                    self.cachedNoteCount = 0
                }
            }
        }
    }
    
    /// Loads a specific page of voice notes asynchronously from disk.
    ///
    /// This method implements the core pagination functionality for loading voice notes.
    /// It detaches a task to perform the file operations outside of the actor context,
    /// which avoids potential deadlocks when performing blocking I/O operations.
    ///
    /// The method performs the following operations:
    /// - Reads the voice notes file from disk
    /// - Decodes all voice notes (future versions will implement true server-side pagination)
    /// - Calculates the subset of notes for the requested page
    /// - Updates the in-memory collection with the loaded notes
    /// - Updates pagination state and UI
    ///
    /// - Parameter page: The zero-based page number to load
    private func loadVoiceNotesPageAsync(page: Int) async {
        await logger.debug("Loading voice notes page \(page)")
        
        // Detach this task to avoid actor isolation when performing file I/O
        let pageSize = self.pageSize // Capture this value before detaching
        await Task.detached(priority: .userInitiated) {
            let url = await self.getVoiceNotesFileURL()
            
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
                    let startIndex = page * self.pageSize
                    let endIndex = min(startIndex + self.pageSize, allNotes.count)
                    
                    // Check if we've reached the end
                    if startIndex >= allNotes.count {
                        // Update on the main actor
                        await MainActor.run {
                            self.loadedAllNotes = true
                        }
                        return
                    }
                    
                    // Get the subset of notes for this page
                    let pageNotes = Array(allNotes[startIndex..<endIndex])
                    
                    // Since we're already on the MainActor class, we can directly update properties
                    // We need to use MainActor.run to update properties from a detached task
                    await MainActor.run {
                        // Clear and reload if this is the first page
                        if page == 0 {
                            self.voiceNotes = pageNotes
                        } else {
                            // Append to existing notes for subsequent pages
                            self.voiceNotes.append(contentsOf: pageNotes)
                        }
                        
                        self.currentPage += 1
                        
                        // Check if we've loaded all notes
                        if endIndex >= allNotes.count {
                            self.loadedAllNotes = true
                        }
                        
                        // Force UI update by triggering objectWillChange
                        self.objectWillChange.send()
                    }
                    
                    // Get the count safely after updating
                    let notesCount = await MainActor.run { return self.voiceNotes.count }
                    await self.logger.debug("Loaded page \(page) with \(pageNotes.count) notes. Total: \(notesCount)")
                } catch {
                    await self.logger.error("Failed to load voice notes: \(error.localizedDescription)")
                    
                    // Update directly since we're on MainActor
                    await MainActor.run {
                        self.loadedAllNotes = true
                    }
                }
            } else {
                await self.logger.info("No voice notes file found")
                
                // Update directly since we're on MainActor
                await MainActor.run {
                    self.loadedAllNotes = true
                }
            }
        }
    }
    
    /// Gets the URL for the voice notes JSON file.
    ///
    /// This method returns the URL where voice notes are stored in the app's documents directory.
    /// It's marked as async to maintain consistency with other file operation methods,
    /// even though the operation itself is synchronous.
    ///
    /// - Returns: The URL for the voice notes JSON file
    private func getVoiceNotesFileURL() async -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("voiceNotes.json")
    }
    
    // MARK: - Voice Note Addition
    
    /// Adds a new voice note to the store and saves it to persistent storage.
    ///
    /// This method adds a new voice note to the beginning of the collection (so it
    /// appears first in chronological lists) and then persists the updated collection
    /// to disk.
    ///
    /// - Parameter voiceNote: The voice note to add to the collection
    ///
    /// ## Example
    /// ```swift
    /// // After creating and processing a new voice note
    /// store.addVoiceNote(newVoiceNote)
    /// ```
    func addVoiceNote(_ voiceNote: VoiceNote) {
        voiceNotes.insert(voiceNote, at: 0) // Add to beginning of array
        saveVoiceNotes()
    }
}
