import Foundation
import Combine
import SwiftUI
import Security
import AVFoundation
import OSLog

/// The VoiceNoteCoordinator is the primary orchestrator for the entire voice note lifecycle.
/// It coordinates all operations related to recording, transcription, processing with Anthropic,
/// and integration with Obsidian. This class serves as the central point of coordination between
/// various services and the UI.
///
/// Responsibilities:
/// - Recording voice notes via RecordingManager
/// - Transcribing audio via TranscriptionManager
/// - Processing transcripts via AnthropicService
/// - Saving notes to Obsidian via ObsidianService
/// - Delegating data persistence to VoiceNoteStore
///
/// The coordinator uses lazy initialization for its services to minimize memory usage
/// until each service is actually needed.
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
    private var _voiceNoteStore: VoiceNoteStore?
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
    
    private var voiceNoteStore: VoiceNoteStore {
        if _voiceNoteStore == nil {
            print("Lazily creating VoiceNoteStore")
            _voiceNoteStore = VoiceNoteStore(previewData: false, lazyInit: true)
        }
        return _voiceNoteStore!
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
        
        // Always set up bindings between services
        setupBindings()
        
        // If requested, preload services - normally we don't do this
        if loadImmediately {
            print("Preloading services as requested (not recommended)")
            // Force initialization of services
            _ = recordingManager
            _ = transcriptionManager
            _ = voiceNoteStore
            _ = anthropicService
            _ = obsidianService
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
        
        // Force initialization of the recording manager and ensure bindings are set up
        // This ensures the recording duration updates will be properly forwarded
        let _ = recordingManager
        
        // Reset the recording duration before starting
        recordingDuration = 0
        
        // Use async/await with Task
        Task {
            do {
                // Call the async version directly
                let success = try await recordingManager.startRecordingAsync()
                
                if success {
                    await MainActor.run {
                        self.isRecording = true
                    }
                    completion(true, nil)
                } else {
                    let error = AppError.recording(.recordingFailed("Failed to start recording"))
                    await MainActor.run {
                        self.handleError(error)
                    }
                    print("Failed to start recording")
                    completion(false, error)
                }
            } catch {
                await MainActor.run {
                    self.handleError(AppError.recording(.recordingFailed(error.localizedDescription)))
                }
                print("Error starting recording: \(error.localizedDescription)")
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
        
        // Use async/await with Task
        Task {
            do {
                // Call the async version directly
                let voiceNote = try await recordingManager.stopRecordingAsync()
                
                if let voiceNote = voiceNote {
                    await MainActor.run {
                        self.isRecording = false
                    }
                    
                    // Process the voice note
                    let duration = voiceNote.duration
                    let recordingURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent(voiceNote.audioFilename)
                    
                    // Process the recording
                    await self.processRecordingAsync(recordingURL: recordingURL, voiceNote: voiceNote)
                    completion(true, nil)
                } else {
                    await MainActor.run {
                        self.isProcessing = false
                        // Reset the recording duration on error
                        self.recordingManager.resetRecordingDuration()
                    }
                    let error = AppError.recording(.recordingFailed("Failed to stop recording"))
                    await MainActor.run {
                        self.handleError(error)
                    }
                    completion(false, error)
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    // Reset the recording duration on error
                    self.recordingManager.resetRecordingDuration()
                    self.handleError(AppError.recording(.recordingFailed(error.localizedDescription)))
                }
                print("Error stopping recording: \(error.localizedDescription)")
                completion(false, error)
            }
        }
    }
    
    // MARK: - Public Methods - Voice Notes
    
    /// Loads more voice notes (pagination)
    func loadMoreVoiceNotes() {
        voiceNoteStore.loadMoreVoiceNotes()
    }
    
    /// Refreshes the voice notes list
    func refreshVoiceNotes() {
        voiceNoteStore.refreshVoiceNotes()
    }
    
    /// Deletes a voice note
    /// - Parameter voiceNote: The voice note to delete
    func deleteVoiceNote(_ voiceNote: VoiceNote) {
        voiceNoteStore.deleteVoiceNote(voiceNote)
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
                
                // Note: We don't reset the recording duration here because we're still going to use the fallback transcript
                
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
    
    /// Process a recording asynchronously
    /// - Parameters:
    ///   - recordingURL: The URL of the recording
    ///   - voiceNote: The voice note to process
    private func processRecordingAsync(recordingURL: URL, voiceNote: VoiceNote) async {
        do {
            // First, transcribe the audio file
            var processedVoiceNote = voiceNote
            
            do {
                // Use the async version of the transcription manager
                let transcript = try await transcriptionManager.transcribeAudioFileAsync(at: recordingURL)
                
                // Update the voice note with the transcript
                processedVoiceNote.originalTranscript = transcript
            } catch {
                print("Error transcribing audio: \(error.localizedDescription)")
                // Continue with empty transcript
            }
            
            // Process with Anthropic API if key is set and we have a transcript
            if !anthropicAPIKey.isEmpty && !processedVoiceNote.originalTranscript.isEmpty {
                do {
                    // Use the async version of the Anthropic service
                    // Process transcript and get title in one call
                    let result = try await anthropicService.processTranscriptWithTitleAsync(transcript: processedVoiceNote.originalTranscript)
                    processedVoiceNote.cleanedTranscript = result.transcript
                    processedVoiceNote.title = result.title
                    // Successfully processed with Anthropic
                } catch {
                    // Log the error but continue with the original voice note
                    await MainActor.run {
                        if !self.anthropicAPIKey.isEmpty {
                            // Only show error if API key is set but call failed
                            let appError = AppError.anthropic(.networkError("Failed to process transcript with Anthropic API"))
                            self.handleError(appError)
                        }
                    }
                    print("Error processing with Anthropic: \(error.localizedDescription)")
                }
            } else if !processedVoiceNote.originalTranscript.isEmpty {
                // If we have a transcript but no Anthropic API key, use the original transcript
                processedVoiceNote.cleanedTranscript = processedVoiceNote.originalTranscript
                // Using original transcript as cleaned transcript
            }
            
            // Save to Obsidian if path is set
            if !obsidianVaultPath.isEmpty {
                do {
                    // Copy audio file to Obsidian vault
                    let audioSuccess = try await obsidianService.copyAudioFileToVault(from: recordingURL)
                    print("Audio file copy result: \(audioSuccess)")
                    
                    // Create markdown note in Obsidian vault
                    let result = try await obsidianService.createVoiceNoteFile(for: processedVoiceNote)
                    print("Note creation result: \(result.success), path: \(result.path ?? "none")")
                    
                    if result.success, let path = result.path {
                        processedVoiceNote.obsidianPath = path
                    }
                } catch {
                    print("Error saving to Obsidian: \(error.localizedDescription)")
                }
            }
            
            // Add to data store
            await MainActor.run {
                voiceNoteStore.addVoiceNote(processedVoiceNote)
                self.isProcessing = false
                recordingManager.resetRecordingDuration()
            }
        } catch {
            await MainActor.run {
                self.isProcessing = false
                recordingManager.resetRecordingDuration()
                self.handleError(AppError.transcription(.recognitionFailed(error.localizedDescription)))
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
                suggestedTitle: "Voice Note \(DateFormatUtil.shared.formatTimestamp(date: Date()))",
                duration: duration,
                completion: completion
            )
            return
        }
        
        // Process with Claude using async/await
        Task {
            do {
                // Use the async version directly
                let result = try await anthropicService.processTranscriptWithTitleAsync(transcript: transcript)
                
                print("Final title: \(result.title)")
                print("Using transcript: cleaned by Claude")
                
                self.createVoiceNote(
                    recordingURL: recordingURL,
                    originalTranscript: transcript,
                    cleanedTranscript: result.transcript,
                    suggestedTitle: result.title,
                    duration: duration,
                    completion: completion
                )
            } catch {
                // Handle error but continue with original transcript
                if !self.anthropicAPIKey.isEmpty {
                    // Only show error if API key is set but call failed
                    let appError = AppError.anthropic(.networkError("Failed to process transcript with Anthropic API"))
                    await MainActor.run {
                        self.handleError(appError)
                    }
                }
                print("Error processing with Claude: \(error.localizedDescription)")
                
                // Generate a default title
                let dateString = DateFormatUtil.shared.formatTimestamp(date: Date())
                let defaultTitle = "Voice Note \(dateString)"
                
                self.createVoiceNote(
                    recordingURL: recordingURL,
                    originalTranscript: transcript,
                    cleanedTranscript: transcript,
                    suggestedTitle: defaultTitle,
                    duration: duration,
                    completion: completion
                )
            }
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
        _voiceNoteStore = nil
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
        
        // Use async/await with Task
        Task {
            // Check if Obsidian vault path is set
            if !obsidianVaultPath.isEmpty {
                print("Saving to Obsidian vault at: \(obsidianVaultPath)")
                
                do {
                    // First copy the audio file to the Obsidian vault using async version
                    let audioSuccess = try await obsidianService.copyAudioFileToVault(from: recordingURL)
                    print("Audio file copy result: \(audioSuccess)")
                    
                    // Then create the markdown note using async version
                    let result = try await obsidianService.createVoiceNoteFile(for: voiceNote)
                    print("Note creation result: \(result.success), path: \(result.path ?? "none")")
                    
                    var updatedVoiceNote = voiceNote
                    if result.success, let path = result.path {
                        updatedVoiceNote.obsidianPath = path
                    }
                    
                    // Add to store
                    await MainActor.run {
                        self.voiceNoteStore.addVoiceNote(updatedVoiceNote)
                        self.isProcessing = false
                        // Reset the recording duration after processing is complete
                        self.recordingManager.resetRecordingDuration()
                    }
                    
                    completion(true, nil)
                } catch {
                    print("Error saving to Obsidian: \(error.localizedDescription)")
                    
                    // Still add the voice note to the store even if Obsidian integration fails
                    await MainActor.run {
                        self.voiceNoteStore.addVoiceNote(voiceNote)
                        self.isProcessing = false
                        self.recordingManager.resetRecordingDuration()
                    }
                    
                    completion(true, error) // We still consider this a success for the voice note creation
                }
            } else {
                print("Obsidian vault path not set, skipping Obsidian integration")
                
                // Still add to store
                await MainActor.run {
                    self.voiceNoteStore.addVoiceNote(voiceNote)
                    self.isProcessing = false
                    // Reset the recording duration after processing is complete
                    self.recordingManager.resetRecordingDuration()
                }
                
                completion(true, nil)
            }
        }
    }
}

// MARK: - Voice Notes Access

extension VoiceNoteCoordinator {
    /// Gets all voice notes
    var voiceNotes: [VoiceNote] {
        voiceNoteStore.voiceNotes
    }
    
    /// Checks if notes are currently loading
    var isLoadingNotes: Bool {
        voiceNoteStore.isLoadingNotes
    }
    
    /// Checks if all notes have been loaded
    var loadedAllNotes: Bool {
        voiceNoteStore.loadedAllNotes
    }
}
