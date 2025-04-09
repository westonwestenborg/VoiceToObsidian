import Foundation
import Speech
import Combine

/// Manages speech recognition and transcription
class TranscriptionManager: ObservableObject {
    // Published properties for UI updates
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Float = 0
    
    // Private properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Initializer
    init() {
        print("TranscriptionManager initialized (lightweight)")
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
        print("Starting async transcription of file: \(audioURL.path)")
        
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
            print("Speech recognition not authorized")
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
    
    /// Transcribes an audio file
    /// - Parameters:
    ///   - audioURL: The URL of the audio file to transcribe
    ///   - completion: Completion handler with success status and transcript
    @available(*, deprecated, message: "Use async/await transcribeAudioFileAsync(at:) instead")
    func transcribeAudioFile(at audioURL: URL, completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                let transcript = try await transcribeAudioFileAsync(at: audioURL)
                completion(true, transcript)
            } catch {
                print("Error in transcribeAudioFile: \(error)")
                completion(false, nil)
            }
        }
    }
    
    /// Cancels any ongoing transcription
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isTranscribing = false
    }
    
    // MARK: - Private Methods
    
    private func setupSpeechRecognition() {
        // Use autoreleasepool to help with memory management
        autoreleasepool {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            
            // Request authorization for speech recognition
            SFSpeechRecognizer.requestAuthorization { status in
                guard status == .authorized else {
                    print("Speech recognition authorization denied")
                    return
                }
                // Authorization successful
                print("Speech recognition authorization granted")
            }
        }
    }
    
    private func performTranscription(of audioURL: URL, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            autoreleasepool {
                guard let self = self else { return }
                
                let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
                guard let recognizer = recognizer, recognizer.isAvailable else {
                    print("Speech recognizer not available")
                    DispatchQueue.main.async {
                        self.isTranscribing = false
                        completion(false, nil)
                    }
                    return
                }
                
                let request = SFSpeechURLRecognitionRequest(url: audioURL)
                request.shouldReportPartialResults = true
                
                print("Created speech recognition request")
                
                self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    guard let self = self else { return }
                    
                    if let result = result {
                        // Update progress
                        let progress = Float(result.bestTranscription.segments.count) / 10.0 // Estimate
                        DispatchQueue.main.async {
                            self.transcriptionProgress = min(0.95, progress) // Cap at 95% until complete
                        }
                        
                        // If this is the final result
                        if result.isFinal {
                            let transcript = result.bestTranscription.formattedString
                            print("Transcription completed successfully")
                            
                            DispatchQueue.main.async {
                                self.transcriptionProgress = 1.0
                                self.isTranscribing = false
                                completion(true, transcript)
                            }
                        }
                    }
                    
                    if let error = error {
                        print("Transcription error: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.isTranscribing = false
                            completion(false, nil)
                        }
                    }
                }
            }
        }
    }
}
