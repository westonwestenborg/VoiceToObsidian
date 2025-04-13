import Foundation
import Speech
import Combine
import OSLog

/// Manages speech recognition and transcription
class TranscriptionManager: ObservableObject {
    // Published properties for UI updates
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Float = 0
    
    // Private properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Logger for TranscriptionManager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "TranscriptionManager")
    
    // Initializer
    init() {
        logger.debug("TranscriptionManager initialized (lightweight)")
        // DO NOT initialize speech recognition until needed
    }
    
    deinit {
        cancelTranscription()
    }
    
    // MARK: - Public Methods
    
    /// Transcribes an audio file using async/await
    /// - Parameter audioURL: The URL of the audio file to transcribe
    /// - Returns: The transcript text if successful, nil otherwise
    /// - Throws: Error if transcription fails
    func transcribeAudioFileAsync(at audioURL: URL) async throws -> String {
        logger.info("Starting async transcription of file: \(audioURL.path)")
        
        // Update UI state on main thread
        await MainActor.run {
            isTranscribing = true
            transcriptionProgress = 0
        }
        
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
            await MainActor.run {
                isTranscribing = false
            }
            throw NSError(domain: "TranscriptionManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
        }
        
        // Perform transcription using continuation
        return try await withCheckedThrowingContinuation { continuation in
            performTranscription(of: audioURL) { success, transcript in
                if success, let transcript = transcript {
                    continuation.resume(returning: transcript)
                } else {
                    continuation.resume(throwing: NSError(domain: "TranscriptionManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to transcribe audio"]))
                }
            }
        }
    }
    

    
    /// Cancels any ongoing transcription
    func cancelTranscription() {
        // Cancel the task on the main thread to avoid threading issues
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Only log if there's an active task being cancelled
            let hadActiveTask = self.recognitionTask != nil
            
            // Cancel the recognition task
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            self.recognitionRequest = nil
            
            // Update state
            self.isTranscribing = false
            
            // Only log if we actually cancelled something
            if hadActiveTask {
                logger.info("Transcription cancelled")
            }
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
                print("Failed to create speech recognizer")
                return
            }
            
            // Check if the recognizer is available
            if !recognizer.isAvailable {
                logger.error("Speech recognizer is not available on this device")
            }
            
            // Request authorization for speech recognition
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    self.logger.info("Speech recognition authorization granted")
                case .denied:
                    self.logger.error("Speech recognition authorization denied by user")
                case .restricted:
                    self.logger.error("Speech recognition is restricted on this device")
                case .notDetermined:
                    self.logger.warning("Speech recognition authorization not determined")
                @unknown default:
                    self.logger.warning("Speech recognition authorization unknown status")
                }
            }
        }
    }
    
    private func performTranscription(of audioURL: URL, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            autoreleasepool {
                guard let self = self else { return }
                
                // Cancel any existing recognition task first
                self.cancelTranscription()
                
                // Verify the audio file exists and has content
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: audioURL.path) {
                    self.logger.error("Audio file does not exist")
                    DispatchQueue.main.async {
                        self.isTranscribing = false
                        completion(false, nil)
                    }
                    return
                }
                
                // Check file size to ensure it's not empty
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: audioURL.path)
                    if let size = attributes[.size] as? NSNumber, size.intValue <= 1000 {
                        self.logger.warning("Audio file is very small, may not contain speech")
                    }
                } catch {
                    self.logger.error("Error checking audio file")
                }
                
                // Create a new recognizer with the US English locale
                let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
                guard let recognizer = recognizer else {
                    self.logger.error("Failed to create speech recognizer")
                    DispatchQueue.main.async {
                        self.isTranscribing = false
                        completion(false, nil)
                    }
                    return
                }
                
                // Check if the recognizer is available
                if !recognizer.isAvailable {
                    self.logger.error("Speech recognizer is not available")
                    // Try again after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        guard let self = self else { return }
                        self.performTranscription(of: audioURL, completion: completion)
                    }
                    return
                }
                
                // Create a URL recognition request
                let request = SFSpeechURLRecognitionRequest(url: audioURL)
                request.shouldReportPartialResults = true
                
                // Set task hints to improve recognition
                request.taskHint = .dictation
                
                // Add contextual phrases if needed
                request.contextualStrings = ["note", "Obsidian", "voice memo"]
                
                self.logger.debug("Created speech recognition request")
                
                // Start the recognition task with error handling and retry logic
                var retryCount = 0
                let maxRetries = 3
                
                func startRecognitionTask() {
                    self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                        guard let self = self else { return }
                        
                        // Handle successful results
                        if let result = result {
                            // Get the current transcript
                            let transcript = result.bestTranscription.formattedString
                            
                            // Update progress
                            let progress = Float(result.bestTranscription.segments.count) / 10.0 // Estimate
                            DispatchQueue.main.async {
                                self.transcriptionProgress = min(0.95, progress) // Cap at 95% until complete
                            }
                            
                            // If this is the final result
                            if result.isFinal {
                                let transcript = result.bestTranscription.formattedString
                                self.logger.info("Transcription completed successfully")
                                
                                DispatchQueue.main.async {
                                    self.transcriptionProgress = 1.0
                                    self.isTranscribing = false
                                    completion(true, transcript)
                                }
                            }
                        }
                        
                        // Handle errors with retry logic
                        if let error = error {
                            let nsError = error as NSError
                            // Log basic error info
                            self.logger.error("Speech recognition error: \(nsError.localizedDescription)")
                            
                            // Handle "No speech detected" error specifically
                            if nsError.localizedDescription.contains("No speech detected") {
                                self.logger.warning("No speech detected in the audio file")
                                
                                // Try one more time with a different approach
                                if retryCount < 1 {
                                    retryCount += 1
                                    
                                    // Cancel the current task
                                    self.recognitionTask?.cancel()
                                    self.recognitionTask = nil
                                    
                                    // Create a new request with different settings
                                    let newRequest = SFSpeechURLRecognitionRequest(url: audioURL)
                                    newRequest.shouldReportPartialResults = true
                                    newRequest.taskHint = .confirmation // Try a different hint
                                    
                                    // Wait a moment before retrying
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        self.recognitionTask = recognizer.recognitionTask(with: newRequest) { [weak self] result, retryError in
                                            // Handle the retry result
                                            if let result = result, result.isFinal, !result.bestTranscription.formattedString.isEmpty {
                                                self?.logger.info("Transcription successful after retry")
                                                DispatchQueue.main.async {
                                                    self?.transcriptionProgress = 1.0
                                                    self?.isTranscribing = false
                                                    completion(true, result.bestTranscription.formattedString)
                                                }
                                            } else if retryError != nil {
                                                self?.logger.error("Transcription retry failed")
                                                DispatchQueue.main.async {
                                                    self?.isTranscribing = false
                                                    completion(false, nil)
                                                }
                                            }
                                        }
                                    }
                                    return
                                }
                            }
                            
                            // Check for kAFAssistantErrorDomain errors (code 1101)
                            else if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101 {
                                self.logger.warning("Received common speech recognition error: \(nsError.domain) Code=\(nsError.code). This is usually non-fatal.")
                                
                                // Only retry if we haven't reached the final result yet
                                if result?.isFinal != true && retryCount < maxRetries {
                                    retryCount += 1
                                    self.logger.info("Retrying speech recognition (attempt \(retryCount) of \(maxRetries))")
                                    
                                    // Cancel the current task
                                    self.recognitionTask?.cancel()
                                    self.recognitionTask = nil
                                    
                                    // Wait a moment before retrying
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        startRecognitionTask()
                                    }
                                    return
                                }
                            }
                            
                            // For other errors or if we've exhausted retries
                            self.logger.error("Transcription error: \(error.localizedDescription)")
                            
                            // If we have partial results, use those rather than failing completely
                            if let partialTranscript = result?.bestTranscription.formattedString, !partialTranscript.isEmpty {
                                self.logger.info("Using partial transcript despite error")
                                DispatchQueue.main.async {
                                    self.transcriptionProgress = 1.0
                                    self.isTranscribing = false
                                    completion(true, partialTranscript)
                                }
                            } else {
                                // No transcript available
                                DispatchQueue.main.async {
                                    self.isTranscribing = false
                                    completion(false, nil)
                                }
                            }
                        }
                    }
                }
                
                // Start the initial recognition task
                startRecognitionTask()
            }
        }
    }
}
