import Foundation
import OSLog

/// Utility functions to bridge between callback-based code and async/await
@available(iOS 13.0, *)
enum AsyncBridge {
    private static let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "AsyncBridge")
    
    /// Converts a callback-based function to an async function
    /// - Parameters:
    ///   - work: The callback-based work to perform
    /// - Returns: The result from the callback
    @available(iOS 13.0, *)
    static func callbackToAsync<T>(work: @escaping (@escaping (Result<T, Error>) -> Void) -> Void) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            work { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Converts an async function to a callback-based function
    /// - Parameters:
    ///   - asyncWork: The async work to perform
    ///   - completion: The completion handler to call with the result
    @available(iOS 15.0, *)
    static func asyncToCallback<T>(
        asyncWork: @escaping () async throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        Task {
            do {
                let result = try await asyncWork()
                completion(.success(result))
            } catch {
                logger.error("Error in async operation: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Executes an async function if available, otherwise falls back to a callback-based function
    /// - Parameters:
    ///   - asyncWork: The async work to perform (iOS 15+)
    ///   - callbackWork: The callback-based work to perform (iOS 14 and below)
    ///   - completion: The completion handler to call with the result
    static func executeWithFallback<T>(
        asyncWork: @escaping () async throws -> T,
        callbackWork: @escaping (@escaping (Result<T, Error>) -> Void) -> Void,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        if #available(iOS 15.0, *) {
            asyncToCallback(asyncWork: asyncWork, completion: completion)
        } else {
            callbackWork(completion)
        }
    }
    
    /// Runs an operation with memory optimization using autorelease pools
    /// - Parameter operation: The operation to run
    /// - Returns: The result of the operation
    @available(iOS 15.0, *)
    static func withOptimizedMemory<T>(operation: @escaping () async throws -> T) async throws -> T {
        return try await autoreleasepool {
            try await operation()
        }
    }
}

// MARK: - VoiceNoteStore Async Bridge Extensions

extension VoiceNoteStore {
    /// Start recording with automatic version selection
    /// - Parameter completion: Completion handler with success status
    func startRecordingWithBridge(completion: @escaping (Bool) -> Void) {
        AsyncBridge.executeWithFallback(
            asyncWork: { 
                if #available(iOS 15.0, *) {
                    // Call the async method directly
                    let success = try await self.startRecording()
                    return success
                } else {
                    // This should never be called on iOS 15+
                    throw AppError.general("Async version not available")
                }
            },
            callbackWork: { callback in
                self.startRecording { success in
                    callback(success ? .success(success) : .failure(AppError.recording(.recordingFailed("Failed to start recording"))))
                }
            },
            completion: { result in
                switch result {
                case .success(let success):
                    completion(success)
                case .failure:
                    completion(false)
                }
            }
        )
    }
    
    /// Stop recording with automatic version selection
    /// - Parameter completion: Completion handler with the voice note
    func stopRecordingWithBridge(completion: @escaping (VoiceNote?) -> Void) {
        AsyncBridge.executeWithFallback(
            asyncWork: { 
                if #available(iOS 15.0, *) {
                    // Call the async method directly
                    let voiceNote = try await self.stopRecording()
                    return voiceNote
                } else {
                    // This should never be called on iOS 15+
                    throw AppError.general("Async version not available")
                }
            },
            callbackWork: { callback in
                self.stopRecording { success, voiceNote in
                    callback(success && voiceNote != nil ? .success(voiceNote) : .failure(AppError.recording(.recordingFailed("Failed to stop recording"))))
                }
            },
            completion: { result in
                switch result {
                case .success(let voiceNote):
                    completion(voiceNote)
                case .failure:
                    completion(nil)
                }
            }
        )
    }
}

// MARK: - AnthropicService Async Bridge Extensions

extension AnthropicService {
    /// Process a transcript with automatic version selection
    /// - Parameters:
    ///   - transcript: The transcript to process
    ///   - completion: Completion handler with success status and cleaned transcript
    func processTranscriptWithBridge(
        _ transcript: String,
        completion: @escaping (Bool, String?, String?) -> Void
    ) {
        AsyncBridge.executeWithFallback(
            asyncWork: { 
                if #available(iOS 15.0, *) {
                    // Call the async method directly
                    let result = try await self.processTranscript(transcript: transcript)
                    return (true, result.transcript, result.title)
                } else {
                    // This should never be called on iOS 15+
                    throw AppError.general("Async version not available")
                }
            },
            callbackWork: { callback in
                self.processTranscript(transcript) { success, cleanedTranscript, title in
                    callback(success ? .success((success, cleanedTranscript, title)) : .failure(AppError.anthropic(.responseParsingFailed("Failed to process transcript"))))
                }
            },
            completion: { result in
                switch result {
                case .success(let tuple):
                    completion(tuple.0, tuple.1, tuple.2)
                case .failure:
                    completion(false, nil, nil)
                }
            }
        )
    }
}

// MARK: - ObsidianService Async Bridge Extensions

extension ObsidianService {
    /// Create a voice note file with automatic version selection
    /// - Parameters:
    ///   - voiceNote: The voice note to create a file for
    ///   - completion: Completion handler with success status
    func createVoiceNoteFileWithBridge(
        for voiceNote: VoiceNote,
        completion: @escaping (Bool) -> Void
    ) {
        AsyncBridge.executeWithFallback(
            asyncWork: { 
                if #available(iOS 15.0, *) {
                    let result = try await self.createVoiceNoteFile(for: voiceNote)
                    return result.success
                } else {
                    // This should never be called on iOS 15+
                    throw AppError.general("Async version not available")
                }
            },
            callbackWork: { callback in
                self.createVoiceNoteFile(for: voiceNote) { success in
                    callback(success ? .success(success) : .failure(AppError.obsidian(.fileCreationFailed("Failed to create voice note file"))))
                }
            },
            completion: { result in
                switch result {
                case .success(let success):
                    completion(success)
                case .failure:
                    completion(false)
                }
            }
        )
    }
    
    /// Copy an audio file to the vault with automatic version selection
    /// - Parameters:
    ///   - url: The URL of the audio file to copy
    ///   - completion: Completion handler with success status
    func copyAudioFileToVaultWithBridge(
        from url: URL,
        completion: @escaping (Bool) -> Void
    ) {
        AsyncBridge.executeWithFallback(
            asyncWork: { 
                if #available(iOS 15.0, *) {
                    return try await self.copyAudioFileToVault(from: url)
                } else {
                    // This should never be called on iOS 15+
                    throw AppError.general("Async version not available")
                }
            },
            callbackWork: { callback in
                self.copyAudioFileToVault(from: url) { success in
                    callback(success ? .success(success) : .failure(AppError.obsidian(.fileCreationFailed("Failed to copy audio file"))))
                }
            },
            completion: { result in
                switch result {
                case .success(let success):
                    completion(success)
                case .failure:
                    completion(false)
                }
            }
        )
    }
}
