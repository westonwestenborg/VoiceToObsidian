import Foundation
import Combine
import SwiftUI
import OSLog

/// VoiceNoteStore is responsible for managing the data storage of voice notes.
/// It handles reading/writing voiceNotes.json and retains an array of VoiceNote objects,
/// but does not handle recording or transcription.
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
            DispatchQueue.global(qos: .utility).async { [weak self] in
                autoreleasepool {
                    guard let self = self else { return }
                    // Just check if file exists and get metadata
                    self.checkVoiceNotesFile()
                    
                    DispatchQueue.main.async {
                        self.hasInitialized = true
                        print("VoiceNoteStore initialized with metadata only")
                    }
                }
            }
        }
    }
    
    private func performDeferredInitialization() {
        print("Performing deferred initialization")
        guard !hasInitialized else { 
            print("Already initialized, skipping")
            return 
        }
        
        // Just check if we have notes, but don't load them yet
        checkVoiceNotesFile()
        
        hasInitialized = true
        print("Deferred initialization complete")
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
        
        // First, ensure we notify UI that loading has started
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            autoreleasepool {
                guard let self = self else { return }
                
                // Ensure initialization is complete
                if !self.hasInitialized {
                    self.performDeferredInitialization()
                }
                
                self.loadVoiceNotesPage(page: self.currentPage)
                
                // Ensure we update the UI on the main thread
                DispatchQueue.main.async {
                    self.isLoadingNotes = false
                    // Force another UI update when loading completes
                    self.objectWillChange.send()
                    self.logger.debug("Voice notes loading complete, sent objectWillChange notification")
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
    
    // MARK: - Persistence
    
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
                    print("Failed to save voice notes: \(error.localizedDescription)")
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
                    print("Voice notes file exists, size: \(fileSize) bytes")
                    
                    // Estimate number of notes based on file size
                    // This is a rough estimate - average note might be around 1KB
                    let estimatedCount = max(1, fileSize / 1024)
                    cachedNoteCount = estimatedCount
                }
            } catch {
                print("Failed to get voice notes file attributes: \(error.localizedDescription)")
                cachedNoteCount = 0
            }
        } else {
            print("No voice notes file found")
            cachedNoteCount = 0
        }
    }
    
    /// Loads a specific page of voice notes
    private func loadVoiceNotesPage(page: Int) {
        print("Loading voice notes page \(page)")
        let url = getVoiceNotesFileURL()
        
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                // Use a file handle for more efficient reading
                let fileHandle = try FileHandle(forReadingFrom: url)
                let data = fileHandle.readDataToEndOfFile()
                try fileHandle.close()
                
                print("Voice notes file size: \(data.count) bytes")
                
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
                    
                    self.logger.debug("Loaded page \(page) with \(pageNotes.count) notes. Total: \(self.voiceNotes.count)")
                    
                    // Force UI update by triggering objectWillChange
                    self.objectWillChange.send()
                }
            } catch {
                print("Failed to load voice notes: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.loadedAllNotes = true
                }
            }
        } else {
            print("No voice notes file found")
            DispatchQueue.main.async { [weak self] in
                self?.loadedAllNotes = true
            }
        }
    }
    
    private func getVoiceNotesFileURL() -> URL {
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
