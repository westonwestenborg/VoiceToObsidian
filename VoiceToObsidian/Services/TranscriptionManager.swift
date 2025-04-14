import Foundation
import Speech
import Combine
import OSLog

/// Manages speech recognition and transcription
@MainActor
class TranscriptionManager: ObservableObject {
    // Published properties for UI updates
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Float = 0
    
    // Private properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestPartialTranscription = ""
    
    // Logger for TranscriptionManager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "TranscriptionManager")
    
    // Initializer
    init() {
        logger.debug("TranscriptionManager initialized (lightweight)")
        // DO NOT initialize speech recognition until needed
    }
    
    deinit {
        // We can't directly call a MainActor-isolated method from deinit
        // Instead, we'll clean up the resources directly that don't require MainActor isolation
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // For completeness, we can schedule a task on the main actor, but it may not execute if the app is terminating
        Task { @MainActor in
            // Update any UI state
            isTranscribing = false
        }
    }
    
    // MARK: - Public Methods
    
    /// Transcribes an audio file using async/await
    /// - Parameter audioURL: The URL of the audio file to transcribe
    /// - Returns: The transcript text if successful
    /// - Throws: Error if transcription fails
    func transcribeAudioFileAsync(at audioURL: URL) async throws -> String {
        logger.info("Starting async transcription of file: \(audioURL.path)")
        
        // Update UI state
        isTranscribing = true
        transcriptionProgress = 0
        latestPartialTranscription = ""
        
        // Setup speech recognition on first use
        if speechRecognizer == nil {
            setupSpeechRecognition()
        }
        
        // Request authorization using continuation
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        // Check authorization status
        guard authStatus == .authorized else {
            logger.error("Speech recognition not authorized")
            isTranscribing = false
            throw NSError(domain: "TranscriptionManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
        }
        
        // Perform transcription using the async method
        let transcript = try await performTranscriptionAsync(of: audioURL)
        return transcript
    }
    
    /// Cancels any ongoing transcription
    func cancelTranscription() {
        // Only log if there's an active task being cancelled
        let hadActiveTask = recognitionTask != nil
        
        // Cancel the recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // Update state
        isTranscribing = false
        
        // Only log if we actually cancelled something
        if hadActiveTask {
            logger.info("Transcription cancelled")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSpeechRecognition() {
        // Use autoreleasepool to help with memory management
        autoreleasepool {
            // Create a speech recognizer with the US English locale
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            
            // Check if the recognizer was created successfully
            guard let recognizer = speechRecognizer else {
                logger.error("Failed to create speech recognizer")
                return
            }
            
            // Check if the recognizer is available
            if !recognizer.isAvailable {
                logger.error("Speech recognizer is not available on this device")
            }
            
            // Request authorization for speech recognition
            Task { @MainActor in
                let status = await withCheckedContinuation { continuation in
                    SFSpeechRecognizer.requestAuthorization { status in
                        continuation.resume(returning: status)
                    }
                }
                
                switch status {
                case .authorized:
                    logger.info("Speech recognition authorization granted")
                case .denied:
                    logger.error("Speech recognition authorization denied by user")
                case .restricted:
                    logger.error("Speech recognition is restricted on this device")
                case .notDetermined:
                    logger.warning("Speech recognition authorization not determined")
                @unknown default:
                    logger.warning("Speech recognition authorization unknown status")
                }
            }
        }
    }
    
    /// Performs transcription of an audio file asynchronously
    /// - Parameter audioURL: URL of the audio file to transcribe
    /// - Returns: The transcript text
    /// - Throws: Error if transcription fails
    private func performTranscriptionAsync(of audioURL: URL) async throws -> String {
        // Verify the audio file exists and has content
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: audioURL.path) {
            logger.error("Audio file does not exist")
            throw NSError(domain: "TranscriptionManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Audio file does not exist"])
        }
        
        // Check file size to ensure it's not empty
        do {
            let attributes = try fileManager.attributesOfItem(atPath: audioURL.path)
            if let size = attributes[.size] as? NSNumber, size.intValue <= 1000 {
                logger.warning("Audio file is very small, may not contain speech")
            }
        } catch {
            logger.error("Error checking audio file: \(error.localizedDescription)")
        }
        
        // Create a new recognizer with the US English locale
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer = recognizer, recognizer.isAvailable else {
            logger.error("Speech recognizer is not available")
            throw NSError(domain: "TranscriptionManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is not available"])
        }
                
        // Create a URL recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true
        
        // Set task hints to improve recognition
        request.taskHint = .dictation
        
        // Add contextual phrases if needed
        request.contextualStrings = ["note", "Obsidian", "voice memo"]
        
        logger.debug("Created speech recognition request")
        
        // Use a continuation to bridge between the callback-based API and async/await
        // Create a class to share state between the recognition task and timeout task
        actor ContinuationState {
            var resumed = false
            let continuation: CheckedContinuation<String, Error>
            
            init(continuation: CheckedContinuation<String, Error>) {
                self.continuation = continuation
            }
            
            func resume(with result: Result<String, Error>) async {
                guard !resumed else { return }
                resumed = true
                
                switch result {
                case .success(let transcript):
                    continuation.resume(returning: transcript)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            func hasResumed() -> Bool {
                return resumed
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Create shared state
            let state = ContinuationState(continuation: continuation)
            
            // Start the recognition task
            self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }
                
                // Process results on the main actor
                Task { [weak self, weak state] in
                    guard let self = self, let state = state else { return }
                    
                    // Handle successful results
                    if let result = result {
                        // Update progress
                        let progress = Float(result.bestTranscription.segments.count) / 10.0 // Estimate
                        self.transcriptionProgress = min(0.95, progress) // Cap at 95% until complete
                        
                        // Store the latest partial transcription for potential timeout scenarios
                        let partialText = result.bestTranscription.formattedString
                        if !partialText.isEmpty {
                            self.latestPartialTranscription = partialText
                            self.logger.debug("Partial transcription: \(partialText)")
                        }
                        
                        // If this is the final result, complete the transcription
                        if result.isFinal {
                            let transcript = result.bestTranscription.formattedString
                            self.logger.info("Transcription completed successfully")
                            
                            self.transcriptionProgress = 1.0
                            self.isTranscribing = false
                            
                            // Resume the continuation with the final transcript
                            if !(await state.hasResumed()) {
                                await state.resume(with: .success(transcript))
                            }
                        }
                    }
                    
                    // Handle errors
                    if let error = error {
                        let nsError = error as NSError
                        // Log basic error info
                        self.logger.error("Speech recognition error: \(nsError.localizedDescription)")
                        
                        // Check for specific error types and handle accordingly
                        if nsError.domain == "kAFAssistantErrorDomain" {
                            // Handle specific Apple speech recognition errors
                            switch nsError.code {
                            case 1: // Recognition failed
                                self.logger.error("Recognition failed - general error")
                            case 2: // Recognition was canceled by the user or system
                                self.logger.error("Recognition canceled")
                            case 3: // Recognition timed out
                                self.logger.error("Recognition timed out")
                            case 4: // Recognition server error
                                self.logger.error("Recognition server error")
                            case 1101: // No speech detected or local speech recognition issue
                                self.logger.error("No speech detected or local speech recognition issue")
                            case 1110: // Other local speech recognition issue
                                self.logger.error("Local speech recognition issue")
                            default:
                                self.logger.error("Unknown speech recognition error code: \(nsError.code)")
                            }
                        }
                        
                        // If we have partial results, use those rather than failing completely
                        if !self.latestPartialTranscription.isEmpty {
                            self.logger.info("Using partial transcript despite error: \(self.latestPartialTranscription)")
                            self.transcriptionProgress = 1.0
                            self.isTranscribing = false
                            
                            // Resume with the partial transcript we've captured
                            if !(await state.hasResumed()) {
                                await state.resume(with: .success(self.latestPartialTranscription))
                            }
                        } else {
                            // No transcript available - check if this is a fatal error or if we should wait
                            // Some errors like 1101 (no speech detected) might be temporary
                            if nsError.domain == "kAFAssistantErrorDomain" && 
                               (nsError.code == 1101 || nsError.code == 1110) {
                                // These are often temporary errors, log but don't fail yet
                                self.logger.debug("Temporary error (\(nsError.code)), waiting for more results")
                            } else {
                                // Fatal error or we've waited long enough, resume with failure
                                self.isTranscribing = false
                                
                                if !(await state.hasResumed()) {
                                    await state.resume(with: .failure(error))
                                }
                            }
                        }
                    }
                }
            }
            
            // Set up a timeout to ensure we don't wait forever
            Task { [weak self, weak state] in
                guard let self = self, let state = state else { return }
                
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds timeout
                    
                    // If we're still transcribing after timeout, force completion with whatever we have
                    self.logger.warning("Checking transcription timeout after 30 seconds")
                    
                    // Only proceed if the continuation hasn't been resumed yet
                    if await !state.hasResumed() {
                        self.logger.warning("Transcription timed out after 30 seconds")
                        
                        // In a timeout scenario, use the latest partial transcription we've captured
                        if !self.latestPartialTranscription.isEmpty {
                            self.logger.info("Using partial transcript after timeout: \(self.latestPartialTranscription)")
                            await state.resume(with: .success(self.latestPartialTranscription))
                        } else if self.transcriptionProgress > 0.1 {
                            // Fallback if we have some progress but no stored transcript
                            let partialTranscript = "[Partial transcription - timed out]"
                            self.logger.info("Using generic transcript after timeout")
                            await state.resume(with: .success(partialTranscript))
                        } else {
                            // No results available after timeout
                            self.logger.error("Transcription timed out with no results")
                            await state.resume(with: .failure(NSError(
                                domain: "TranscriptionManager",
                                code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Transcription timed out with no results"]
                            )))
                        }
                        
                        self.transcriptionProgress = 1.0
                        self.isTranscribing = false
                        self.cancelTranscription()
                    }
                } catch {
                    // Task was cancelled, do nothing
                }
            }
        }
    }
}
