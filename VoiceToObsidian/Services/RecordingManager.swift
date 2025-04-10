import Foundation
import AVFoundation
import Combine
import SwiftUI

/// Manages audio recording functionality
class RecordingManager: ObservableObject {
    // Published properties for UI updates
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    
    // Private properties
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession?
    private var currentRecordingURL: URL?
    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    
    // Initializer
    init() {
        print("RecordingManager initialized")
    }
    
    deinit {
        // Use Task to call the async method in deinit
        Task {
            do {
                _ = try? await stopRecordingAsync()
            }
        }
        durationTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Starts recording audio using async/await
    /// - Returns: Boolean indicating success
    /// - Throws: Error if recording fails
    func startRecordingAsync() async throws -> Bool {
        print("Starting recording with async/await...")
        
        // Set up the recording session
        let session = AVAudioSession.sharedInstance()
        recordingSession = session
        
        // Check if we already have permission
        if session.recordPermission == .granted {
            return try await setupRecordingSessionAsync(session: session)
        } else {
            // Request microphone permission
            let allowed = await withCheckedContinuation { continuation in
                session.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            
            if !allowed {
                print("Microphone permission denied")
                throw NSError(domain: "RecordingManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
            }
            
            return try await setupRecordingSessionAsync(session: session)
        }
    }
    

    
    /// Stops recording audio using async/await
    /// - Returns: The recorded voice note
    /// - Throws: Error if stopping recording fails
    func stopRecordingAsync() async throws -> VoiceNote? {
        print("Stopping recording with async/await...")
        
        guard let recorder = audioRecorder,
              let recordingURL = currentRecordingURL,
              let startTime = recordingStartTime else {
            throw NSError(domain: "RecordingManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No active recording to stop"])
        }
        
        // Ensure we've been recording for at least 1 second to capture audio
        let currentDuration = recorder.currentTime
        if currentDuration < 0.5 {
            print("Recording duration too short (\(currentDuration)s), waiting to ensure audio is captured...")
            // Wait a bit to ensure we capture some audio
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        // Verify the recording URL exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: recordingURL.path) {
            print("Warning: Recording file does not exist before stopping: \(recordingURL.path)")
        }
        
        // Get a reference to the recorder before stopping
        let recorderRef = recorder
        
        // Capture the duration BEFORE stopping the recorder
        let duration = recorderRef.currentTime
        
        // Stop recording
        recorderRef.stop()
        
        // Wait a moment to ensure the file is properly written
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify the recording was saved
        if !fileManager.fileExists(atPath: recordingURL.path) {
            print("Error: Recording file was not created after stopping: \(recordingURL.path)")
            throw NSError(domain: "RecordingManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Recording file was not created"])
        }
        
        // Get the file size to verify it's not empty
        var fileSize: Int = 0
        do {
            let attributes = try fileManager.attributesOfItem(atPath: recordingURL.path)
            if let fileSizeNumber = attributes[.size] as? NSNumber {
                fileSize = fileSizeNumber.intValue
                // File size captured for debugging if needed
                if fileSize <= 0 {
                    print("Error: Recording file is empty")
                    throw NSError(domain: "RecordingManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Recording file is empty"])
                }
            }
        } catch {
            print("Error checking recording file: \(error.localizedDescription)")
        }
        
        // Duration was already captured before stopping the recorder
        print("Using previously captured recording duration: \(duration) seconds")
        
        // Clean up resources
        audioRecorder = nil
        
        // Stop the duration timer properly
        if let timer = durationTimer {
            timer.invalidate()
            durationTimer = nil
        }
        
        // Update state on the main thread
        await MainActor.run {
            isRecording = false
            // Keep the recording duration displayed until processing is complete
            // We'll reset it later with resetRecordingDuration()
        }
        
        // Create a basic voice note with the recording information
        // The transcript will be added later by the transcription process
        let voiceNote = VoiceNote(
            id: UUID(),
            title: "Voice Note \(DateFormatUtil.shared.formatTimestamp(date: startTime))",
            originalTranscript: "",  // Will be filled in by transcription
            cleanedTranscript: "",   // Will be filled in by Anthropic
            duration: duration,
            creationDate: startTime,
            audioFilename: recordingURL.lastPathComponent
        )
        
        print("Successfully created voice note")
        return voiceNote
    }
    

    
    /// Gets the current recording URL
    /// - Returns: The URL of the current recording, if any
    func getCurrentRecordingURL() -> URL? {
        return currentRecordingURL
    }
    
    /// Gets the recording start time
    /// - Returns: The start time of the current recording, if any
    func getRecordingStartTime() -> Date? {
        return recordingStartTime
    }
    
    /// Resets the recording duration to zero
    /// Call this after processing is complete
    func resetRecordingDuration() {
        recordingDuration = 0
    }
    
    // MARK: - Private Methods
    
    /// Set up the recording session with async/await
    /// - Parameter session: The AVAudioSession to set up
    /// - Returns: Boolean indicating success
    /// - Throws: Error if setup fails
    private func setupRecordingSessionAsync(session: AVAudioSession) async throws -> Bool {
        do {
            // Configure the audio session for recording
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            
            // Set the preferred sample rate and I/O buffer duration
            try session.setPreferredSampleRate(44100.0)
            try session.setPreferredIOBufferDuration(0.005)
            
            // Activate the session with options
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("Audio session successfully configured with sample rate: \(session.sampleRate)")
            
            // Removed intentional delay to reduce latency
            
            return try await startRecordingAudioAsync()
        } catch {
            print("Failed to set up recording session: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Start recording audio with async/await
    /// - Returns: Boolean indicating success
    /// - Throws: Error if recording fails
    private func startRecordingAudioAsync() async throws -> Bool {
        // Create a unique filename for the recording
        let audioFilename = "\(UUID().uuidString).m4a"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        currentRecordingURL = documentsDirectory.appendingPathComponent(audioFilename)
        
        // Set up the audio recorder with original working settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]
        
        do {
            guard let recordingURL = currentRecordingURL else {
                throw NSError(domain: "RecordingManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create recording URL"])
            }
            
            // Delete any existing file at the URL
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: recordingURL.path) {
                try fileManager.removeItem(at: recordingURL)
                print("Removed existing file at recording URL")
            }
            
            // Create and configure the audio recorder
            let recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            recorder.delegate = self as? AVAudioRecorderDelegate // Set delegate if needed
            recorder.prepareToRecord() // Prepare the recorder
            recorder.isMeteringEnabled = true // Enable metering for audio levels
            
            // Start recording
            let success = recorder.record()
            if !success {
                throw NSError(domain: "RecordingManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])
            }
            
            // Store the recorder and start time
            audioRecorder = recorder
            recordingStartTime = Date()
            
            // Update UI state immediately before setting up timer (latency improvement)
            await MainActor.run {
                // Update state first for immediate UI feedback
                self.isRecording = true
                
                // Then set up the timer for ongoing updates
                self.durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self, let recorder = self.audioRecorder else { return }
                    self.recordingDuration = recorder.currentTime
                    
                    // Update metering if needed
                    if recorder.isMeteringEnabled {
                        recorder.updateMeters()
                    }
                }
                
                // Ensure the timer is added to the main run loop
                if let timer = self.durationTimer {
                    RunLoop.main.add(timer, forMode: .common)
                }
            }
            
            print("Recording started successfully")
            return true
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            throw error
        }
    }
    


}
