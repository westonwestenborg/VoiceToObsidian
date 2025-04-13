import Foundation
import Combine
import SwiftUI
import Security
import AVFoundation
import OSLog

// Import BookmarkManager for secure bookmark storage
import VoiceToObsidian

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
            logger.debug("Lazily creating RecordingManager")
            _recordingManager = RecordingManager()
        }
        return _recordingManager!
    }
    
    private var transcriptionManager: TranscriptionManager {
        if _transcriptionManager == nil {
            logger.debug("Lazily creating TranscriptionManager")
            _transcriptionManager = TranscriptionManager()
        }
        return _transcriptionManager!
    }
    
    private var voiceNoteStore: VoiceNoteStore {
        if _voiceNoteStore == nil {
            logger.debug("Lazily creating VoiceNoteStore")
            _voiceNoteStore = VoiceNoteStore(previewData: false, lazyInit: true)
        }
        return _voiceNoteStore!
    }
    
    private var anthropicService: AnthropicService {
        if _anthropicService == nil {
            logger.debug("Lazily creating AnthropicService")
            _anthropicService = AnthropicService(apiKey: anthropicAPIKey)
        }
        return _anthropicService!
    }
    
    private var obsidianService: ObsidianService {
        if _obsidianService == nil {
            logger.debug("Lazily creating ObsidianService")
            _obsidianService = ObsidianService(vaultPath: obsidianVaultPath)
        }
        return _obsidianService!
    }
    
    // Logger for VoiceNoteCoordinator
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "VoiceNoteCoordinator")
    
    // Configuration using property wrappers for automatic persistence
    @SecureStorage(wrappedValue: "", key: "AnthropicAPIKey")
    private var anthropicAPIKey: String {
        didSet {
            logger.debug("API key updated")
            anthropicService.updateAPIKey(anthropicAPIKey)
        }
    }
    
    @SecureStorage(wrappedValue: "", key: "ObsidianVaultPath")
    private var obsidianVaultPath: String {
        didSet {
            logger.debug("Vault path updated")
            obsidianService.updateVaultPath(obsidianVaultPath)
        }
    }
    
    private var obsidianVaultBookmark: Data?
    
    // Cancellables for Combine subscriptions
    var cancellables = Set<AnyCancellable>()
    
    // Initializer
    init(loadImmediately: Bool = false) {
        logger.debug("VoiceNoteCoordinator initialization started - minimal setup only")
        
        // No need to manually initialize stored properties as they are now handled by property wrappers
        
        // Always set up bindings between services
        setupBindings()
        
        // If requested, preload services - normally we don't do this
        if loadImmediately {
            logger.warning("Preloading services as requested (not recommended)")
            // Force initialization of services
            _ = recordingManager
            _ = transcriptionManager
            _ = voiceNoteStore
            _ = anthropicService
            _ = obsidianService
        }
        
        logger.debug("VoiceNoteCoordinator initialized - services will load on demand")
    }
    
    // This method is no longer needed - initialization moved to init()
    
    // This method is no longer needed - preloading moved to init()
    
    // MARK: - Public Methods - Recording
    
    /// Starts recording a voice note asynchronously
    /// - Returns: Boolean indicating success
    /// - Throws: Error if recording fails
    func startRecordingAsync() async throws -> Bool {
        guard !isRecording && !isProcessing else {
            let error = AppError.recording(.recordingFailed("Recording or processing already in progress"))
            await MainActor.run {
                handleError(error)
            }
            throw error
        }
        
        // Force initialization of the recording manager and ensure bindings are set up
        // This ensures the recording duration updates will be properly forwarded
        let _ = recordingManager
        
        // Reset the recording duration before starting
        await MainActor.run {
            recordingDuration = 0
        }
        
        do {
            // Call the async version directly
            let success = try await recordingManager.startRecordingAsync()
            
            if success {
                await MainActor.run {
                    self.isRecording = true
                }
                return true
            } else {
                let error = AppError.recording(.recordingFailed("Failed to start recording"))
                await MainActor.run {
                    self.handleError(error)
                }
                logger.error("Failed to start recording")
                throw error
            }
        } catch {
            await MainActor.run {
                self.handleError(AppError.recording(.recordingFailed(error.localizedDescription)))
            }
            logger.error("Error starting recording: \(error.localizedDescription)")
            throw error
        }
    }
    

    
    /// Stops recording and processes the voice note asynchronously
    /// - Returns: Boolean indicating success
    /// - Throws: Error if stopping recording fails
    func stopRecordingAsync() async throws -> Bool {
        guard isRecording else {
            let error = AppError.recording(.recordingFailed("Not currently recording"))
            await MainActor.run {
                handleError(error)
            }
            throw error
        }
        
        guard !isProcessing else {
            let error = AppError.recording(.recordingFailed("Already processing a recording"))
            await MainActor.run {
                handleError(error)
            }
            throw error
        }
        
        await MainActor.run {
            isProcessing = true
        }
        
        do {
            // Call the async version directly
            let voiceNote = try await recordingManager.stopRecordingAsync()
            
            if let voiceNote = voiceNote {
                await MainActor.run {
                    self.isRecording = false
                }
                
                // Get the recording URL
                let recordingURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(voiceNote.audioFilename)
                
                // Process the recording
                await self.processRecordingAsync(recordingURL: recordingURL, voiceNote: voiceNote)
                return true
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
                throw error
            }
        } catch {
            await MainActor.run {
                self.isProcessing = false
                // Reset the recording duration on error
                self.recordingManager.resetRecordingDuration()
                self.handleError(AppError.recording(.recordingFailed(error.localizedDescription)))
            }
            logger.error("Error stopping recording: \(error.localizedDescription)")
            throw error
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
        // Property wrapper handles the deletion from keychain
        anthropicAPIKey = ""
        anthropicService.updateAPIKey("")
        logger.info("API key cleared successfully")
    }
    
    /// Sets the Obsidian vault path
    /// - Parameter path: The path to the Obsidian vault
    func setObsidianVaultPath(_ path: String) {
        obsidianVaultPath = path
    }
    
    /// Clears the Obsidian vault path
    func clearObsidianVaultPath() {
        // Property wrapper handles the deletion from keychain
        obsidianVaultPath = ""
        obsidianService.updateVaultPath("")
        logger.info("Vault path cleared successfully")
    }
    
    /// Clears all sensitive data from the app (API keys, vault paths, bookmarks) asynchronously
    /// - Returns: Dictionary of errors that occurred during the operation, empty if successful
    func clearAllSensitiveDataAsync() async -> [String: Error] {
        var errors: [String: Error] = [:]
        
        // Clear local properties - property wrappers will handle keychain deletion
        await MainActor.run {
            // Update local properties
            anthropicAPIKey = "" // SecureStorage wrapper handles keychain deletion
            obsidianVaultPath = "" // SecureStorage wrapper handles keychain deletion
            
            // Update services
            anthropicService.updateAPIKey("")
            obsidianService.updateVaultPath("")
        }
        
        // Clear the vault bookmark using the BookmarkManager
        BookmarkManager.shared.clearObsidianVaultBookmark()
        
        if !errors.isEmpty {
            logger.warning("Some errors occurred while clearing sensitive data: \(errors)")
        } else {
            logger.info("All sensitive data cleared successfully")
        }
        
        return errors
    }
    

    
    // MARK: - Private Methods
    
    /// Sets up bindings between services using Combine
    private func setupBindings() {
        // Forward recording duration updates
        recordingManager.$recordingDuration
            .receive(on: RunLoop.main)
            .sink { [weak self] duration in
                self?.recordingDuration = duration
            }
            .store(in: &cancellables)
        
        // Forward transcription progress updates
        transcriptionManager.$transcriptionProgress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                self?.transcriptionProgress = progress
            }
            .store(in: &cancellables)
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
                logger.error("Error transcribing audio: \(error.localizedDescription)")
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
                    logger.error("Error processing with Anthropic: \(error.localizedDescription)")
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
                    logger.debug("Audio file copy result: \(audioSuccess)")
                    
                    // Create markdown note in Obsidian vault
                    let result = try await obsidianService.createVoiceNoteFile(for: processedVoiceNote)
                    logger.info("Note creation result: \(result.success), path: \(result.path ?? "none")")
                    
                    if result.success, let path = result.path {
                        processedVoiceNote.obsidianPath = path
                    }
                } catch {
                    logger.error("Error saving to Obsidian: \(error.localizedDescription)")
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
    
    /// Access to the voice note store for UI observation
    var voiceNoteStoreForObservation: VoiceNoteStore {
        return voiceNoteStore
    }
}
