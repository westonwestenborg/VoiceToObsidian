import Foundation
import Combine
import SwiftUI
import Security
import AVFoundation
import OSLog

/// Coordinates all voice note operations and services
class VoiceNoteCoordinator: ObservableObject, ErrorHandling {
    // Published properties for UI updates
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var transcriptionProgress: Float = 0
    
    // Error handling properties
    @Published var errorState: AppError?
    @Published var isShowingError: Bool = false
    
    // Backing variables for lazy services
    private var _recordingManager: RecordingManager?
    private var _transcriptionManager: TranscriptionManager?
    private var _dataStore: VoiceNoteDataStore?
    private var _anthropicService: AnthropicService?
    private var _obsidianService: ObsidianService?
    
    // Lazy services - only initialized when needed
    private var recordingManager: RecordingManager {
        if _recordingManager == nil {
            print("Lazily creating RecordingManager")
            _recordingManager = RecordingManager()
        }
        return _recordingManager!
    }
    
    private var transcriptionManager: TranscriptionManager {
        if _transcriptionManager == nil {
            print("Lazily creating TranscriptionManager")
            _transcriptionManager = TranscriptionManager()
        }
        return _transcriptionManager!
    }
    
    private var dataStore: VoiceNoteDataStore {
        if _dataStore == nil {
            print("Lazily creating VoiceNoteDataStore")
            _dataStore = VoiceNoteDataStore(preloadData: false)
        }
        return _dataStore!
    }
    
    private var anthropicService: AnthropicService {
        if _anthropicService == nil {
            print("Lazily creating AnthropicService")
            _anthropicService = AnthropicService(apiKey: anthropicAPIKey)
        }
        return _anthropicService!
    }
    
    private var obsidianService: ObsidianService {
        if _obsidianService == nil {
            print("Lazily creating ObsidianService")
            _obsidianService = ObsidianService(vaultPath: obsidianVaultPath)
        }
        return _obsidianService!
    }
    
    // Logger for VoiceNoteCoordinator
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "VoiceNoteCoordinator")
    
    // Configuration
    private var anthropicAPIKey: String = "" {
        didSet {
            logger.debug("API key updated")
            anthropicService.updateAPIKey(anthropicAPIKey)
            
            // Store API key securely using SecurityManager
            do {
                try SecurityManager.storeAnthropicAPIKey(anthropicAPIKey)
            } catch {
                logger.error("Failed to save API key to keychain: \(error.localizedDescription)")
                self.handleError(AppError.keychain(.unexpectedStatus(0)))
            }
        }
    }
    
    private var obsidianVaultPath: String = "" {
        didSet {
            logger.debug("Vault path updated")
            obsidianService.updateVaultPath(obsidianVaultPath)
            
            // Store vault path using SecurityManager
            do {
                try SecurityManager.storeObsidianVaultPath(obsidianVaultPath)
            } catch {
                logger.error("Failed to save vault path to keychain: \(error.localizedDescription)")
                self.handleError(AppError.keychain(.unexpectedStatus(0)))
            }
        }
    }
    
    private var obsidianVaultBookmark: Data?
    
    // Cancellables for Combine subscriptions
    var cancellables = Set<AnyCancellable>()
    
    // Initializer
    init(loadImmediately: Bool = false) {
        logger.debug("VoiceNoteCoordinator initialization started - minimal setup only")
        
        // Initialize stored properties first
        // Retrieve configuration values using SecurityManager
        do {
            self.anthropicAPIKey = try SecurityManager.retrieveAnthropicAPIKey()
        } catch {
            logger.error("Failed to retrieve API key: \(error.localizedDescription)")
            self.anthropicAPIKey = ""  // Use empty string as fallback
        }
        
        // Get vault path using SecurityManager
        do {
            self.obsidianVaultPath = try SecurityManager.retrieveObsidianVaultPath()
        } catch {
            logger.error("Failed to retrieve vault path: \(error.localizedDescription)")
            self.obsidianVaultPath = ""
        }
        
        // If requested, preload services - normally we don't do this
        if loadImmediately {
            print("Preloading services as requested (not recommended)")
            // Force initialization of services
            _ = recordingManager
            _ = transcriptionManager
            _ = dataStore
            _ = anthropicService
            _ = obsidianService
            
            // Set up bindings between services
            setupBindings()
        }
        
        print("VoiceNoteCoordinator initialized - services will load on demand")
    }
    
    // This method is no longer needed - initialization moved to init()
    
    // This method is no longer needed - preloading moved to init()
    
    // MARK: - Public Methods - Recording
    
    /// Starts recording a voice note
    /// - Parameter completion: Completion handler with success status and error if any
    func startRecording(completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        guard !isRecording && !isProcessing else {
            let error = AppError.recording(.recordingFailed("Recording or processing already in progress"))
            handleError(error)
            completion(false, error)
            return
        }
        
        // Ensure bindings are set up before recording
        if cancellables.isEmpty {
            setupBindings()
        }
        
        recordingManager.startRecording { [weak self] success in
            guard let self = self else { return }
            
            if success {
                self.isRecording = true
                completion(true, nil)
            } else {
                // Handle recording failure
                let error = AppError.recording(.recordingFailed("Failed to start recording"))
                self.handleError(error)
                print("Failed to start recording")
                completion(false, error)
            }
        }
    }
    
    /// Stops recording and processes the voice note
    /// - Parameter completion: Completion handler with success status and error if any
    func stopRecording(completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        guard isRecording else {
            let error = AppError.recording(.recordingFailed("Not currently recording"))
            handleError(error)
            completion(false, error)
            return
        }
        
        guard !isProcessing else {
            let error = AppError.recording(.recordingFailed("Already processing a recording"))
            handleError(error)
            completion(false, error)
            return
        }
        
        isProcessing = true
        
        recordingManager.stopRecording { [weak self] success, recordingURL, duration in
            guard let self = self else { return }
            
            if !success || recordingURL == nil {
                self.isProcessing = false
                let error = AppError.recording(.recordingFailed("Failed to stop recording or no recording URL"))
                self.handleError(error)
                completion(false, error)
                return
            }
            
            self.isRecording = false
            self.processRecording(recordingURL: recordingURL!, duration: duration) { success, error in
                completion(success, error)
            }
        }
    }
    
    // MARK: - Public Methods - Voice Notes
    
    /// Loads more voice notes (pagination)
    func loadMoreVoiceNotes() {
        dataStore.loadMoreVoiceNotes()
    }
    
    /// Refreshes the voice notes list
    func refreshVoiceNotes() {
        dataStore.refreshVoiceNotes()
    }
    
    /// Deletes a voice note
    /// - Parameter voiceNote: The voice note to delete
    func deleteVoiceNote(_ voiceNote: VoiceNote) {
        dataStore.deleteVoiceNote(voiceNote)
    }
    
    // MARK: - Public Methods - Configuration
    
    /// Sets the Anthropic API key
    /// - Parameter key: The API key
    func setAnthropicAPIKey(_ key: String) {
        anthropicAPIKey = key
    }
    
    /// Clears the Anthropic API key securely
    func clearAnthropicAPIKey() {
        do {
            try KeychainManager.deleteString(forKey: "AnthropicAPIKey")
            anthropicAPIKey = ""
            anthropicService.updateAPIKey("")
            print("API key cleared successfully")
        } catch {
            print("Failed to clear API key: \(error)")
        }
    }
    
    /// Sets the Obsidian vault path
    /// - Parameter path: The path to the Obsidian vault
    func setObsidianVaultPath(_ path: String) {
        obsidianVaultPath = path
    }
    
    /// Clears the Obsidian vault path
    func clearObsidianVaultPath() {
        do {
            try KeychainManager.deleteString(forKey: "ObsidianVaultPath")
            UserDefaults.standard.removeObject(forKey: "ObsidianVaultPath")
            obsidianVaultPath = ""
            obsidianService.updateVaultPath("")
            print("Vault path cleared successfully")
        } catch {
            print("Failed to clear vault path: \(error)")
        }
    }
    
    /// Clears all sensitive data from the app (API keys, vault paths, bookmarks)
    /// - Parameter completion: Optional completion handler called when the operation is complete
    func clearAllSensitiveData(completion: (() -> Void)? = nil) {
        // Clear all data from keychain
        let errors = KeychainManager.clearAllSensitiveData()
        
        // Also clear from UserDefaults for backward compatibility
        UserDefaults.standard.removeObject(forKey: "ObsidianVaultPath")
        UserDefaults.standard.removeObject(forKey: "ObsidianVaultBookmark")
        
        // Update local properties
        anthropicAPIKey = ""
        obsidianVaultPath = ""
        
        // Update services
        anthropicService.updateAPIKey("")
        obsidianService.updateVaultPath("")
        
        if !errors.isEmpty {
            print("Some errors occurred while clearing sensitive data: \(errors)")
        } else {
            print("All sensitive data cleared successfully")
        }
        
        completion?()
    }
    
    // MARK: - Private Methods
    
    /// Sets up bindings between services using Combine
    private func setupBindings() {
        // Forward recording duration updates
        recordingManager.$recordingDuration
            .receive(on: RunLoop.main)
            .assign(to: \.recordingDuration, on: self)
            .store(in: &cancellables)
        
        // Forward transcription progress updates
        transcriptionManager.$transcriptionProgress
            .receive(on: RunLoop.main)
            .assign(to: \.transcriptionProgress, on: self)
            .store(in: &cancellables)
    }
    
    /// Processes a recording by transcribing it, cleaning it with Claude, and saving it
    /// - Parameters:
    ///   - recordingURL: The URL of the recording
    ///   - duration: The duration of the recording
    private func processRecording(recordingURL: URL, duration: TimeInterval, completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        // Step 1: Transcribe the recording
        transcriptionManager.transcribeAudioFile(at: recordingURL) { [weak self] success, transcript in
            guard let self = self else { return }
            
            if !success || transcript == nil {
                // Handle transcription failure
                print("Transcription failed")
                self.isProcessing = false
                
                let error = AppError.transcription(.fileTranscriptionFailed("Failed to transcribe audio file"))
                self.handleError(error)
                completion(false, error)
                
                // Use a fallback transcript
                let fallbackTranscript = "This is a fallback transcript. The actual speech recognition failed. Please check your microphone permissions and try again."
                self.processTranscriptWithClaude(
                    recordingURL: recordingURL,
                    transcript: fallbackTranscript,
                    duration: duration,
                    completion: completion
                )
            } else {
                // Step 2: Process with Claude API
                self.processTranscriptWithClaude(
                    recordingURL: recordingURL,
                    transcript: transcript!,
                    duration: duration,
                    completion: completion
                )
            }
        }
    }
    
    /// Processes a transcript with the Claude API
    /// - Parameters:
    ///   - recordingURL: The URL of the recording
    ///   - transcript: The transcript to process
    ///   - duration: The duration of the recording
    private func processTranscriptWithClaude(recordingURL: URL, transcript: String, duration: TimeInterval, completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        // Skip Claude processing if API key is not set
        if anthropicAPIKey.isEmpty {
            print("Anthropic API key not set, skipping Claude processing")
            createVoiceNote(
                recordingURL: recordingURL,
                originalTranscript: transcript,
                cleanedTranscript: transcript,
                suggestedTitle: "Voice Note \(Date().formatted(.dateTime.month().day().year()))",
                duration: duration,
                completion: completion
            )
            return
        }
        
        // Process with Claude
        anthropicService.processTranscript(transcript) { [weak self] success, cleanedTranscript, suggestedTitle in
            guard let self = self else { return }
            
            if !success && !self.anthropicAPIKey.isEmpty {
                // Only show error if API key is set but call failed
                let error = AppError.anthropic(.networkError("Failed to process transcript with Anthropic API"))
                self.handleError(error)
                // We'll continue with the original transcript, but we've logged the error
            }
            
            // If the API call fails, use the original transcript and a default title
            let finalTranscript = cleanedTranscript ?? transcript
            
            // Generate a default title if needed
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            let dateString = dateFormatter.string(from: Date())
            let finalTitle = suggestedTitle ?? "Voice Note \(dateString)"
            
            print("Final title: \(finalTitle)")
            print("Using transcript: \(success ? "cleaned by Claude" : "original")")
            
            self.createVoiceNote(
                recordingURL: recordingURL,
                originalTranscript: transcript,
                cleanedTranscript: finalTranscript,
                suggestedTitle: finalTitle,
                duration: duration,
                completion: completion
            )
        }
    }
    

    
    /// Cleanup resources
    func cleanup() {
        // Only clean up resources that were actually initialized
        if _recordingManager != nil {
            // Release audio session
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        
        // Force nil all optionals to release memory
        _recordingManager = nil
        _transcriptionManager = nil
        _dataStore = nil
        _anthropicService = nil
        _obsidianService = nil
        
        // Cancel any publishers
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        print("VoiceNoteCoordinator cleaned up")
    }
    
    /// Creates a voice note and saves it
    /// - Parameters:
    ///   - recordingURL: The URL of the recording
    ///   - originalTranscript: The original transcript
    ///   - cleanedTranscript: The cleaned transcript
    ///   - suggestedTitle: The suggested title
    ///   - duration: The duration of the recording
    private func createVoiceNote(recordingURL: URL, originalTranscript: String, cleanedTranscript: String, suggestedTitle: String, duration: TimeInterval, completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        let startTime = recordingManager.getRecordingStartTime() ?? Date()
        
        // Create voice note
        let voiceNote = VoiceNote(
            title: suggestedTitle,
            originalTranscript: originalTranscript,
            cleanedTranscript: cleanedTranscript,
            duration: duration,
            creationDate: startTime,
            audioFilename: recordingURL.lastPathComponent
        )
        
        // Check if Obsidian vault path is set
        if !obsidianVaultPath.isEmpty {
            print("Saving to Obsidian vault at: \(obsidianVaultPath)")
            
            // First copy the audio file to the Obsidian vault
            obsidianService.copyAudioFileToVault(from: recordingURL) { [weak self] audioSuccess in
                guard let self = self else { return }
                
                print("Audio file copy result: \(audioSuccess)")
                
                // Then create the markdown note
                self.obsidianService.createVoiceNoteFile(for: voiceNote) { noteSuccess, obsidianPath in
                    print("Note creation result: \(noteSuccess), path: \(obsidianPath ?? "none")")
                    
                    var updatedVoiceNote = voiceNote
                    if noteSuccess, let path = obsidianPath {
                        updatedVoiceNote.obsidianPath = path
                    }
                    
                    // Add to store
                    self.dataStore.addVoiceNote(updatedVoiceNote)
                    
                    // Update state
                    DispatchQueue.main.async {
                        self.isProcessing = false
                    }
                }
            }
        } else {
            print("Obsidian vault path not set, skipping Obsidian integration")
            
            // Still add to store
            dataStore.addVoiceNote(voiceNote)
            
            // Update state
            DispatchQueue.main.async {
                self.isProcessing = false
            }
        }
    }
}

// MARK: - Voice Notes Access

extension VoiceNoteCoordinator {
    /// Gets all voice notes
    var voiceNotes: [VoiceNote] {
        dataStore.voiceNotes
    }
    
    /// Checks if notes are currently loading
    var isLoadingNotes: Bool {
        dataStore.isLoadingNotes
    }
    
    /// Checks if all notes have been loaded
    var loadedAllNotes: Bool {
        dataStore.loadedAllNotes
    }
}
