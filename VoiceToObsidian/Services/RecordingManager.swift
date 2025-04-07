import Foundation
import AVFoundation
import Combine

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
        stopRecording(completion: { _, _, _ in })
        durationTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Starts recording audio
    /// - Parameter completion: Completion handler with success status
    func startRecording(completion: @escaping (Bool) -> Void) {
        print("Starting recording...")
        
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
    
    /// Stops recording audio
    /// - Parameter completion: Completion handler with success status, recording URL, and duration
    func stopRecording(completion: @escaping (Bool, URL?, TimeInterval) -> Void) {
        guard let recorder = audioRecorder, 
              let recordingURL = currentRecordingURL, 
              let startTime = recordingStartTime else {
            completion(false, nil, 0)
            return
        }
        
        // Stop recording
        recorder.stop()
        audioRecorder = nil
        
        // Stop the duration timer properly
        if let timer = durationTimer {
            timer.invalidate()
            durationTimer = nil
        }
        
        // Calculate recording duration
        let duration = recorder.currentTime
        
        // Update state
        isRecording = false
        
        // Keep the recording duration displayed until processing is complete
        // We'll reset it later with resetRecordingDuration()
        
        // Return the recording URL and duration
        completion(true, recordingURL, duration)
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
            
            // Start a timer to update the recording duration
            // Make sure the timer runs on the main thread and updates the published property
            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let recorder = self.audioRecorder else { return }
                DispatchQueue.main.async {
                    self.recordingDuration = recorder.currentTime
                }
            }
            
            // Ensure the timer is added to the main run loop
            RunLoop.main.add(durationTimer!, forMode: .common)
            
            // Update state
            isRecording = true
            
            completion(true)
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            completion(false)
        }
    }
}
