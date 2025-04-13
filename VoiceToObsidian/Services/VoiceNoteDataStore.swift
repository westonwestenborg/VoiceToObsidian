import Foundation
import Combine
import OSLog

/// Manages persistence and retrieval of voice notes
class VoiceNoteDataStore: ObservableObject {
    // Published properties for UI updates
    @Published var voiceNotes: [VoiceNote] = []
    @Published var isLoadingNotes: Bool = false
    @Published var loadedAllNotes: Bool = false
    
    // Pagination parameters
    private var currentPage = 0
    private let pageSize = 10
    private var cachedNoteCount: Int = 0
    
    // Logger for VoiceNoteDataStore
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "VoiceNoteDataStore")
    
    // Initializer
    init(preloadData: Bool = false) {
        logger.debug("VoiceNoteDataStore initialized")
        
        if preloadData {
            // Just check if we have notes, but don't load them yet
            DispatchQueue.global(qos: .utility).async { [weak self] in
                autoreleasepool {
                    self?.checkVoiceNotesFile()
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Loads the next page of voice notes
    func loadMoreVoiceNotes() {
        guard !isLoadingNotes && !loadedAllNotes else { return }
        
        isLoadingNotes = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            autoreleasepool {
                guard let self = self else { return }
                
                self.loadVoiceNotesPage(page: self.currentPage)
                
                DispatchQueue.main.async {
                    self.isLoadingNotes = false
                }
            }
        }
    }
    
    /// Resets pagination and reloads notes from the beginning
    func refreshVoiceNotes() {
        currentPage = 0
        loadedAllNotes = false
        voiceNotes = []
        loadMoreVoiceNotes()
    }
    
    /// Adds a new voice note to the store
    /// - Parameter voiceNote: The voice note to add
    func addVoiceNote(_ voiceNote: VoiceNote) {
        voiceNotes.append(voiceNote)
        saveVoiceNotes()
    }
    
    /// Updates an existing voice note
    /// - Parameter voiceNote: The voice note to update
    func updateVoiceNote(_ voiceNote: VoiceNote) {
        if let index = voiceNotes.firstIndex(where: { $0.id == voiceNote.id }) {
            voiceNotes[index] = voiceNote
            saveVoiceNotes()
        }
    }
    
    /// Deletes a voice note
    /// - Parameter voiceNote: The voice note to delete
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
    
    /// Saves voice notes to disk
    private func saveVoiceNotes() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            autoreleasepool {
                guard let self = self else { return }
                
                do {
                    let data = try JSONEncoder().encode(self.voiceNotes)
                    let url = self.getVoiceNotesFileURL()
                    try data.write(to: url)
                    
                    // Update cached count
                    self.cachedNoteCount = self.voiceNotes.count
                } catch {
                    self.logger.error("Failed to save voice notes: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Just checks if the voice notes file exists and gets its metadata
    private func checkVoiceNotesFile() {
        let url = getVoiceNotesFileURL()
        
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
    
    /// Loads a specific page of voice notes
    private func loadVoiceNotesPage(page: Int) {
        logger.debug("Loading voice notes page \(page)")
        let url = getVoiceNotesFileURL()
        
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                // Use a file handle for more efficient reading
                let fileHandle = try FileHandle(forReadingFrom: url)
                let data = fileHandle.readDataToEndOfFile()
                try fileHandle.close()
                
                self.logger.debug("Voice notes file size: \(data.count) bytes")
                
                // Decode all notes (we'll implement true pagination in a future version)
                let allNotes = try JSONDecoder().decode([VoiceNote].self, from: data)
                
                // Calculate pagination
                let startIndex = page * pageSize
                let endIndex = min(startIndex + pageSize, allNotes.count)
                
                // Check if we've reached the end
                if startIndex >= allNotes.count {
                    DispatchQueue.main.async { [weak self] in
                        self?.loadedAllNotes = true
                    }
                    return
                }
                
                // Get the subset of notes for this page
                let pageNotes = Array(allNotes[startIndex..<endIndex])
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
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
                self.logger.error("Failed to load voice notes: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.loadedAllNotes = true
                }
            }
        } else {
            self.logger.info("No voice notes file found")
            DispatchQueue.main.async { [weak self] in
                self?.loadedAllNotes = true
            }
        }
    }
    
    /// Gets the URL for the voice notes file
    private func getVoiceNotesFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("voiceNotes.json")
    }
}
