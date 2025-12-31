import Foundation
import Speech
import AVFoundation
import OSLog

/// Transcription manager using iOS 26 SpeechAnalyzer for unlimited duration transcription.
///
/// `TranscriptionManager` provides file-based transcription using Apple's new SpeechAnalyzer API,
/// which has no duration limits and processes audio fully on-device. This replaces the older
/// `SFSpeechRecognizer` approach that had ~60s server limits.
///
/// ## Example Usage
/// ```swift
/// let transcriptionManager = TranscriptionManager()
///
/// do {
///     let transcript = try await transcriptionManager.transcribeAudioFileAsync(at: audioFileURL)
///     print("Transcription: \(transcript)")
/// } catch {
///     print("Transcription failed: \(error)")
/// }
/// ```
@MainActor
class TranscriptionManager: ObservableObject {
    /// Indicates whether transcription is currently in progress.
    @Published var isTranscribing = false

    /// The progress of the current transcription operation, ranging from 0.0 to 1.0.
    @Published var transcriptionProgress: Float = 0

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "TranscriptionManager")
    private var currentAnalyzer: SpeechAnalyzer?

    /// Actor to ensure transcriptions are processed one at a time.
    /// The Speech framework's SpeechAnalyzer may not handle concurrent instances well.
    private actor TranscriptionQueue {
        private var isProcessing = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func acquireLock() async {
            if isProcessing {
                await withCheckedContinuation { continuation in
                    waiters.append(continuation)
                }
            }
            isProcessing = true
        }

        func releaseLock() {
            isProcessing = false
            if !waiters.isEmpty {
                let next = waiters.removeFirst()
                next.resume()
            }
        }
    }

    private let transcriptionQueue = TranscriptionQueue()

    /// Contextual strings to improve recognition accuracy.
    /// Note: DictationTranscriber doesn't have a direct contextualStrings API.
    /// Custom words are passed to the LLM service for post-processing cleanup.
    private var contextualStrings: [String] = ["Obsidian", "voice memo", "note"]

    init() {
        logger.debug("TranscriptionManager initialized with SpeechAnalyzer")
    }

    /// Sets custom words to improve recognition accuracy.
    /// These are combined with user's custom words from CustomWordsManager during processing.
    func setContextualStrings(_ strings: [String]) {
        contextualStrings = strings
        logger.debug("Set \(strings.count) contextual strings")
    }

    /// Transcribes an audio file using SpeechAnalyzer (no duration limits).
    ///
    /// Multiple concurrent calls are serialized to prevent race conditions with the
    /// Speech framework's SpeechAnalyzer. If another transcription is in progress,
    /// this call will wait in a FIFO queue.
    ///
    /// - Parameter audioURL: The URL of the audio file to transcribe
    /// - Returns: The complete transcript text
    /// - Throws: `TranscriptionError` if transcription fails
    func transcribeAudioFileAsync(at audioURL: URL) async throws -> String {
        // Acquire lock - waits if another transcription is in progress
        await transcriptionQueue.acquireLock()
        logger.info("Acquired transcription lock for: \(audioURL.lastPathComponent)")

        defer {
            Task { await transcriptionQueue.releaseLock() }
        }

        logger.info("Starting SpeechAnalyzer transcription of: \(audioURL.path)")

        isTranscribing = true
        transcriptionProgress = 0

        defer {
            isTranscribing = false
            transcriptionProgress = 1.0
        }

        // Check authorization
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard authStatus == .authorized else {
            logger.error("Speech recognition not authorized")
            throw TranscriptionError.notAuthorized
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            logger.error("Audio file does not exist: \(audioURL.path)")
            throw TranscriptionError.fileNotFound
        }

        // Open audio file
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: audioURL)
        } catch {
            logger.error("Failed to open audio file: \(error.localizedDescription)")
            throw TranscriptionError.fileNotFound
        }

        // Get audio duration for progress estimation
        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        logger.info("Audio duration: \(durationSeconds) seconds")

        // Create DictationTranscriber for long-form dictation with punctuation
        let transcriber = DictationTranscriber(
            locale: Locale(identifier: "en-US"),
            preset: .longDictation
        )

        // Ensure the speech model is available (download if needed)
        try await ensureModelAvailable(for: transcriber)

        // Load custom words (for logging/future use - actual integration is via LLM post-processing)
        let customWords = await CustomWordsManager.shared.customWords
        let allContextualStrings = contextualStrings + customWords
        logger.debug("Contextual strings available: \(allContextualStrings.count) words")

        // Track start time for progress estimation
        let startTime = Date()

        // Collect results as they stream in
        let transcriptTask = Task {
            var fullText = ""
            for try await result in transcriber.results {
                let segment = String(result.text.characters)
                fullText += segment

                // Update progress based on elapsed time vs expected duration
                // SpeechAnalyzer typically processes faster than real-time (55% faster per Apple)
                let elapsed = Date().timeIntervalSince(startTime)
                let estimatedTotalTime = durationSeconds / 1.55  // ~55% faster than real-time
                let progress = min(0.95, Float(elapsed / estimatedTotalTime))

                await MainActor.run {
                    self.transcriptionProgress = progress
                }

                logger.debug("Received segment: \(segment)")
            }
            return fullText
        }

        // Create analyzer and process the file
        let analyzer = try await SpeechAnalyzer(
            inputAudioFile: audioFile,
            modules: [transcriber],
            finishAfterFile: true
        )
        currentAnalyzer = analyzer

        do {
            let transcript = try await transcriptTask.value
            logger.info("Transcription completed: \(transcript.count) characters")
            return transcript

        } catch {
            transcriptTask.cancel()
            logger.error("SpeechAnalyzer error: \(error.localizedDescription)")
            throw TranscriptionError.analysisFailed(error.localizedDescription)
        }
    }

    /// Cancels any ongoing transcription.
    func cancelTranscription() {
        currentAnalyzer = nil
        isTranscribing = false
        logger.info("Transcription cancelled")
    }

    // MARK: - Private Methods

    /// Ensures the speech model is available, downloading if necessary.
    private func ensureModelAvailable(for transcriber: DictationTranscriber) async throws {
        let status = await AssetInventory.status(forModules: [transcriber])

        switch status {
        case .installed:
            logger.debug("Speech model already installed")
            return

        case .supported, .downloading:
            logger.info("Speech model needs download, requesting installation...")
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
                logger.info("Speech model downloaded successfully")
            }

        case .unsupported:
            logger.error("Speech model not supported on this device")
            throw TranscriptionError.modelNotSupported
        }
    }
}

// MARK: - Error Types

enum TranscriptionError: LocalizedError {
    case notAuthorized
    case fileNotFound
    case modelNotSupported
    case analysisFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .fileNotFound:
            return "Audio file not found"
        case .modelNotSupported:
            return "Speech model not supported on this device"
        case .analysisFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}
