import Foundation
import AVFoundation
import Combine
import SwiftUI
import OSLog

/// A manager that handles audio recording functionality with background processing support.
///
/// `RecordingManager` provides comprehensive audio recording capabilities including:
/// - Starting and stopping recordings
/// - Managing recording sessions and permissions
/// - Handling audio interruptions (calls, other apps)
/// - Supporting background recording when the app is minimized
/// - Tracking recording duration
/// - Proper resource management
///
/// The class is designed to work within the MVVM architecture pattern and is marked with
/// `@MainActor` to ensure all UI updates happen on the main thread.
///
/// - Important: This class requires microphone permission to function properly.
///
/// ## Example Usage
/// ```swift
/// let recordingManager = RecordingManager()
///
/// // Start recording
/// do {
///     let success = try await recordingManager.startRecordingAsync()
///     if success {
///         print("Recording started successfully")
///     }
/// } catch {
///     print("Failed to start recording: \(error)")
/// }
///
/// // Later, stop recording
/// do {
///     let voiceNote = try await recordingManager.stopRecordingAsync()
///     if let voiceNote = voiceNote {
///         print("Recording saved: \(voiceNote.title)")
///     }
/// } catch {
///     print("Failed to stop recording: \(error)")
/// }
/// ```
@MainActor
class RecordingManager: ObservableObject {
    /// Indicates whether audio recording is currently in progress.
    ///
    /// This property is observed by UI components to show appropriate recording states.
    @Published var isRecording = false
    
    /// The duration of the current recording in seconds.
    ///
    /// This property is continuously updated while recording is in progress and can be
    /// used to display a timer in the UI.
    @Published var recordingDuration: TimeInterval = 0
    
    // MARK: - Private Properties
    
    /// The audio recorder instance used for recording.
    private var audioRecorder: AVAudioRecorder?
    
    /// Reference to the shared audio session.
    private var recordingSession: AVAudioSession?
    
    /// The URL where the current recording is being saved.
    private var currentRecordingURL: URL?
    
    /// The timestamp when the current recording started.
    private var recordingStartTime: Date?
    
    /// Timer used to update the recording duration.
    private var durationTimer: Timer?
    
    /// Background task identifier for continuing recording when app is in background.
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    /// Logger for structured logging of recording operations.
    ///
    /// Uses OSLog for efficient and structured logging throughout the recording process.
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "RecordingManager")
    
    // MARK: - Initialization
    
    /// Initializes a new RecordingManager instance.
    ///
    /// This initializer sets up notification observers for handling audio interruptions
    /// and app state changes.
    init() {
        logger.info("RecordingManager initialized")
        setupNotifications()
    }
    
    /// Sets up notification observers for audio session interruptions and app state changes.
    ///
    /// This method registers observers for:
    /// - Audio session interruptions (phone calls, other apps using audio)
    /// - App lifecycle events (entering background, becoming active)
    /// - Audio route changes (headphones connected/disconnected)
    ///
    /// These observers ensure the recording continues properly across different system events.
    private func setupNotifications() {
        // Audio session interruption notifications
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioSessionInterruption(notification: notification)
        }
        
        // App entering background notification
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppDidEnterBackground(notification: notification)
        }
        
        // App becoming active notification
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppWillEnterForeground(notification: notification)
        }
        
        // Route change notifications (e.g., headphones connected/disconnected)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioRouteChange(notification: notification)
        }
    }
    
    /// Cleans up resources when the RecordingManager is deallocated.
    ///
    /// This method ensures proper cleanup by:
    /// - Stopping any active recording
    /// - Invalidating timers
    /// - Removing notification observers
    /// - Ending background tasks
    ///
    /// - Note: Since this is a `@MainActor` class, we need special handling in deinit.
    deinit {
        // Use Task to call the async method in deinit
        Task {
            do {
                _ = try? await stopRecordingAsync()
            }
        }
        durationTimer?.invalidate()
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        // End background task if active - handle directly instead of calling MainActor-isolated method
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            
            // We can't log directly here since logger might require MainActor
            // but we can schedule a task for logging
            Task { @MainActor in
                logger.info("Background task ended in deinit")
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Starts recording audio using async/await pattern with background support.
    ///
    /// This method handles the entire recording setup process including:
    /// - Requesting microphone permissions if needed
    /// - Setting up the audio session
    /// - Creating a file to store the recording
    /// - Starting the recording process
    /// - Setting up background task support
    /// - Starting the duration timer
    ///
    /// - Returns: Boolean indicating whether recording started successfully
    /// - Throws: Error if recording fails for any reason, including permission denied
    ///
    /// - Note: This method updates `isRecording` and starts updating `recordingDuration`
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let success = try await recordingManager.startRecordingAsync()
    ///     if success {
    ///         // Recording started
    ///     }
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
    func startRecordingAsync() async throws -> Bool {
        logger.info("Starting recording with async/await...")
        
        // Begin background task to ensure we have time to start recording
        beginBackgroundTask()
        
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
                logger.error("Microphone permission denied")
                endBackgroundTaskIfNeeded()
                throw NSError(domain: "RecordingManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
            }
            
            return try await setupRecordingSessionAsync(session: session)
        }
    }
    

    
    /// Stops recording audio using async/await pattern.
    ///
    /// This method handles the entire process of stopping a recording including:
    /// - Ensuring the recording has captured sufficient audio
    /// - Properly stopping the AVAudioRecorder
    /// - Verifying the recording was saved correctly
    /// - Creating a VoiceNote object with metadata
    /// - Cleaning up resources
    /// - Ending background tasks
    ///
    /// - Returns: The recorded voice note if successful, or nil if no recording was active
    /// - Throws: Error if stopping recording fails for any reason
    ///
    /// - Note: This method updates `isRecording` and stops updating `recordingDuration`
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let voiceNote = try await recordingManager.stopRecordingAsync()
    ///     if let voiceNote = voiceNote {
    ///         // Use the recorded voice note
    ///     }
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
    func stopRecordingAsync() async throws -> VoiceNote? {
        logger.info("Stopping recording with async/await...")
        
        // Begin background task to ensure we have time to complete stopping the recording
        beginBackgroundTask()
        
        guard let recorder = audioRecorder,
              let recordingURL = currentRecordingURL,
              let startTime = recordingStartTime else {
            endBackgroundTaskIfNeeded()
            throw NSError(domain: "RecordingManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No active recording to stop"])
        }
        
        // Ensure we've been recording for at least 1 second to capture audio
        let currentDuration = recorder.currentTime
        if currentDuration < 0.5 {
            logger.warning("Recording duration too short (\(currentDuration)s), waiting to ensure audio is captured...")
            // Wait a bit to ensure we capture some audio
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        // Verify the recording URL exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: recordingURL.path) {
            logger.warning("Recording file does not exist before stopping: \(recordingURL.path)")
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
            logger.error("Recording file was not created after stopping: \(recordingURL.path)")
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
                    logger.error("Recording file is empty")
                    throw NSError(domain: "RecordingManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Recording file is empty"])
                }
            }
        } catch {
            logger.error("Error checking recording file: \(error.localizedDescription)")
        }
        
        // Duration was already captured before stopping the recorder
        logger.debug("Using previously captured recording duration: \(duration) seconds")
        
        // Clean up resources
        audioRecorder = nil
        
        // Stop the duration timer properly
        if let timer = durationTimer {
            timer.invalidate()
            durationTimer = nil
        }
        
        // End background task since recording is stopped
        endBackgroundTaskIfNeeded()
        
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
        
        logger.info("Successfully created voice note")
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
    
    /// Sets up the recording session with async/await pattern.
    ///
    /// This internal method configures the audio session for recording by:
    /// - Setting the audio session category and mode
    /// - Activating the audio session
    /// - Creating a unique file URL for the recording
    /// - Configuring recording settings (format, quality, etc.)
    /// - Initializing the audio recorder
    /// - Starting the recording
    /// - Setting up the duration timer
    ///
    /// - Parameter session: The AVAudioSession to set up
    /// - Returns: Boolean indicating success
    /// - Throws: Error if any part of the setup process fails
    ///
    /// - Important: This method should only be called from `startRecordingAsync()`
    private func setupRecordingSessionAsync(session: AVAudioSession) async throws -> Bool {
        do {
            // Configure the audio session for recording with background support
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            
            // Set the preferred sample rate and I/O buffer duration
            try session.setPreferredSampleRate(44100.0)
            try session.setPreferredIOBufferDuration(0.005)
            
            // Activate the session with options
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            logger.info("Audio session successfully configured with sample rate: \(session.sampleRate)")
            
            // Removed intentional delay to reduce latency
            
            return try await startRecordingAudioAsync()
        } catch {
            logger.error("Failed to set up recording session: \(error.localizedDescription)")
            endBackgroundTaskIfNeeded()
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
                logger.info("Removed existing file at recording URL")
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
            
            logger.info("Recording started successfully")
            return true
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            endBackgroundTaskIfNeeded()
            throw error
        }
    }
    
    // MARK: - Background Task Management
    
    /// Begins a background task to allow audio processing to continue when app is in background.
    ///
    /// This method registers a background task with iOS to request additional execution time
    /// when the app is in the background. This is essential for continuing recording when the
    /// app is minimized or the device is locked.
    ///
    /// The method includes an expiration handler that safely ends recording if the system
    /// needs to terminate the background task.
    private func beginBackgroundTask() {
        // End any existing background task first
        endBackgroundTaskIfNeeded()
        
        // Start a new background task
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // This is the expiration handler - clean up if we're about to be terminated
            self?.endBackgroundTaskIfNeeded()
        }
        
        logger.info("Background task started with identifier: \(self.backgroundTask.rawValue)")
    }
    
    /// End the current background task if one exists
    private func endBackgroundTaskIfNeeded() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            logger.info("Background task ended")
        }
    }
    
    // MARK: - Notification Handlers
    
    /// Handle audio session interruptions (e.g., phone calls)
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began - audio session is deactivated
            logger.info("Audio session interrupted")
            
            // If we're recording, we'll need to handle this interruption
            if isRecording {
                // We'll let the system pause our session, but we'll keep our state as recording
                // so we can resume when the interruption ends
                logger.info("Recording was active during interruption")
            }
            
        case .ended:
            // Interruption ended - check if we should resume
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                logger.info("Audio interruption ended - resuming session")
                
                // Try to reactivate the session
                do {
                    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                    
                    // If we were recording before the interruption, the recorder might have stopped
                    // We could potentially restart it here, but that's complex and might not be desired
                    // Instead, we'll log that the session is back but recording may need to be manually restarted
                    if isRecording && audioRecorder?.isRecording == false {
                        logger.warning("Recording was interrupted and needs to be manually restarted")
                        // Update UI state to reflect that recording stopped
                        Task { @MainActor in
                            self.isRecording = false
                        }
                    }
                } catch {
                    logger.error("Failed to reactivate audio session: \(error.localizedDescription)")
                }
            }
            
        @unknown default:
            logger.warning("Unknown audio session interruption type")
        }
    }
    
    /// Handle app entering background
    @objc private func handleAppDidEnterBackground(notification: Notification) {
        logger.info("App entered background")
        
        // If we're recording, make sure we have a background task
        if isRecording {
            beginBackgroundTask()
            logger.info("Continuing recording in background")
        }
    }
    
    /// Handle app returning to foreground
    @objc private func handleAppWillEnterForeground(notification: Notification) {
        logger.info("App will enter foreground")
        
        // If we're not recording, we can end the background task
        if !isRecording {
            endBackgroundTaskIfNeeded()
        }
    }
    
    /// Handle audio route changes (e.g., headphones connected/disconnected)
    /// Handles audio route changes such as headphones being connected or disconnected.
    ///
    /// This method responds to system notifications about audio route changes and takes
    /// appropriate action based on the type of change. For example, if headphones are
    /// disconnected during recording, it might pause or continue recording through the device speaker.
    ///
    /// - Parameter notification: The notification containing information about the route change
    @objc private func handleAudioRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Log the route change
        logger.info("Audio route changed: \(reason.rawValue)")
        
        // Handle old and new routes if needed
        if let routeDescription = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
            for output in routeDescription.outputs {
                logger.info("Previous output: \(output.portName)")
            }
        }
        
        // Get current route
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        for output in currentRoute.outputs {
            logger.info("Current output: \(output.portName)")
        }
        
        // Handle specific reasons if needed
        switch reason {
        case .oldDeviceUnavailable:
            // This happens when headphones are unplugged
            if isRecording {
                logger.info("Audio device became unavailable while recording")
                // We'll let the system handle the route change
                // The recording should continue with the new audio route
            }
        default:
            break
        }
    }
}
