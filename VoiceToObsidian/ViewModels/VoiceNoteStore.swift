import Foundation
import Combine
import SwiftUI
import OSLog

/// VoiceNoteStore is responsible for managing the data storage of voice notes.
/// It handles reading/writing voiceNotes.json and retains an array of VoiceNote objects,
/// but does not handle recording or transcription.
@MainActor
class VoiceNoteStore: ObservableObject, ErrorHandling {
    @Published var voiceNotes: [VoiceNote] = []
    @Published var isLoadingNotes: Bool = false
    @Published var loadedAllNotes: Bool = false
    
    // Error handling properties
    @Published var errorState: AppError?
    @Published var isShowingError: Bool = false
    
    // Logger for VoiceNoteStore
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "VoiceNoteStore")
    
    // Track whether we've completed initialization
    private var hasInitialized = false
    
    // Pagination parameters
    private var currentPage = 0
    private let pageSize = 10
    private var cachedNoteCount: Int = 0
    
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
    
    // MARK: - Voice Note Management
    
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
    
    /// Loads the next page of voice notes
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
    
    /// Resets pagination and reloads notes from the beginning
    func refreshVoiceNotes() {
        currentPage = 0
        loadedAllNotes = false
        voiceNotes = []
        loadMoreVoiceNotes()
    }
    
    // MARK: - Persistence
    
    private func saveVoiceNotes() {
        Task(priority: .utility) {
            do {
                try await saveVoiceNotesAsync()
            } catch {
                await logger.error("Failed to save voice notes: \(error.localizedDescription)")
            }
        }
    }
    
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
    
    /// Just checks if the voice notes file exists and gets its metadata
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
    
    /// Loads a specific page of voice notes asynchronously
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
    
    private func getVoiceNotesFileURL() async -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("voiceNotes.json")
    }
    
    // MARK: - Voice Note Addition
    
    /// Adds a new voice note to the store and saves it
    func addVoiceNote(_ voiceNote: VoiceNote) {
        voiceNotes.insert(voiceNote, at: 0) // Add to beginning of array
        saveVoiceNotes()
    }
}
