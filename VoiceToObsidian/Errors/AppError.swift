import Foundation
import OSLog

/// Centralized error type for the Voice to Obsidian application.
///
/// `AppError` provides a comprehensive error handling system for the entire application,
/// organizing errors into specific domains through nested error types. This approach enables:
/// - Consistent error handling throughout the app
/// - Domain-specific error information
/// - Localized error messages with recovery suggestions
/// - Structured error logging
///
/// The enum uses associated values to wrap domain-specific error types, allowing for
/// detailed error information while maintaining a unified error handling approach.
///
/// ## Example Usage
/// ```swift
/// // Creating and throwing an error
/// throw AppError.recording(.permissionDenied)
///
/// // Handling errors
/// do {
///     try recordingManager.startRecordingAsync()
/// } catch let error as AppError {
///     // Access localized error information
///     print(error.errorDescription ?? "Unknown error")
///     print(error.recoverySuggestion ?? "No recovery suggestion available")
///     
///     // Log the error
///     error.log()
/// }
/// ```
enum AppError: Error {
    /// An error related to audio recording functionality.
    /// - Parameter RecordingError: The specific recording error that occurred
    case recording(RecordingError)
    
    /// An error related to speech transcription.
    /// - Parameter TranscriptionError: The specific transcription error that occurred
    case transcription(TranscriptionError)
    
    /// An error related to Anthropic API interactions.
    /// - Parameter AnthropicError: The specific Anthropic API error that occurred
    case anthropic(AnthropicError)

    /// An error related to LLM provider interactions.
    /// - Parameter LLMError: The specific LLM error that occurred
    case llm(LLMError)

    /// An error related to Obsidian vault interactions.
    /// - Parameter ObsidianError: The specific Obsidian error that occurred
    case obsidian(ObsidianError)
    
    /// An error related to security-scoped bookmarks.
    /// - Parameter SecurityScopedError: The specific security-scoped bookmark error that occurred
    case securityScoped(SecurityScopedError)
    
    /// An error related to Keychain operations.
    /// - Parameter KeychainError: The specific Keychain error that occurred
    case keychain(KeychainManager.KeychainError)
    
    /// A general error with a custom message.
    /// - Parameter String: A description of the error
    case general(String)
    
    // MARK: - Nested Error Types
    
    /// Errors related to audio recording functionality.
    ///
    /// This enum encapsulates all errors that can occur during the audio recording process,
    /// from permission issues to technical failures.
    enum RecordingError: Error { 
        /// The user denied microphone permission or it hasn't been granted.
        case permissionDenied
        
        /// The recording process failed with a specific reason.
        /// - Parameter String: A description of why recording failed
        case recordingFailed(String)
        
        /// Setting up the audio session failed.
        /// - Parameter String: A description of why the audio session setup failed
        case audioSessionSetupFailed(String)
        
        /// Creating the audio file for recording failed.
        case audioFileCreationFailed
    }
    
    /// Errors related to speech transcription.
    ///
    /// This enum encapsulates all errors that can occur during the speech recognition
    /// and transcription process.
    enum TranscriptionError: Error {
        /// The speech recognizer is not available on this device.
        case speechRecognizerUnavailable
        
        /// The speech recognition process failed.
        /// - Parameter String: A description of why recognition failed
        case recognitionFailed(String)
        
        /// Transcribing an audio file failed.
        /// - Parameter String: A description of why file transcription failed
        case fileTranscriptionFailed(String)
        
        /// Creating the speech recognition request failed.
        case recognitionRequestCreationFailed
    }
    
    /// Errors related to Anthropic API interactions.
    ///
    /// This enum encapsulates all errors that can occur when communicating with
    /// the Anthropic Claude API for transcript processing.
    enum AnthropicError: Error {
        /// The Anthropic API key is missing or not configured.
        case apiKeyMissing

        /// Creating the API request failed.
        case requestCreationFailed

        /// A network error occurred during the API call.
        /// - Parameter String: A description of the network error
        case networkError(String)

        /// Parsing the API response failed.
        /// - Parameter String: A description of why parsing failed
        case responseParsingFailed(String)

        /// The API response was invalid or unexpected.
        case invalidResponse
    }

    /// Errors related to LLM (Language Model) provider interactions.
    ///
    /// This enum encapsulates all errors that can occur when communicating with
    /// any LLM provider (Foundation Models, Anthropic, OpenAI, Gemini) for transcript processing.
    enum LLMError: Error {
        /// The API key is missing or not configured for the selected provider.
        case apiKeyMissing

        /// The selected LLM provider is unavailable.
        /// - Parameter String: A description of why the provider is unavailable
        case providerUnavailable(String)

        /// The request to the LLM failed.
        /// - Parameter String: A description of why the request failed
        case requestFailed(String)

        /// Parsing the LLM response failed.
        /// - Parameter String: A description of why parsing failed
        case responseParsingFailed(String)

        /// The LLM response was invalid or unexpected.
        case invalidResponse

        /// A network error occurred during the API call.
        /// - Parameter String: A description of the network error
        case networkError(String)
    }
    
    /// Errors related to Obsidian vault interactions.
    ///
    /// This enum encapsulates all errors that can occur when interacting with
    /// the Obsidian vault, including access, file operations, and path issues.
    enum ObsidianError: Error {
        /// Failed to access the Obsidian vault directory.
        case vaultAccessFailed
        
        /// The Obsidian vault path is not set or is invalid.
        case vaultPathMissing
        
        /// Resolving the security-scoped bookmark for the vault failed.
        /// - Parameter String: A description of why bookmark resolution failed
        case bookmarkResolutionFailed(String)
        
        /// Creating a file in the vault failed.
        /// - Parameter String: A description of why file creation failed
        case fileCreationFailed(String)
        
        /// Creating a directory in the vault failed.
        /// - Parameter String: A description of why directory creation failed
        case directoryCreationFailed(String)
        
        /// A file was not found in the vault.
        /// - Parameter String: A description of the file that wasn't found
        case fileNotFound(String)
    }
    
    /// Errors related to security-scoped bookmarks.
    ///
    /// This enum encapsulates all errors that can occur when working with
    /// security-scoped bookmarks for maintaining access to user-selected directories.
    enum SecurityScopedError: Error {
        /// Creating a security-scoped bookmark failed.
        case bookmarkCreationFailed
        
        /// The security-scoped bookmark data is stale and needs to be recreated.
        case bookmarkDataStale
        
        /// Access to the bookmarked resource was denied.
        case accessDenied
        
        /// The security-scoped bookmark data is missing or invalid.
        case bookmarkDataMissing
    }
}

// MARK: - LocalizedError Conformance

/// Extension to make AppError conform to LocalizedError for user-friendly error messages.
extension AppError: LocalizedError {
    /// A localized message describing what error occurred.
    ///
    /// This property provides a user-friendly description of the error that can be
    /// displayed in the UI. It delegates to domain-specific handler methods to generate
    /// appropriate messages based on the specific error type.
    ///
    /// - Returns: A localized error description string
    var errorDescription: String? {
        switch self {
        case .recording(let err): return handleRecordingError(err)
        case .transcription(let err): return handleTranscriptionError(err)
        case .anthropic(let err): return handleAnthropicError(err)
        case .llm(let err): return handleLLMError(err)
        case .obsidian(let err): return handleObsidianError(err)
        case .securityScoped(let err): return handleSecurityScopedError(err)
        case .keychain(let err): return handleKeychainError(err)
        case .general(let message): return message
        }
    }
    
    /// A localized message describing the reason for the failure.
    ///
    /// This property provides a higher-level categorization of the error type,
    /// helping users understand which system or component encountered the error.
    ///
    /// - Returns: A localized string explaining the reason for the error
    var failureReason: String? {
        switch self {
        case .recording: return "Audio recording issue"
        case .transcription: return "Speech transcription issue"
        case .anthropic: return "Anthropic API issue"
        case .llm: return "LLM processing issue"
        case .obsidian: return "Obsidian vault access issue"
        case .securityScoped: return "Security permission issue"
        case .keychain: return "Secure storage issue"
        case .general: return "Application error"
        }
    }
    
    /// A localized message describing how to recover from the error.
    ///
    /// This property provides actionable advice to users about how they might
    /// resolve the error. For example, it might suggest granting permissions,
    /// adding API keys, or reselecting the Obsidian vault.
    ///
    /// - Returns: A localized string with recovery advice, if available
    var recoverySuggestion: String? {
        switch self {
        case .recording(.permissionDenied):
            return "Please grant microphone permission in Settings."
        case .anthropic(.apiKeyMissing):
            return "Please add your Anthropic API key in Settings."
        case .llm(.apiKeyMissing):
            return "Please add an API key for your selected provider in Settings."
        case .llm(.providerUnavailable):
            return "Try selecting a different LLM provider in Settings."
        case .obsidian(.vaultPathMissing):
            return "Please select your Obsidian vault in Settings."
        case .securityScoped(.bookmarkDataStale), .securityScoped(.accessDenied):
            return "Please reselect your Obsidian vault in Settings."
        default:
            return "Please try again or restart the app if the issue persists."
        }
    }
    
    // MARK: - Helper Methods for Error Descriptions
    
    private func handleRecordingError(_ error: RecordingError) -> String {
        switch error {
        case .permissionDenied:
            return "Microphone access is required for recording."
        case .recordingFailed(let message):
            return "Failed to record audio: \(message)"
        case .audioSessionSetupFailed(let message):
            return "Failed to set up audio session: \(message)"
        case .audioFileCreationFailed:
            return "Failed to create audio file."
        }
    }
    
    private func handleTranscriptionError(_ error: TranscriptionError) -> String {
        switch error {
        case .speechRecognizerUnavailable:
            return "Speech recognition is not available on this device."
        case .recognitionFailed(let message):
            return "Failed to recognize speech: \(message)"
        case .fileTranscriptionFailed(let message):
            return "Failed to transcribe audio file: \(message)"
        case .recognitionRequestCreationFailed:
            return "Failed to create speech recognition request."
        }
    }
    
    private func handleAnthropicError(_ error: AnthropicError) -> String {
        switch error {
        case .apiKeyMissing:
            return "Anthropic API key is missing."
        case .requestCreationFailed:
            return "Failed to create API request."
        case .networkError(let message):
            return "Network error: \(message)"
        case .responseParsingFailed(let message):
            return "Failed to parse API response: \(message)"
        case .invalidResponse:
            return "Received invalid response from API."
        }
    }

    private func handleLLMError(_ error: LLMError) -> String {
        switch error {
        case .apiKeyMissing:
            return "API key is missing for the selected provider."
        case .providerUnavailable(let message):
            return "LLM provider unavailable: \(message)"
        case .requestFailed(let message):
            return "Failed to process with LLM: \(message)"
        case .responseParsingFailed(let message):
            return "Failed to parse LLM response: \(message)"
        case .invalidResponse:
            return "Received invalid response from LLM."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }

    private func handleObsidianError(_ error: ObsidianError) -> String {
        switch error {
        case .vaultAccessFailed:
            return "Failed to access Obsidian vault."
        case .vaultPathMissing:
            return "Obsidian vault path is not set."
        case .bookmarkResolutionFailed(let message):
            return "Failed to resolve vault bookmark: \(message)"
        case .fileCreationFailed(let message):
            return "Failed to create file in vault: \(message)"
        case .directoryCreationFailed(let message):
            return "Failed to create directory in vault: \(message)"
        case .fileNotFound(let message):
            return "File not found: \(message)"
        }
    }
    
    private func handleSecurityScopedError(_ error: SecurityScopedError) -> String {
        switch error {
        case .bookmarkCreationFailed:
            return "Failed to create security bookmark."
        case .bookmarkDataStale:
            return "Security bookmark is no longer valid."
        case .accessDenied:
            return "Access to selected folder was denied."
        case .bookmarkDataMissing:
            return "Security bookmark data is missing."
        }
    }
    
    private func handleKeychainError(_ error: KeychainManager.KeychainError) -> String {
        switch error {
        case .itemNotFound:
            return "Item not found in secure storage."
        case .duplicateItem:
            return "Item already exists in secure storage."
        case .unexpectedStatus(let status):
            return "Secure storage error: \(status)"
        case .conversionError:
            return "Failed to convert data for secure storage."
        }
    }
}

// MARK: - Error Logging

/// Extension to add structured logging capabilities to AppError.
extension AppError {
    /// Logs the error with appropriate level using OSLog.
    ///
    /// This method provides consistent, structured logging for all app errors.
    /// It logs the error description, failure reason, and recovery suggestion
    /// with appropriate log levels for easier debugging and troubleshooting.
    ///
    /// ## Example
    /// ```swift
    /// catch let error as AppError {
    ///     error.log()
    ///     // Handle the error...
    /// }
    /// ```
    func log() {
        // Create a logger for error logging
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "AppError")
        
        // Log the error with appropriate level
        logger.error("ERROR: \(errorDescription ?? "Unknown error")")
        logger.error("REASON: \(failureReason ?? "Unknown reason")")
        
        if let suggestion = recoverySuggestion {
            logger.notice("SUGGESTION: \(suggestion)")
        }
        
        // Additional debug info in development builds
        #if DEBUG
        logger.debug("ERROR DETAILS: \(self)")
        #endif
    }
}
