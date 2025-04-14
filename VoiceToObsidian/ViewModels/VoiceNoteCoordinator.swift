import Foundation
import Combine
import SwiftUI
import Security
import AVFoundation
import OSLog

// Import BookmarkManager for secure bookmark storage
import VoiceToObsidian

/// The primary orchestrator for the entire voice note lifecycle in the Voice to Obsidian application.
///
/// `VoiceNoteCoordinator` serves as the central coordination point between various services and the UI,
/// managing the complete lifecycle of voice notes from recording through processing to storage.
/// It follows the coordinator pattern to decouple UI components from business logic and service interactions.
///
/// ## Responsibilities
/// - Recording voice notes via `RecordingManager`
/// - Transcribing audio via `TranscriptionManager`
/// - Processing transcripts via `AnthropicService`
/// - Saving notes to Obsidian via `ObsidianService`
/// - Delegating data persistence to `VoiceNoteStore`
/// - Managing configuration and secure storage of sensitive data
/// - Handling errors throughout the voice note lifecycle
///
/// ## Design Patterns
/// - **Coordinator Pattern**: Acts as a mediator between UI and services
/// - **Lazy Initialization**: Services are only created when needed to minimize resource usage
/// - **Property Wrappers**: Uses `@SecureStorage` for secure persistence of sensitive configuration
/// - **Combine**: Leverages reactive programming for state updates across components
///
/// ## Example Usage
/// ```swift
/// // Create a coordinator
/// let coordinator = VoiceNoteCoordinator()
///
/// // Start recording
/// Task {
///     do {
///         try await coordinator.startRecordingAsync()
///     } catch {
///         print("Recording failed: \(error)")
///     }
/// }
///
/// // Stop recording and process
/// Task {
///     do {
///         try await coordinator.stopRecordingAsync()
///     } catch {
///         print("Processing failed: \(error)")
///     }
/// }
/// ```
@MainActor
class VoiceNoteCoordinator: ObservableObject, ErrorHandling {
    // MARK: - Published Properties
    
    /// Indicates whether a recording is currently in progress.
    ///
    /// This property is used to update the UI and control the recording state.
    /// When `true`, the app is actively recording audio.
    @Published var isRecording = false
    
    /// Indicates whether a voice note is currently being processed.
    ///
    /// This property is used to update the UI and prevent multiple simultaneous operations.
    /// When `true`, the app is transcribing, processing with Anthropic, or saving to Obsidian.
    @Published var isProcessing = false
    
    /// The current duration of the active recording in seconds.
    ///
    /// This property is updated in real-time during recording and is used to display
    /// the recording duration in the UI.
    @Published var recordingDuration: TimeInterval = 0
    
    /// The progress of the current transcription operation (0.0 to 1.0).
    ///
    /// This property is updated during transcription and is used to display
    /// progress indicators in the UI.
    @Published var transcriptionProgress: Float = 0
    
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
    
    // MARK: - Lazy Service Backing Variables
    
    /// Backing variable for the lazily initialized recording manager.
    ///
    /// This variable holds the instance of `RecordingManager` once it's created.
    /// It remains `nil` until the `recordingManager` property is accessed.
    private var _recordingManager: RecordingManager?
    
    /// Backing variable for the lazily initialized transcription manager.
    ///
    /// This variable holds the instance of `TranscriptionManager` once it's created.
    /// It remains `nil` until the `transcriptionManager` property is accessed.
    private var _transcriptionManager: TranscriptionManager?
    
    /// Backing variable for the lazily initialized voice note store.
    ///
    /// This variable holds the instance of `VoiceNoteStore` once it's created.
    /// It remains `nil` until the `voiceNoteStore` property is accessed.
    private var _voiceNoteStore: VoiceNoteStore?
    
    /// Backing variable for the lazily initialized Anthropic service.
    ///
    /// This variable holds the instance of `AnthropicService` once it's created.
    /// It remains `nil` until the `anthropicService` property is accessed.
    private var _anthropicService: AnthropicService?
    
    /// Backing variable for the lazily initialized Obsidian service.
    ///
    /// This variable holds the instance of `ObsidianService` once it's created.
    /// It remains `nil` until the `obsidianService` property is accessed.
    private var _obsidianService: ObsidianService?
    
    // MARK: - Lazy Service Properties
    
    /// The recording manager responsible for audio recording functionality.
    ///
    /// This property lazily initializes the `RecordingManager` when first accessed,
    /// which helps minimize memory usage and startup time. The manager handles
    /// all aspects of audio recording, including permissions and file creation.
    private var recordingManager: RecordingManager {
        if _recordingManager == nil {
            logger.debug("Lazily creating RecordingManager")
            _recordingManager = RecordingManager()
        }
        return _recordingManager!
    }
    
    /// The transcription manager responsible for speech recognition.
    ///
    /// This property lazily initializes the `TranscriptionManager` when first accessed,
    /// which helps minimize memory usage and startup time. The manager handles
    /// converting audio recordings to text using Apple's speech recognition.
    private var transcriptionManager: TranscriptionManager {
        if _transcriptionManager == nil {
            logger.debug("Lazily creating TranscriptionManager")
            _transcriptionManager = TranscriptionManager()
        }
        return _transcriptionManager!
    }
    
    /// The voice note store responsible for data persistence.
    ///
    /// This property lazily initializes the `VoiceNoteStore` when first accessed,
    /// which helps minimize memory usage and startup time. The store handles
    /// saving, loading, and managing voice note data on disk.
    private var voiceNoteStore: VoiceNoteStore {
        if _voiceNoteStore == nil {
            logger.debug("Lazily creating VoiceNoteStore")
            _voiceNoteStore = VoiceNoteStore(previewData: false, lazyInit: true)
        }
        return _voiceNoteStore!
    }
    
    /// The Anthropic service responsible for processing transcripts.
    ///
    /// This property lazily initializes the `AnthropicService` when first accessed,
    /// which helps minimize memory usage and startup time. The service handles
    /// communication with the Anthropic Claude API to clean and format transcripts.
    private var anthropicService: AnthropicService {
        if _anthropicService == nil {
            logger.debug("Lazily creating AnthropicService")
            _anthropicService = AnthropicService(apiKey: anthropicAPIKey)
        }
        return _anthropicService!
    }
    
    /// The Obsidian service responsible for vault interactions.
    ///
    /// This property lazily initializes the `ObsidianService` when first accessed,
    /// which helps minimize memory usage and startup time. The service handles
    /// creating markdown files and copying audio files to the Obsidian vault.
    private var obsidianService: ObsidianService {
        if _obsidianService == nil {
            logger.debug("Lazily creating ObsidianService")
            _obsidianService = ObsidianService(vaultPath: obsidianVaultPath)
        }
        return _obsidianService!
    }
    
    // MARK: - Logging
    
    /// Logger for structured logging of coordinator operations.
    ///
    /// This logger uses the OSLog system for efficient and structured logging
    /// of coordinator activities, errors, and service lifecycle events.
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "VoiceNoteCoordinator")
    
    // MARK: - Secure Configuration
    
    /// The Anthropic API key stored securely in the Keychain.
    ///
    /// This property uses the `@SecureStorage` property wrapper to automatically
    /// handle secure storage and retrieval of the API key from the Keychain.
    /// When the value changes, it automatically updates the Anthropic service.
    @SecureStorage(wrappedValue: "", key: "AnthropicAPIKey")
    private var anthropicAPIKey: String {
        didSet {
            logger.debug("API key updated")
            anthropicService.updateAPIKey(anthropicAPIKey)
        }
    }
    
    /// The path to the Obsidian vault stored securely in the Keychain.
    ///
    /// This property uses the `@SecureStorage` property wrapper to automatically
    /// handle secure storage and retrieval of the vault path from the Keychain.
    /// When the value changes, it automatically updates the Obsidian service.
    @SecureStorage(wrappedValue: "", key: "ObsidianVaultPath")
    private var obsidianVaultPath: String {
        didSet {
            logger.debug("Vault path updated")
            obsidianService.updateVaultPath(obsidianVaultPath)
        }
    }
    
    /// The security-scoped bookmark data for the Obsidian vault.
    ///
    /// This property holds the bookmark data that allows the app to maintain
    /// access to the user-selected Obsidian vault directory across app launches.
    private var obsidianVaultBookmark: Data?
    
    // MARK: - Combine
    
    /// Collection of cancellables for managing Combine subscriptions.
    ///
    /// This set stores all active Combine subscription cancellables to ensure
    /// proper memory management and prevent memory leaks from lingering subscriptions.
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initializes a new VoiceNoteCoordinator instance.
    ///
    /// This initializer sets up the coordinator with minimal resource usage by default.
    /// It establishes bindings between services but doesn't initialize the services themselves
    /// unless specifically requested with the `loadImmediately` parameter.
    ///
    /// - Parameter loadImmediately: If `true`, forces immediate initialization of all services
    ///   rather than waiting for lazy initialization. This is generally not recommended
    ///   as it increases startup time and memory usage. Default is `false`.
    ///
    /// ## Example
    /// ```swift
    /// // Standard initialization with lazy loading
    /// let coordinator = VoiceNoteCoordinator()
    ///
    /// // Initialization with immediate loading of all services
    /// let eagerCoordinator = VoiceNoteCoordinator(loadImmediately: true)
    /// ```
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
    
    /// Starts recording a voice note asynchronously.
    ///
    /// This method initiates an audio recording session through the `RecordingManager`.
    /// It performs the following operations:
    /// - Checks that no recording or processing is already in progress
    /// - Initializes the recording manager if needed
    /// - Resets the recording duration counter
    /// - Starts the actual recording process
    /// - Updates the UI state to reflect the recording status
    ///
    /// - Returns: A boolean indicating whether recording started successfully
    /// - Throws: `AppError.recording` with details about what went wrong
    ///
    /// ## Example
    /// ```swift
    /// Task {
    ///     do {
    ///         let success = try await coordinator.startRecordingAsync()
    ///         if success {
    ///             print("Recording started successfully")
    ///         }
    ///     } catch {
    ///         print("Failed to start recording: \(error)")
    ///     }
    /// }
    /// ```
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
    

    
    /// Stops recording and processes the voice note asynchronously.
    ///
    /// This method stops the current recording and initiates the complete processing
    /// pipeline for the recorded voice note. It performs the following operations:
    /// - Checks that a recording is actually in progress
    /// - Stops the recording through the `RecordingManager`
    /// - Updates the UI state to reflect that recording has stopped
    /// - Initiates the processing pipeline, which includes:
    ///   - Transcribing the audio using `TranscriptionManager`
    ///   - Processing the transcript with `AnthropicService` (if configured)
    ///   - Saving the note to Obsidian using `ObsidianService` (if configured)
    ///   - Persisting the voice note data using `VoiceNoteStore`
    ///
    /// - Returns: A boolean indicating whether the operation succeeded
    /// - Throws: `AppError` with details about what went wrong
    ///
    /// ## Example
    /// ```swift
    /// Task {
    ///     do {
    ///         let success = try await coordinator.stopRecordingAsync()
    ///         if success {
    ///             print("Recording stopped and processing completed successfully")
    ///         }
    ///     } catch {
    ///         print("Failed to process recording: \(error)")
    ///     }
    /// }
    /// ```
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
    
    /// Loads more voice notes using pagination.
    ///
    /// This method delegates to the `VoiceNoteStore` to load the next batch of voice notes
    /// from disk. It implements pagination to improve performance when dealing with a large
    /// number of voice notes by loading them in batches rather than all at once.
    ///
    /// This method should be called when the user scrolls near the end of the current list
    /// of voice notes or explicitly requests to load more notes.
    ///
    /// ## Example
    /// ```swift
    /// // When user scrolls to bottom of list
    /// if !coordinator.loadedAllNotes {
    ///     coordinator.loadMoreVoiceNotes()
    /// }
    /// ```
    func loadMoreVoiceNotes() {
        voiceNoteStore.loadMoreVoiceNotes()
    }
    
    /// Refreshes the voice notes list by reloading from disk.
    ///
    /// This method delegates to the `VoiceNoteStore` to reload all voice notes from disk,
    /// discarding the current in-memory cache. It's useful when the underlying data may
    /// have changed outside of the normal app flow, or when the user explicitly requests
    /// a refresh.
    ///
    /// ## Example
    /// ```swift
    /// // When user pulls to refresh
    /// coordinator.refreshVoiceNotes()
    /// ```
    func refreshVoiceNotes() {
        voiceNoteStore.refreshVoiceNotes()
    }
    
    /// Deletes a voice note and its associated files.
    ///
    /// This method delegates to the `VoiceNoteStore` to delete the specified voice note
    /// from both memory and disk storage. It removes:
    /// - The voice note from the in-memory collection
    /// - The voice note's metadata from persistent storage
    /// - The associated audio file from the file system
    ///
    /// - Parameter voiceNote: The voice note to delete
    ///
    /// ## Example
    /// ```swift
    /// // When user swipes to delete
    /// coordinator.deleteVoiceNote(voiceNote)
    /// ```
    func deleteVoiceNote(_ voiceNote: VoiceNote) {
        voiceNoteStore.deleteVoiceNote(voiceNote)
    }
    
    // MARK: - Public Methods - Configuration
    
    /// Sets the Anthropic API key for transcript processing.
    ///
    /// This method securely stores the provided API key in the Keychain using the
    /// `@SecureStorage` property wrapper and updates the Anthropic service with the new key.
    /// The API key is required for transcript processing with the Anthropic Claude API.
    ///
    /// - Parameter key: The Anthropic API key to store
    ///
    /// ## Example
    /// ```swift
    /// // When user enters API key in settings
    /// coordinator.setAnthropicAPIKey("ant-api-xxxxxxxxxxxxx")
    /// ```
    func setAnthropicAPIKey(_ key: String) {
        anthropicAPIKey = key
    }
    
    /// Clears the Anthropic API key securely from storage.
    ///
    /// This method removes the API key from the Keychain using the `@SecureStorage`
    /// property wrapper and updates the Anthropic service to reflect the change.
    /// After calling this method, transcript processing with Anthropic will be disabled
    /// until a new API key is provided.
    ///
    /// ## Example
    /// ```swift
    /// // When user wants to remove API key
    /// coordinator.clearAnthropicAPIKey()
    /// ```
    func clearAnthropicAPIKey() {
        // Property wrapper handles the deletion from keychain
        anthropicAPIKey = ""
        anthropicService.updateAPIKey("")
        logger.info("API key cleared successfully")
    }
    
    /// Sets the path to the Obsidian vault for note creation.
    ///
    /// This method securely stores the provided vault path in the Keychain using the
    /// `@SecureStorage` property wrapper and updates the Obsidian service with the new path.
    /// The vault path is required for creating markdown notes in the Obsidian vault.
    ///
    /// - Parameter path: The file system path to the Obsidian vault
    ///
    /// ## Example
    /// ```swift
    /// // When user selects vault directory
    /// coordinator.setObsidianVaultPath("/Users/username/Documents/ObsidianVault")
    /// ```
    func setObsidianVaultPath(_ path: String) {
        obsidianVaultPath = path
    }
    
    /// Clears the Obsidian vault path securely from storage.
    ///
    /// This method removes the vault path from the Keychain using the `@SecureStorage`
    /// property wrapper and updates the Obsidian service to reflect the change.
    /// After calling this method, note creation in Obsidian will be disabled
    /// until a new vault path is provided.
    ///
    /// ## Example
    /// ```swift
    /// // When user wants to remove vault access
    /// coordinator.clearObsidianVaultPath()
    /// ```
    func clearObsidianVaultPath() {
        // Property wrapper handles the deletion from keychain
        obsidianVaultPath = ""
        obsidianService.updateVaultPath("")
        logger.info("Vault path cleared successfully")
    }
    
    /// Clears all sensitive data from the app asynchronously.
    ///
    /// This method provides a comprehensive way to remove all sensitive data from the app,
    /// including:
    /// - The Anthropic API key from the Keychain
    /// - The Obsidian vault path from the Keychain
    /// - Any security-scoped bookmarks for the Obsidian vault
    ///
    /// It's designed for use in privacy features, account logout, or app reset functionality.
    /// The method returns a dictionary of any errors that occurred during the operation,
    /// allowing the caller to handle partial failures appropriately.
    ///
    /// - Returns: A dictionary mapping operation names to errors that occurred.
    ///   An empty dictionary indicates complete success.
    ///
    /// ## Example
    /// ```swift
    /// Task {
    ///     let errors = await coordinator.clearAllSensitiveDataAsync()
    ///     if errors.isEmpty {
    ///         print("All sensitive data cleared successfully")
    ///     } else {
    ///         print("Some errors occurred: \(errors)")
    ///     }
    /// }
    /// ```
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
    
    /// Sets up reactive bindings between services using Combine.
    ///
    /// This method establishes the reactive data flow between different components
    /// of the application using Combine publishers and subscribers. It creates bindings for:
    /// - Recording duration updates from `RecordingManager` to the coordinator's published property
    /// - Transcription progress updates from `TranscriptionManager` to the coordinator's published property
    ///
    /// These bindings ensure that UI components observing the coordinator's published properties
    /// will automatically update when the underlying service state changes.
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
    

    
    /// Processes a recording asynchronously through the complete voice note pipeline.
    ///
    /// This private method implements the core processing pipeline for a voice note after recording.
    /// It orchestrates the following sequence of operations:
    /// 1. Transcribes the audio file using `TranscriptionManager`
    /// 2. If an Anthropic API key is available, processes the transcript with `AnthropicService` to:
    ///    - Clean and format the transcript
    ///    - Generate an appropriate title
    /// 3. If an Obsidian vault path is available:
    ///    - Copies the audio file to the Obsidian vault's attachments directory
    ///    - Creates a markdown note in the vault with the transcript and metadata
    /// 4. Saves the completed voice note to persistent storage via `VoiceNoteStore`
    /// 5. Updates the UI state to reflect completion
    ///
    /// The method includes comprehensive error handling at each stage, allowing the pipeline
    /// to continue even if individual steps fail.
    ///
    /// - Parameters:
    ///   - recordingURL: The file URL of the recorded audio file
    ///   - voiceNote: The initial voice note object with basic metadata
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
    

    

    
    /// Cleans up resources and prepares the coordinator for deallocation.
    ///
    /// This method performs proper cleanup of all resources managed by the coordinator,
    /// including:
    /// - Releasing the audio session
    /// - Releasing all service instances
    /// - Cancelling all Combine subscriptions
    ///
    /// It should be called when the coordinator is no longer needed, such as when
    /// the app is terminating or when switching to a different user session.
    ///
    /// ## Example
    /// ```swift
    /// // When app is terminating
    /// coordinator.cleanup()
    /// ```
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

/// Extension providing convenient access to voice note data for UI components.
///
/// This extension exposes voice note data and state from the `VoiceNoteStore` in a way
/// that's convenient for SwiftUI views to consume. It provides computed properties that
/// forward to the underlying store, allowing views to observe and react to changes in
/// the voice note collection without directly coupling to the store implementation.
extension VoiceNoteCoordinator {
    /// Gets all voice notes currently loaded in memory.
    ///
    /// This computed property provides access to the current collection of voice notes
    /// managed by the `VoiceNoteStore`. It's intended for use in SwiftUI views that need
    /// to display the voice notes, such as in a list or grid.
    ///
    /// ## Example
    /// ```swift
    /// List(coordinator.voiceNotes) { voiceNote in
    ///     VoiceNoteRow(voiceNote: voiceNote)
    /// }
    /// ```
    var voiceNotes: [VoiceNote] {
        voiceNoteStore.voiceNotes
    }
    
    /// Indicates whether voice notes are currently being loaded from disk.
    ///
    /// This computed property reflects the loading state of the `VoiceNoteStore`.
    /// It's useful for displaying loading indicators in the UI while notes are being
    /// loaded from disk.
    ///
    /// ## Example
    /// ```swift
    /// if coordinator.isLoadingNotes {
    ///     ProgressView()
    /// }
    /// ```
    var isLoadingNotes: Bool {
        voiceNoteStore.isLoadingNotes
    }
    
    /// Indicates whether all available voice notes have been loaded.
    ///
    /// This computed property reflects whether the `VoiceNoteStore` has loaded all
    /// available voice notes from disk. It's useful for determining whether to show
    /// a "Load More" button or automatically trigger loading more notes when the user
    /// scrolls to the bottom of the list.
    ///
    /// ## Example
    /// ```swift
    /// if !coordinator.loadedAllNotes {
    ///     Button("Load More") {
    ///         coordinator.loadMoreVoiceNotes()
    ///     }
    /// }
    /// ```
    var loadedAllNotes: Bool {
        voiceNoteStore.loadedAllNotes
    }
    
    /// Provides direct access to the voice note store for UI observation.
    ///
    /// This computed property provides direct access to the `VoiceNoteStore` instance
    /// for cases where SwiftUI views need to observe the store directly using the
    /// `@ObservedObject` property wrapper. This is useful when the view needs to react
    /// to multiple state changes in the store.
    ///
    /// ## Example
    /// ```swift
    /// struct VoiceNoteListView: View {
    ///     @ObservedObject var store: VoiceNoteStore
    ///     
    ///     init(coordinator: VoiceNoteCoordinator) {
    ///         self.store = coordinator.voiceNoteStoreForObservation
    ///     }
    ///     
    ///     var body: some View {
    ///         List(store.voiceNotes) { voiceNote in
    ///             VoiceNoteRow(voiceNote: voiceNote)
    ///         }
    ///         .overlay(Group {
    ///             if store.isLoadingNotes {
    ///                 ProgressView()
    ///             }
    ///         })
    ///     }
    /// }
    /// ```
    var voiceNoteStoreForObservation: VoiceNoteStore {
        return voiceNoteStore
    }
}
