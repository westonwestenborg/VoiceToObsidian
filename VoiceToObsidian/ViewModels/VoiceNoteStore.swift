import Foundation
import AVFoundation
import Speech
import Combine

class VoiceNoteStore: ObservableObject {
    @Published var voiceNotes: [VoiceNote] = []
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession?
    private var currentRecordingURL: URL?
    private var recordingStartTime: Date?
    
    // For speech recognition
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Anthropic API key - to be set by the user
    private var anthropicAPIKey: String = UserDefaults.standard.string(forKey: "AnthropicAPIKey") ?? ""
    
    // Path to Obsidian vault - to be set by the user
    private var obsidianVaultPath: String = UserDefaults.standard.string(forKey: "ObsidianVaultPath") ?? ""
    
    init(previewData: Bool = false) {
        if previewData {
            voiceNotes = VoiceNote.sampleNotes
        } else {
            loadVoiceNotes()
            setupSpeechRecognition()
        }
    }
    
    // MARK: - Voice Recording
    
    func startRecording(completion: @escaping (Bool) -> Void) {
        // Set up the recording session
        let session = AVAudioSession.sharedInstance()
        recordingSession = session
        
        // Check if we already have permission before requesting it
        if session.recordPermission == .granted {
            do {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                self.startRecordingAudio(completion: completion)
            } catch {
                print("Failed to set up recording session: \(error.localizedDescription)")
                completion(false)
            }
        } else {
            // Request microphone permission
            session.requestRecordPermission { [weak self] allowed in
                DispatchQueue.main.async {
                    guard let self = self, allowed else {
                        print("Microphone permission denied")
                        completion(false)
                        return
                    }
                    
                    do {
                        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                        try session.setActive(true, options: .notifyOthersOnDeactivation)
                        self.startRecordingAudio(completion: completion)
                    } catch {
                        print("Failed to set up recording session after permission: \(error.localizedDescription)")
                        completion(false)
                    }
                }
            }
        }
    }
    
    private func startRecordingAudio(completion: @escaping (Bool) -> Void) {
        // Create a unique filename for the recording
        let audioFilename = "\(UUID().uuidString).m4a"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        currentRecordingURL = documentsDirectory.appendingPathComponent(audioFilename)
        
        // Set up the audio recorder
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: currentRecordingURL!, settings: settings)
            audioRecorder?.record()
            recordingStartTime = Date()
            
            // Start speech recognition
            startSpeechRecognition()
            
            completion(true)
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    func stopRecording(completion: @escaping (Bool, VoiceNote?) -> Void) {
        guard let recorder = audioRecorder, let recordingURL = currentRecordingURL, let startTime = recordingStartTime else {
            completion(false, nil)
            return
        }
        
        // Stop recording
        recorder.stop()
        audioRecorder = nil
        
        // Stop speech recognition
        stopSpeechRecognition { [weak self] success, transcript in
            guard let self = self, success, let transcript = transcript else {
                completion(false, nil)
                return
            }
            
            // Process the transcript with Anthropic API
            // Create an instance of AnthropicService to process the transcript
            let anthropicService = AnthropicService(apiKey: self.anthropicAPIKey)
            anthropicService.processTranscript(transcript) { success, cleanedTranscript, suggestedTitle in
                // If the API call fails, use the original transcript and a default title
                let finalTranscript = cleanedTranscript ?? transcript
                
                // Generate a default title if needed
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                let dateString = dateFormatter.string(from: Date())
                let finalTitle = suggestedTitle ?? "Voice Note \(dateString)"
                
                print("Final title: \(finalTitle)")
                print("Using transcript: \(success ? "cleaned by Claude" : "original")")
                
                // Calculate recording duration
                let duration = recorder.currentTime
                
                // Create voice note
                let voiceNote = VoiceNote(
                    title: finalTitle,
                    originalTranscript: transcript,
                    cleanedTranscript: finalTranscript,
                    duration: duration,
                    creationDate: startTime,
                    audioFilename: recordingURL.lastPathComponent
                )
                
                // Check if Obsidian vault path is set
                if !self.obsidianVaultPath.isEmpty {
                    print("Saving to Obsidian vault at: \(self.obsidianVaultPath)")
                    
                    // Access the security-scoped bookmark if available
                    var vaultURL: URL?
                    var didStartAccessing = false
                    
                    if let bookmarkData = UserDefaults.standard.data(forKey: "ObsidianVaultBookmark") {
                        do {
                            var isStale = false
                            vaultURL = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
                            
                            if isStale {
                                print("Bookmark is stale, need to get a new one")
                            } else {
                                print("Successfully resolved bookmark to: \(vaultURL?.path ?? "unknown")")
                                didStartAccessing = vaultURL?.startAccessingSecurityScopedResource() ?? false
                            }
                        } catch {
                            print("Failed to resolve bookmark: \(error.localizedDescription)")
                        }
                    }
                    
                    // Create an instance of ObsidianService to save the note
                    let obsidianService = ObsidianService(vaultPath: self.obsidianVaultPath)
                    
                    // First copy the audio file to the Obsidian vault
                    obsidianService.copyAudioFileToVault(from: recordingURL) { audioSuccess in
                        print("Audio file copy result: \(audioSuccess)")
                        
                        // Then create the markdown note
                        obsidianService.createVoiceNoteFile(for: voiceNote) { noteSuccess, obsidianPath in
                            print("Note creation result: \(noteSuccess), path: \(obsidianPath ?? "none")")
                            
                            // Stop accessing the security-scoped resource
                            if didStartAccessing, let url = vaultURL {
                                url.stopAccessingSecurityScopedResource()
                                print("Stopped accessing security-scoped resource")
                            }
                            
                            var updatedVoiceNote = voiceNote
                            if noteSuccess, let path = obsidianPath {
                                updatedVoiceNote.obsidianPath = path
                            }
                            
                            // Add to store and save
                            self.voiceNotes.append(updatedVoiceNote)
                            self.saveVoiceNotes()
                            
                            completion(true, updatedVoiceNote)
                        }
                    }
                } else {
                    print("Obsidian vault path not set, skipping Obsidian integration")
                    
                    // Still add to store and save even if Obsidian integration is skipped
                    self.voiceNotes.append(voiceNote)
                    self.saveVoiceNotes()
                    
                    completion(true, voiceNote)
                }
            }
        }
    }
    
    // MARK: - Speech Recognition
    
    private func setupSpeechRecognition() {
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
    
    private func startSpeechRecognition() {
        // Initialize speech recognizer
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        // For development purposes, we'll use file-based transcription instead of live recognition
        print("Speech recognition initialized - will use file-based transcription")
        
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    print("Speech recognition authorization denied")
                case .restricted:
                    print("Speech recognition restricted on this device")
                case .notDetermined:
                    print("Speech recognition authorization not determined")
                @unknown default:
                    print("Unknown authorization status")
                }
            }
        }
        
        // The following is the old live recognition code, kept for reference
        /*
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        // Create a recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create speech recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let error = error {
                print("Speech recognition error: \(error.localizedDescription)")
                self?.stopSpeechRecognition { _, _ in }
            }
        }
        
        // Connect audio input to recognition request
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("Audio engine error: \(error.localizedDescription)")
        }
        */
    }
    
    private func stopSpeechRecognition(completion: @escaping (Bool, String?) -> Void) {
        guard let audioURL = currentRecordingURL else {
            print("No recording URL available for transcription")
            completion(false, nil)
            return
        }
        
        // Use file-based transcription instead of live recognition
        print("Transcribing audio file at: \(audioURL.path)")
        transcribeAudioFile(at: audioURL) { success, transcript in
            if success, let transcript = transcript {
                print("Transcription successful: \(transcript.prefix(100))...")
                completion(true, transcript)
            } else {
                print("Transcription failed, using fallback text")
                // Fallback to a simulated transcript if transcription fails
                let fallbackTranscript = "This is a fallback transcript. The actual speech recognition failed. Please check your microphone permissions and try again."
                completion(true, fallbackTranscript)
            }
        }
    }
    
    private func transcribeAudioFile(at audioURL: URL, completion: @escaping (Bool, String?) -> Void) {
        print("Starting transcription of file: \(audioURL.path)")
        
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("Speech recognizer not available")
            completion(false, nil)
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        
        print("Created speech recognition request")
        
        recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                print("Transcription error: \(error.localizedDescription)")
                completion(false, nil)
                return
            }
            
            if let result = result {
                let transcript = result.bestTranscription.formattedString
                print("Transcription completed successfully")
                completion(true, transcript)
            } else {
                print("No transcription result returned")
                completion(false, nil)
            }
        }
    }
    
    // MARK: - LLM Processing
    // Note: LLM processing is now handled by the AnthropicService class
    
    // MARK: - Obsidian Integration
    // Note: Obsidian integration is now handled by the ObsidianService class
    
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
    
    // MARK: - Persistence
    
    private func saveVoiceNotes() {
        do {
            let data = try JSONEncoder().encode(voiceNotes)
            let url = getVoiceNotesFileURL()
            try data.write(to: url)
        } catch {
            print("Failed to save voice notes: \(error.localizedDescription)")
        }
    }
    
    private func loadVoiceNotes() {
        let url = getVoiceNotesFileURL()
        
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                voiceNotes = try JSONDecoder().decode([VoiceNote].self, from: data)
            } catch {
                print("Failed to load voice notes: \(error.localizedDescription)")
                voiceNotes = []
            }
        } else {
            voiceNotes = []
        }
    }
    
    private func getVoiceNotesFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("voiceNotes.json")
    }
    
    // MARK: - Configuration
    
    func setAnthropicAPIKey(_ key: String) {
        anthropicAPIKey = key
        UserDefaults.standard.set(key, forKey: "AnthropicAPIKey")
    }
    
    func setObsidianVaultPath(_ path: String) {
        obsidianVaultPath = path
        UserDefaults.standard.set(path, forKey: "ObsidianVaultPath")
    }
}
