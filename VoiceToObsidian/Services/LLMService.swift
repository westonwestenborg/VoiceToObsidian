import Foundation
import OSLog
import AnyLanguageModel

/// Result from LLM processing containing the cleaned transcript and suggested title.
struct LLMProcessingResult {
    /// The cleaned and formatted transcript.
    let transcript: String
    /// The suggested title for the voice note.
    let title: String
}

/// Service for processing transcripts with multiple LLM providers.
///
/// `LLMService` provides a unified interface for processing voice transcripts using
/// various LLM providers including Apple Foundation Models, Anthropic Claude,
/// OpenAI, and Google Gemini. It handles provider selection, API key management,
/// and request/response processing.
///
/// The service uses the AnyLanguageModel library to provide a consistent API
/// across all providers.
@MainActor
class LLMService {
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "LLMService")

    // MARK: - API Keys for Cloud Providers

    private var anthropicAPIKey: String = ""
    private var openAIAPIKey: String = ""
    private var geminiAPIKey: String = ""

    // MARK: - Current Provider and Model

    private var currentProvider: LLMProvider = .foundationModels
    private var currentModel: String = ""

    // MARK: - Initialization

    init() {
        currentModel = currentProvider.defaultModel
        logger.debug("LLMService initialized with provider: \(self.currentProvider.displayName)")
    }

    // MARK: - Configuration

    /// Updates the current LLM provider.
    ///
    /// - Parameter provider: The new provider to use for LLM requests.
    func updateProvider(_ provider: LLMProvider) {
        currentProvider = provider
        currentModel = provider.defaultModel
        logger.debug("Provider updated to: \(provider.displayName)")
    }

    /// Updates the current model for the selected provider.
    ///
    /// - Parameter model: The model identifier to use.
    func updateModel(_ model: String) {
        currentModel = model
        logger.debug("Model updated to: \(model)")
    }

    /// Updates the Anthropic API key.
    ///
    /// - Parameter key: The Anthropic API key.
    func updateAnthropicAPIKey(_ key: String) {
        anthropicAPIKey = key
        logger.debug("Anthropic API key updated")
    }

    /// Updates the OpenAI API key.
    ///
    /// - Parameter key: The OpenAI API key.
    func updateOpenAIAPIKey(_ key: String) {
        openAIAPIKey = key
        logger.debug("OpenAI API key updated")
    }

    /// Updates the Gemini API key.
    ///
    /// - Parameter key: The Gemini API key.
    func updateGeminiAPIKey(_ key: String) {
        geminiAPIKey = key
        logger.debug("Gemini API key updated")
    }

    // MARK: - Foundation Models Availability

    /// Indicates whether Apple Foundation Models is available on this device.
    ///
    /// Foundation Models requires iOS 26.0 or later and specific hardware support.
    var isFoundationModelsAvailable: Bool {
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        return false
    }

    // MARK: - Processing

    /// Processes a transcript with the current LLM provider and returns both cleaned transcript and title.
    ///
    /// This method sends the transcript to the configured LLM provider for cleanup and
    /// title generation. The LLM will:
    /// - Remove filler words (um, uh, like, etc.)
    /// - Fix grammatical errors and repetitions
    /// - Format the text in a clear, readable way
    /// - Suggest a concise title for the note
    ///
    /// - Parameters:
    ///   - transcript: The original voice transcript to process.
    ///   - customWords: Custom words that the user commonly uses, which helps the LLM
    ///                  recognize and preserve specific terminology.
    /// - Returns: An `LLMProcessingResult` containing the cleaned transcript and suggested title.
    /// - Throws: `AppError.llm` with details about what went wrong.
    func processTranscriptWithTitle(
        transcript: String,
        customWords: [String]
    ) async throws -> LLMProcessingResult {
        logger.debug("Processing transcript with provider: \(self.currentProvider.displayName)")

        let prompt = buildPrompt(transcript: transcript, customWords: customWords)
        let response = try await sendRequest(prompt: prompt)
        return parseResponse(response)
    }

    // MARK: - Private Methods

    /// Builds the prompt for the LLM request.
    private func buildPrompt(transcript: String, customWords: [String]) -> String {
        let customWordsSection = !customWords.isEmpty ? """
        The voice-to-text model we use makes errors. This is a list of common words the speaker uses, please replace them when you are cleaning up the transcript if you think they are a better fit: \(customWords.joined(separator: ", "))

        """ : ""

        return """
        I have a voice memo transcript that needs to be cleaned up. Please:

        1. Remove filler words (um, uh, like, etc.)
        2. Fix any grammatical errors or repetitions
        3. Format the text in a clear, readable way
        4. Suggest a concise title for this note (max 5-7 words)
           - Avoid special characters: : / \\ ? * " < > | [ ] # ^
           - Use hyphens or spaces for separation instead of colons

        \(customWordsSection)Original transcript:
        \(transcript)

        Please respond in the following format:

        TITLE: [Your suggested title]

        CLEANED TRANSCRIPT:
        [The cleaned up transcript]
        """
    }

    /// Sends a request to the current LLM provider.
    private func sendRequest(prompt: String) async throws -> String {
        let model = try createLanguageModel()
        let session = LanguageModelSession(model: model)

        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            logger.error("LLM request failed: \(error.localizedDescription)")
            throw AppError.llm(.requestFailed(error.localizedDescription))
        }
    }

    /// Creates the appropriate language model for the current provider.
    private func createLanguageModel() throws -> any LanguageModel {
        switch currentProvider {
        case .foundationModels:
            guard isFoundationModelsAvailable else {
                throw AppError.llm(.providerUnavailable("Apple Intelligence is not available on this device"))
            }
            if #available(iOS 26.0, *) {
                return SystemLanguageModel.default
            } else {
                throw AppError.llm(.providerUnavailable("Apple Intelligence requires iOS 26.0 or later"))
            }

        case .anthropic:
            let apiKey = anthropicAPIKey
            guard !apiKey.isEmpty else {
                throw AppError.llm(.apiKeyMissing)
            }
            let model = currentModel
            return AnthropicLanguageModel(
                apiKey: apiKey,
                model: model
            )

        case .openai:
            let apiKey = openAIAPIKey
            guard !apiKey.isEmpty else {
                throw AppError.llm(.apiKeyMissing)
            }
            let model = currentModel
            return OpenAILanguageModel(
                apiKey: apiKey,
                model: model
            )

        case .gemini:
            let apiKey = geminiAPIKey
            guard !apiKey.isEmpty else {
                throw AppError.llm(.apiKeyMissing)
            }
            let model = currentModel
            return GeminiLanguageModel(
                apiKey: apiKey,
                model: model
            )
        }
    }

    /// Parses the LLM response to extract the title and cleaned transcript.
    private func parseResponse(_ response: String) -> LLMProcessingResult {
        var title: String? = nil
        var cleanedTranscript: String? = nil

        // Extract title
        if let titleRange = response.range(of: "TITLE: ", options: .caseInsensitive),
           let endOfTitleRange = response.range(of: "\n\n", options: [], range: titleRange.upperBound..<response.endIndex) {
            title = String(response[titleRange.upperBound..<endOfTitleRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract cleaned transcript
        if let transcriptRange = response.range(of: "CLEANED TRANSCRIPT:", options: .caseInsensitive) {
            cleanedTranscript = String(response[transcriptRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let defaultTitle = "Voice Note \(DateFormatUtil.shared.formatTimestamp(date: Date()))"
        return LLMProcessingResult(
            transcript: cleanedTranscript ?? response,
            title: title ?? defaultTitle
        )
    }
}
