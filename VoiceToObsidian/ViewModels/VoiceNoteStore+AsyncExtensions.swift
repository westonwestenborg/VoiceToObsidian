import Foundation
import AVFoundation
import Speech
import Combine
import SwiftUI
import OSLog

// MARK: - Swift Concurrency Extensions for VoiceNoteStore
extension VoiceNoteStore {
    
    // Logger for async extensions
    private var asyncLogger: Logger {
        Logger(subsystem: "com.voicetoobsidian.app", category: "VoiceNoteStore.Async")
    }
    
    /// Start recording using async/await pattern
    /// - Returns: Boolean indicating success
    /// - Throws: AppError if recording fails
    @available(iOS 15.0, *)
    func startRecordingAsync() async throws -> Bool {
        asyncLogger.debug("Starting recording with async/await")
        
        // Set up the recording session
        let session = AVAudioSession.sharedInstance()
        recordingSession = session
        
        // Check if we already have permission
        if session.recordPermission == .granted {
            return try await setupRecordingSession(session: session)
        } else {
            // Request microphone permission
            let allowed = await withCheckedContinuation { continuation in
                session.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            
            if !allowed {
                let permissionError = AppError.recording(.permissionDenied)
                await MainActor.run {
                    self.handleError(permissionError)
                }
                asyncLogger.error("Microphone permission denied")
                throw permissionError
            }
            
            return try await setupRecordingSession(session: session)
        }
    }
    
    /// Set up the recording session with async/await
    /// - Parameter session: The AVAudioSession to set up
    /// - Returns: Boolean indicating success
    /// - Throws: AppError if setup fails
    @available(iOS 15.0, *)
    private func setupRecordingSession(session: AVAudioSession) async throws -> Bool {
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            return try await startRecordingAudioAsync()
        } catch {
            let appError = AppError.recording(.audioSessionSetupFailed(error.localizedDescription))
            await MainActor.run {
                self.handleError(appError)
            }
            asyncLogger.error("Failed to set up recording session: \(error.localizedDescription)")
            throw appError
        }
    }
    
    /// Start recording audio with async/await
    /// - Returns: Boolean indicating success
    /// - Throws: AppError if recording fails
    @available(iOS 15.0, *)
    private func startRecordingAudioAsync() async throws -> Bool {
        // Create a unique filename for the recording
        let audioFilename = "\(UUID().uuidString).m4a"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsDirectory.appendingPathComponent(audioFilename)
        currentRecordingURL = audioURL
        
        // Set up the audio recorder
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Start recording
            if audioRecorder?.record() == true {
                recordingStartTime = Date()
                await MainActor.run {
                    self.isRecording = true
                }
                asyncLogger.debug("Recording started successfully")
                return true
            } else {
                let recordingError = AppError.recording(.recordingFailed("Failed to start recording"))
                await MainActor.run {
                    self.handleError(recordingError)
                }
                asyncLogger.error("Failed to start recording")
                throw recordingError
            }
        } catch {
            let recordingError = AppError.recording(.recordingFailed(error.localizedDescription))
            await MainActor.run {
                self.handleError(recordingError)
            }
            asyncLogger.error("Error setting up audio recorder: \(error.localizedDescription)")
            throw recordingError
        }
    }
    
    /// Stop recording using async/await pattern
    /// - Returns: The recorded voice note
    /// - Throws: AppError if stopping recording fails
    @available(iOS 15.0, *)
    func stopRecordingAsync() async throws -> VoiceNote? {
        asyncLogger.debug("Stopping recording with async/await")
        
        guard let audioRecorder = audioRecorder, let recordingURL = currentRecordingURL, let startTime = recordingStartTime else {
            let error = AppError.recording(.recordingFailed("No active recording to stop"))
            await MainActor.run {
                self.handleError(error)
            }
            asyncLogger.error("No active recording to stop")
            throw error
        }
        
        // Stop recording
        audioRecorder.stop()
        
        // Reset audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            asyncLogger.error("Error deactivating audio session: \(error.localizedDescription)")
            // Continue anyway, this is not critical
        }
        
        // Calculate duration
        let duration = Date().timeIntervalSince(startTime)
        
        // Reset recording state
        await MainActor.run {
            self.isRecording = false
            self.isProcessing = true
        }
        
        // Transcribe the audio file
        do {
            let transcript = try await transcribeAudioFileAsync(url: recordingURL)
            
            // Create a voice note
            let voiceNote = VoiceNote(
                id: UUID(),
                title: DateFormatUtil.shared.formatTimestamp(date: startTime),
                transcript: transcript,
                cleanedTranscript: transcript,
                duration: duration,
                creationDate: startTime,
                audioFilename: recordingURL.lastPathComponent
            )
            
            // Add to voice notes array
            await MainActor.run {
                self.voiceNotes.insert(voiceNote, at: 0)
                self.isProcessing = false
            }
            
            asyncLogger.debug("Recording stopped and transcribed successfully")
            return voiceNote
        } catch {
            await MainActor.run {
                self.isProcessing = false
            }
            
            if let appError = error as? AppError {
                await MainActor.run {
                    self.handleError(appError)
                }
                throw appError
            } else {
                let transcriptionError = AppError.transcription(.fileTranscriptionFailed(error.localizedDescription))
                await MainActor.run {
                    self.handleError(transcriptionError)
                }
                throw transcriptionError
            }
        }
    }
    
    /// Transcribe an audio file using async/await pattern
    /// - Parameter url: URL of the audio file to transcribe
    /// - Returns: The transcription text
    /// - Throws: AppError if transcription fails
    @available(iOS 15.0, *)
    func transcribeAudioFileAsync(url: URL) async throws -> String {
        asyncLogger.debug("Transcribing audio file with async/await: \(url.lastPathComponent)")
        
        // Check if speech recognizer is available
        guard let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), speechRecognizer.isAvailable else {
            let error = AppError.transcription(.speechRecognizerUnavailable)
            asyncLogger.error("Speech recognizer unavailable")
            throw error
        }
        
        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        // Perform recognition
        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
                speechRecognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let result = result, result.isFinal else {
                        return
                    }
                    
                    continuation.resume(returning: result)
                }
            }
            
            // Get the best transcription
            let transcript = result.bestTranscription.formattedString
            asyncLogger.debug("Transcription completed successfully")
            return transcript
        } catch {
            asyncLogger.error("Transcription failed: \(error.localizedDescription)")
            throw AppError.transcription(.fileTranscriptionFailed(error.localizedDescription))
        }
    }
    
    /// Process a voice note with Anthropic API using async/await
    /// - Parameter voiceNote: The voice note to process
    /// - Returns: The processed voice note
    /// - Throws: AppError if processing fails
    @available(iOS 15.0, *)
    func processWithAnthropicAsync(voiceNote: VoiceNote) async throws -> VoiceNote {
        asyncLogger.debug("Processing voice note with Anthropic API using async/await")
        
        guard !anthropicAPIKey.isEmpty else {
            let error = AppError.anthropic(.apiKeyMissing)
            asyncLogger.error("Anthropic API key is missing")
            throw error
        }
        
        // Create AnthropicService
        let anthropicService = AnthropicService(apiKey: anthropicAPIKey)
        
        do {
            // Process the transcript
            let cleanedTranscript = try await anthropicService.processTranscriptAsync(transcript: voiceNote.transcript)
            
            // Create updated voice note
            var updatedVoiceNote = voiceNote
            updatedVoiceNote.cleanedTranscript = cleanedTranscript
            
            asyncLogger.debug("Voice note processed successfully with Anthropic API")
            return updatedVoiceNote
        } catch {
            asyncLogger.error("Failed to process with Anthropic API: \(error.localizedDescription)")
            if let appError = error as? AppError {
                throw appError
            } else {
                throw AppError.anthropic(.networkError(error.localizedDescription))
            }
        }
    }
    
    /// Save a voice note to Obsidian vault using async/await
    /// - Parameter voiceNote: The voice note to save
    /// - Returns: Boolean indicating success
    /// - Throws: AppError if saving fails
    @available(iOS 15.0, *)
    func saveToObsidianAsync(voiceNote: VoiceNote) async throws -> Bool {
        asyncLogger.debug("Saving voice note to Obsidian vault using async/await")
        
        guard !obsidianVaultPath.isEmpty else {
            let error = AppError.obsidian(.vaultPathMissing)
            asyncLogger.error("Obsidian vault path is missing")
            throw error
        }
        
        // Create ObsidianService
        let obsidianService = ObsidianService(vaultPath: obsidianVaultPath)
        
        do {
            // Save the voice note
            let result = try await obsidianService.createVoiceNoteFile(for: voiceNote)
            
            if result.success {
                // Copy the audio file
                if let audioURL = getAudioFileURL(for: voiceNote) {
                    let copyResult = try await obsidianService.copyAudioFileToVault(from: audioURL)
                    asyncLogger.debug("Audio file copied to Obsidian vault: \(copyResult)")
                }
                
                asyncLogger.debug("Voice note saved to Obsidian vault successfully")
                return true
            } else {
                asyncLogger.error("Failed to save voice note to Obsidian vault")
                throw AppError.obsidian(.fileCreationFailed("Failed to create note file"))
            }
        } catch {
            asyncLogger.error("Error saving to Obsidian: \(error.localizedDescription)")
            if let appError = error as? AppError {
                throw appError
            } else {
                throw AppError.obsidian(.fileCreationFailed(error.localizedDescription))
            }
        }
    }
    
    /// Helper method to get the URL for a voice note's audio file
    /// - Parameter voiceNote: The voice note
    /// - Returns: URL of the audio file, if it exists
    private func getAudioFileURL(for voiceNote: VoiceNote) -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsDirectory.appendingPathComponent(voiceNote.audioFilename)
        
        if FileManager.default.fileExists(atPath: audioURL.path) {
            return audioURL
        } else {
            asyncLogger.error("Audio file not found: \(voiceNote.audioFilename)")
            return nil
        }
    }
    

}
