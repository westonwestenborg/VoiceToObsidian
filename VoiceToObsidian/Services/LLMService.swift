import Foundation
import OSLog
import AnyLanguageModel

#if canImport(FoundationModels)
import FoundationModels
#endif

/// System instructions for transcript cleanup.
///
/// These instructions are passed to `LanguageModelSession(instructions:)` separately
/// from the user prompt, following Apple's best practices for Foundation Models.
private let transcriptCleanupInstructions = """
You are a transcript editor. Your task is to clean voice transcripts by:
- Removing filler words (um, uh, like, you know, so, basically)
- Fixing grammar and punctuation errors
- Improving readability while preserving the original meaning
- NOT adding content that wasn't in the original

Generate a concise title (5-7 words) that captures the main topic.
Do NOT use special characters in titles: : / \\ ? * " < > | [ ] # ^
"""

/// Result from LLM processing containing the cleaned transcript and suggested title.
struct LLMProcessingResult {
    /// The cleaned and formatted transcript.
    let transcript: String
    /// The suggested title for the voice note.
    let title: String
}

/// Codable struct for parsing cloud provider JSON responses.
private struct CloudProviderResponse: Codable {
    let title: String
    let cleanedTranscript: String
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

    /// Returns the current provider identifier for tracking purposes.
    var currentProviderIdentifier: String {
        currentProvider.rawValue
    }

    /// Returns the current model identifier for tracking purposes.
    var currentModelIdentifier: String {
        currentModel
    }

    // MARK: - Token Estimation

    /// Estimates the token count for a given text.
    ///
    /// Uses a rough estimate of ~4 characters per token for English text.
    /// This is conservative to avoid context window overflow.
    ///
    /// - Parameter text: The text to estimate tokens for.
    /// - Returns: Estimated token count.
    private func estimateTokenCount(_ text: String) -> Int {
        // Rough estimate: ~4 characters per token for English
        return text.count / 4
    }

    /// The maximum token budget for Apple Intelligence context window.
    ///
    /// Apple Intelligence has a 4,096 token limit shared between input and output.
    /// We reserve tokens for system instructions and output.
    private let maxContextTokens = 4096
    private let systemInstructionTokens = 200
    private let outputReserveTokens = 800

    /// The maximum input tokens available for transcript content.
    var maxTranscriptTokens: Int {
        maxContextTokens - systemInstructionTokens - outputReserveTokens
    }

    /// Determines if a transcript exceeds the safe processing length for the current provider.
    ///
    /// - Parameter transcript: The transcript to check.
    /// - Returns: True if the transcript should be chunked or truncated.
    func isTranscriptTooLong(_ transcript: String) -> Bool {
        let limit = currentProvider == .foundationModels ? maxTranscriptTokens : maxCloudTranscriptTokens
        return estimateTokenCount(transcript) > limit
    }

    /// The maximum input tokens available for cloud providers (much larger context windows).
    private let maxCloudTranscriptTokens = 30000  // ~120k chars, safe for Claude/GPT-4

    /// Validates if a transcript has enough content to process meaningfully.
    ///
    /// - Parameter transcript: The transcript to validate.
    /// - Returns: True if the transcript has sufficient content for LLM processing.
    func isTranscriptProcessable(_ transcript: String) -> Bool {
        let wordCount = transcript.split(separator: " ").count
        return wordCount >= 3
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

        // Use native FoundationModels API for Apple Intelligence
        if currentProvider == .foundationModels {
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                return try await processWithNativeFoundationModels(
                    transcript: transcript,
                    customWords: customWords
                )
            }
            #endif
            // Fallback if FoundationModels not available
            throw AppError.llm(.providerUnavailable("Apple Intelligence requires iOS 26.0 or later"))
        }

        // For cloud providers, use AnyLanguageModel with Guided Generation
        return try await processWithCloudProvider(
            transcript: transcript,
            customWords: customWords
        )
    }

    /// Processes a transcript using cloud providers via AnyLanguageModel.
    ///
    /// Cloud providers (Claude, OpenAI, Gemini) don't support structured Guided Generation
    /// in AnyLanguageModel, so we use plain text generation with JSON parsing.
    ///
    /// - Parameters:
    ///   - transcript: The original voice transcript to process.
    ///   - customWords: Custom words to preserve in the transcript.
    /// - Returns: An `LLMProcessingResult` with title and cleaned transcript.
    /// - Throws: `AppError.llm` with details about what went wrong.
    private func processWithCloudProvider(
        transcript: String,
        customWords: [String]
    ) async throws -> LLMProcessingResult {
        logger.debug("Processing transcript with cloud provider: \(self.currentProvider.displayName)")

        // Validate transcript - if too short, throw error so caller can handle gracefully
        guard isTranscriptProcessable(transcript) else {
            logger.warning("Transcript too short to process: \(transcript.split(separator: " ").count) words")
            throw AppError.llm(.transcriptTooShort)
        }

        // Check length - if too long, throw error so caller can handle gracefully
        if isTranscriptTooLong(transcript) {
            let maxChars = maxCloudTranscriptTokens * 4  // Convert tokens back to chars
            logger.warning("Transcript too long (\(transcript.count) chars) for context window (max \(maxChars) chars)")
            throw AppError.llm(.transcriptTooLong(maxCharacters: maxChars))
        }

        // Build the user prompt with optional custom words and JSON output format
        let customWordsSection = !customWords.isEmpty ? """

        Common words the speaker uses (preserve these when appropriate): \(customWords.joined(separator: ", "))
        """ : ""

        let userPrompt = """
        Clean this voice transcript and generate a title.\(customWordsSection)

        TRANSCRIPT:
        \(transcript)

        Respond with ONLY a JSON object in this exact format (no markdown, no explanation):
        {"title": "Your Title Here", "cleanedTranscript": "Your cleaned transcript here"}
        """

        // System instructions for cloud providers
        let cloudInstructions = """
        You are a transcript editor. Your task is to clean voice transcripts by:
        - Removing filler words (um, uh, like, you know, so, basically)
        - Fixing grammar and punctuation errors
        - Improving readability while preserving the original meaning
        - NOT adding content that wasn't in the original

        Generate a concise title (5-7 words) that captures the main topic.
        Do NOT use special characters in titles: : / \\ ? * " < > | [ ] # ^

        IMPORTANT: Respond with ONLY valid JSON. No markdown code blocks, no explanation.
        """

        // Create model and session with instructions
        let model = try createLanguageModel()
        let session = LanguageModelSession(
            model: model,
            instructions: cloudInstructions
        )

        // Set generation options with higher token limit for long transcripts
        // The output will be roughly the same size as the input plus overhead for JSON
        let estimatedOutputTokens = estimateTokenCount(transcript) + 500  // transcript + JSON overhead
        let options = AnyLanguageModel.GenerationOptions(
            maximumResponseTokens: max(4096, estimatedOutputTokens)  // At least 4096, or more if needed
        )
        logger.debug("Using maximumResponseTokens: \(max(4096, estimatedOutputTokens))")

        do {
            // Use plain text generation since cloud providers don't support structured output
            let response = try await session.respond(to: userPrompt, options: options)
            let responseText = response.content
            logger.debug("Cloud provider response received, parsing JSON")

            // Parse the JSON response
            return try parseCloudProviderResponse(responseText)
        } catch let error as AppError {
            throw error
        } catch {
            logger.error("Cloud provider request failed: \(error.localizedDescription)")
            throw AppError.llm(.requestFailed(error.localizedDescription))
        }
    }

    /// Parses the JSON response from cloud providers.
    ///
    /// - Parameter response: The raw response text from the cloud provider.
    /// - Returns: An `LLMProcessingResult` with extracted title and transcript.
    /// - Throws: `AppError.llm(.responseParsingFailed)` if parsing fails.
    private func parseCloudProviderResponse(_ response: String) throws -> LLMProcessingResult {
        // Log the first 200 chars for debugging
        let preview = String(response.prefix(200))
        logger.debug("Parsing response (first 200 chars): \(preview)")
        logger.debug("Full response length: \(response.count) characters")

        // Try to extract JSON from the response - it might be wrapped in markdown or have extra text
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown JSON code blocks if present
        if let codeBlockStart = jsonString.range(of: "```json") {
            jsonString = String(jsonString[codeBlockStart.upperBound...])
            if let codeBlockEnd = jsonString.range(of: "```") {
                jsonString = String(jsonString[..<codeBlockEnd.lowerBound])
            }
        } else if let codeBlockStart = jsonString.range(of: "```") {
            jsonString = String(jsonString[codeBlockStart.upperBound...])
            if let codeBlockEnd = jsonString.range(of: "```") {
                jsonString = String(jsonString[..<codeBlockEnd.lowerBound])
            }
        }

        // Try to find JSON object in the response (look for { ... })
        if let jsonStart = jsonString.firstIndex(of: "{"),
           let jsonEnd = jsonString.lastIndex(of: "}") {
            jsonString = String(jsonString[jsonStart...jsonEnd])
        }

        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.debug("Extracted JSON length: \(jsonString.count) characters")

        // Check if JSON appears truncated (doesn't end with })
        if !jsonString.hasSuffix("}") {
            logger.error("JSON appears truncated - doesn't end with }")
            logger.error("Last 100 chars: \(String(jsonString.suffix(100)))")
            throw AppError.llm(.responseParsingFailed("Response was truncated"))
        }

        // Parse JSON using Codable for better error messages
        guard let jsonData = jsonString.data(using: .utf8) else {
            logger.error("Failed to convert response to data")
            throw AppError.llm(.responseParsingFailed("Invalid response encoding"))
        }

        do {
            let decoder = JSONDecoder()
            let parsed = try decoder.decode(CloudProviderResponse.self, from: jsonData)

            logger.debug("Cloud provider JSON parsed successfully with title: \(parsed.title)")
            return LLMProcessingResult(
                transcript: parsed.cleanedTranscript,
                title: parsed.title
            )
        } catch let decodingError as DecodingError {
            // Provide detailed error info for debugging
            switch decodingError {
            case .dataCorrupted(let context):
                logger.error("JSON data corrupted: \(context.debugDescription)")
                if let underlying = context.underlyingError as NSError? {
                    logger.error("Underlying error: \(underlying.localizedDescription)")
                    // Log position info if available
                    if let errorIndex = underlying.userInfo["NSJSONSerializationErrorIndex"] as? Int {
                        let start = max(0, errorIndex - 50)
                        let end = min(jsonString.count, errorIndex + 50)
                        let startIdx = jsonString.index(jsonString.startIndex, offsetBy: start)
                        let endIdx = jsonString.index(jsonString.startIndex, offsetBy: end)
                        logger.error("Error near position \(errorIndex): ...\(jsonString[startIdx..<endIdx])...")
                    }
                }
            case .keyNotFound(let key, let context):
                logger.error("Missing key '\(key.stringValue)': \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                logger.error("Type mismatch for \(type): \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                logger.error("Value not found for \(type): \(context.debugDescription)")
            @unknown default:
                logger.error("Unknown decoding error: \(decodingError.localizedDescription)")
            }
            logger.error("Attempted to parse (first 500 chars): \(String(jsonString.prefix(500)))")
            logger.error("Attempted to parse (last 200 chars): \(String(jsonString.suffix(200)))")
            throw AppError.llm(.responseParsingFailed("Invalid JSON: \(decodingError.localizedDescription)"))
        } catch {
            logger.error("JSON parsing failed: \(error.localizedDescription)")
            logger.error("Attempted to parse (first 500 chars): \(String(jsonString.prefix(500)))")
            throw AppError.llm(.responseParsingFailed("Invalid JSON: \(error.localizedDescription)"))
        }
    }

    #if canImport(FoundationModels)
    /// Processes a transcript using Apple's native FoundationModels Guided Generation.
    ///
    /// This method uses Apple's native `@Generable` structs directly, bypassing
    /// AnyLanguageModel for true structured output with Apple Intelligence.
    ///
    /// - Parameters:
    ///   - transcript: The original voice transcript to process.
    ///   - customWords: Custom words to preserve in the transcript.
    /// - Returns: An `LLMProcessingResult` with title and cleaned transcript.
    /// - Throws: `AppError.llm` with details about what went wrong.
    @available(iOS 26.0, *)
    private func processWithNativeFoundationModels(
        transcript: String,
        customWords: [String]
    ) async throws -> LLMProcessingResult {
        logger.debug("Processing transcript with native FoundationModels API")

        // Validate transcript
        guard isTranscriptProcessable(transcript) else {
            logger.warning("Transcript too short to process: \(transcript.split(separator: " ").count) words")
            throw AppError.llm(.transcriptTooShort)
        }

        // Check length - if too long, throw error so caller can handle gracefully
        if isTranscriptTooLong(transcript) {
            let maxChars = maxTranscriptTokens * 4
            logger.warning("Transcript too long (\(transcript.count) chars) for context window (max \(maxChars) chars)")
            throw AppError.llm(.transcriptTooLong(maxCharacters: maxChars))
        }

        // Build the user prompt with optional custom words
        let customWordsSection = !customWords.isEmpty ? """

        Common words the speaker uses (preserve these when appropriate): \(customWords.joined(separator: ", "))
        """ : ""

        let userPrompt = """
        Clean this voice transcript:\(customWordsSection)

        \(transcript)
        """

        // Create native FoundationModels session with instructions
        let systemModel = FoundationModels.SystemLanguageModel.default
        let session = FoundationModels.LanguageModelSession(
            model: systemModel,
            instructions: transcriptCleanupInstructions
        )

        do {
            // Use native Guided Generation - this returns structured output!
            let response = try await session.respond(
                to: userPrompt,
                generating: NativeTranscriptCleanupResult.self
            )
            let result = response.content
            logger.debug("Native Guided Generation succeeded with title: \(result.title)")

            return LLMProcessingResult(
                transcript: result.cleanedTranscript,
                title: result.title
            )
        } catch {
            logger.error("Native Guided Generation failed: \(error.localizedDescription)")
            throw AppError.llm(.requestFailed(error.localizedDescription))
        }
    }
    #endif

    // MARK: - Private Methods

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
}
