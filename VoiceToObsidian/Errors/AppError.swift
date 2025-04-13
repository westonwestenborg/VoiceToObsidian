import Foundation
import OSLog

/// Centralized error type for the Voice to Obsidian application
enum AppError: Error {
    case recording(RecordingError)
    case transcription(TranscriptionError)
    case anthropic(AnthropicError)
    case obsidian(ObsidianError)
    case securityScoped(SecurityScopedError)
    case keychain(KeychainManager.KeychainError)
    case general(String)
    
    // MARK: - Nested Error Types
    
    /// Errors related to audio recording functionality
    enum RecordingError: Error { 
        case permissionDenied
        case recordingFailed(String)
        case audioSessionSetupFailed(String)
        case audioFileCreationFailed
    }
    
    /// Errors related to speech transcription
    enum TranscriptionError: Error {
        case speechRecognizerUnavailable
        case recognitionFailed(String)
        case fileTranscriptionFailed(String)
        case recognitionRequestCreationFailed
    }
    
    /// Errors related to Anthropic API interactions
    enum AnthropicError: Error {
        case apiKeyMissing
        case requestCreationFailed
        case networkError(String)
        case responseParsingFailed(String)
        case invalidResponse
    }
    
    /// Errors related to Obsidian vault interactions
    enum ObsidianError: Error {
        case vaultAccessFailed
        case vaultPathMissing
        case bookmarkResolutionFailed(String)
        case fileCreationFailed(String)
        case directoryCreationFailed(String)
        case fileNotFound(String)
    }
    
    /// Errors related to security-scoped bookmarks
    enum SecurityScopedError: Error {
        case bookmarkCreationFailed
        case bookmarkDataStale
        case accessDenied
        case bookmarkDataMissing
    }
}

// MARK: - LocalizedError Conformance
extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .recording(let err): return handleRecordingError(err)
        case .transcription(let err): return handleTranscriptionError(err)
        case .anthropic(let err): return handleAnthropicError(err)
        case .obsidian(let err): return handleObsidianError(err)
        case .securityScoped(let err): return handleSecurityScopedError(err)
        case .keychain(let err): return handleKeychainError(err)
        case .general(let message): return message
        }
    }
    
    var failureReason: String? {
        switch self {
        case .recording: return "Audio recording issue"
        case .transcription: return "Speech transcription issue"
        case .anthropic: return "Anthropic API issue"
        case .obsidian: return "Obsidian vault access issue"
        case .securityScoped: return "Security permission issue"
        case .keychain: return "Secure storage issue"
        case .general: return "Application error"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .recording(.permissionDenied):
            return "Please grant microphone permission in Settings."
        case .anthropic(.apiKeyMissing):
            return "Please add your Anthropic API key in Settings."
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
extension AppError {
    /// Log the error with appropriate level
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
