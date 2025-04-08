import Foundation
import AVFoundation
import Speech
import Combine
import SwiftUI
import OSLog

class VoiceNoteStore: ObservableObject, ErrorHandling {
    @Published var voiceNotes: [VoiceNote] = []
    @Published var isLoadingNotes: Bool = false
    @Published var loadedAllNotes: Bool = false
    
    // Error handling properties
    @Published var errorState: AppError?
    @Published var isShowingError: Bool = false
    
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
    
    // MARK: - Voice Recording
    
    // Deprecated callback-based startRecording method removed - using async version only
    
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
            guard let recordingURL = currentRecordingURL else {
                let error = AppError.recording(.audioFileCreationFailed)
                handleError(error)
                completion(false)
                return
            }
            
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.record()
            recordingStartTime = Date()
            
            // Start speech recognition
            startSpeechRecognition()
            
            completion(true)
        } catch {
            let appError = AppError.recording(.recordingFailed(error.localizedDescription))
            handleError(appError)
            print("Failed to start recording: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // Deprecated callback-based stopRecording method removed - using async version only
    
    // MARK: - Speech Recognition
    
    private func setupSpeechRecognition() {
        // Use autoreleasepool to help with memory management
        autoreleasepool {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            
            // Request authorization for speech recognition
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    switch status {
                    case .authorized:
                        print("Speech recognition authorization granted")
                    case .denied:
                        let error = AppError.transcription(.speechRecognizerUnavailable)
                        self.handleError(error)
                        print("Speech recognition authorization denied")
                    case .restricted:
                        let error = AppError.transcription(.speechRecognizerUnavailable)
                        self.handleError(error)
                        print("Speech recognition restricted on this device")
                    case .notDetermined:
                        print("Speech recognition not determined")
                    @unknown default:
                        print("Unknown authorization status")
                    }
                }
            }
        } // Close autoreleasepool
    }
    
    private func startSpeechRecognition() {
        // Initialize speech recognizer
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            let error = AppError.transcription(.speechRecognizerUnavailable)
            handleError(error)
            print("Speech recognizer not available")
            return
        }
        
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
            let error = AppError.transcription(.speechRecognizerUnavailable)
            handleError(error)
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
    
    // MARK: - Pagination and Loading
    
    /// Loads the next page of voice notes
    func loadMoreVoiceNotes() {
        guard !isLoadingNotes && !loadedAllNotes else { return }
        
        isLoadingNotes = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            autoreleasepool {
                guard let self = self else { return }
                
                // Ensure initialization is complete
                if !self.hasInitialized {
                    self.performDeferredInitialization()
                }
                
                self.loadVoiceNotesPage(page: self.currentPage)
                
                DispatchQueue.main.async {
                    self.isLoadingNotes = false
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
                    // Append to existing notes
                    self.voiceNotes.append(contentsOf: pageNotes)
                    self.currentPage += 1
                    
                    // Check if we've loaded all notes
                    if endIndex >= allNotes.count {
                        self.loadedAllNotes = true
                    }
                    
                    print("Loaded page \(page) with \(pageNotes.count) notes. Total: \(self.voiceNotes.count)")
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
