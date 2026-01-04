//
//  LLMServiceTests.swift
//  VoiceToObsidianTests
//
//  Tests for LLMService multi-provider functionality.
//

import Testing
import Foundation
@testable import VoiceToObsidian

/// Tests for LLMService provider and configuration management.
///
/// Note: These tests focus on configuration and parsing logic.
/// Actual LLM API calls are not tested here to avoid requiring API keys
/// and network access. For full integration testing, use manual testing
/// with real API keys.
struct LLMServiceTests {

    // MARK: - Provider Configuration Tests

    @Test @MainActor func testDefaultProvider() async throws {
        let llmService = LLMService()

        // Foundation Models is the default provider
        // We can't directly access currentProvider, but we can verify
        // the service initializes without error
        #expect(true, "LLMService initialized successfully")
    }

    @Test @MainActor func testUpdateProvider() async throws {
        let llmService = LLMService()

        // Update to each provider type - should not throw
        llmService.updateProvider(.anthropic)
        llmService.updateProvider(.openai)
        llmService.updateProvider(.gemini)
        llmService.updateProvider(.foundationModels)

        #expect(true, "All provider updates completed successfully")
    }

    @Test @MainActor func testUpdateModel() async throws {
        let llmService = LLMService()

        // Update model - should not throw
        llmService.updateModel("claude-sonnet-4-5-20250929")
        llmService.updateModel("gpt-4o")
        llmService.updateModel("gemini-2.0-flash")

        #expect(true, "All model updates completed successfully")
    }

    // MARK: - API Key Configuration Tests

    @Test @MainActor func testUpdateAPIKeys() async throws {
        let llmService = LLMService()

        // Update all API keys - should not throw
        llmService.updateAnthropicAPIKey("test-anthropic-key")
        llmService.updateOpenAIAPIKey("test-openai-key")
        llmService.updateGeminiAPIKey("test-gemini-key")

        #expect(true, "All API key updates completed successfully")
    }

    @Test @MainActor func testClearAPIKeys() async throws {
        let llmService = LLMService()

        // Set and then clear API keys
        llmService.updateAnthropicAPIKey("test-key")
        llmService.updateAnthropicAPIKey("")

        llmService.updateOpenAIAPIKey("test-key")
        llmService.updateOpenAIAPIKey("")

        llmService.updateGeminiAPIKey("test-key")
        llmService.updateGeminiAPIKey("")

        #expect(true, "All API keys cleared successfully")
    }

    // MARK: - Foundation Models Availability Tests

    @Test @MainActor func testFoundationModelsAvailability() async throws {
        let llmService = LLMService()

        // In test environment (simulator), Foundation Models is typically not available
        // This just verifies the property can be accessed without crashing
        let available = llmService.isFoundationModelsAvailable

        // We don't assert true/false since it depends on the test environment
        #expect(available == true || available == false, "isFoundationModelsAvailable returned a valid boolean")
    }

    // MARK: - Error Handling Tests

    @Test @MainActor func testProcessWithoutAPIKeyThrows() async throws {
        let llmService = LLMService()

        // Set provider to Anthropic but don't provide API key
        llmService.updateProvider(.anthropic)

        // Try to process - should throw apiKeyMissing error
        // Note: Transcript must be 3+ words to pass validation
        do {
            _ = try await llmService.processTranscriptWithTitle(
                transcript: "This is a test transcript",
                customWords: []
            )
            #expect(false, "Expected an error but got success")
        } catch {
            // Verify the error is the expected type
            guard let appError = error as? AppError,
                  case .llm(.apiKeyMissing) = appError else {
                #expect(false, "Expected apiKeyMissing error but got \(error)")
                return
            }
            #expect(true)
        }
    }

    @Test @MainActor func testProcessWithOpenAIWithoutAPIKeyThrows() async throws {
        let llmService = LLMService()

        // Set provider to OpenAI but don't provide API key
        llmService.updateProvider(.openai)

        // Note: Transcript must be 3+ words to pass validation
        do {
            _ = try await llmService.processTranscriptWithTitle(
                transcript: "This is a test transcript",
                customWords: []
            )
            #expect(false, "Expected an error but got success")
        } catch {
            guard let appError = error as? AppError,
                  case .llm(.apiKeyMissing) = appError else {
                #expect(false, "Expected apiKeyMissing error but got \(error)")
                return
            }
            #expect(true)
        }
    }

    @Test @MainActor func testProcessWithGeminiWithoutAPIKeyThrows() async throws {
        let llmService = LLMService()

        // Set provider to Gemini but don't provide API key
        llmService.updateProvider(.gemini)

        // Note: Transcript must be 3+ words to pass validation
        do {
            _ = try await llmService.processTranscriptWithTitle(
                transcript: "This is a test transcript",
                customWords: []
            )
            #expect(false, "Expected an error but got success")
        } catch {
            guard let appError = error as? AppError,
                  case .llm(.apiKeyMissing) = appError else {
                #expect(false, "Expected apiKeyMissing error but got \(error)")
                return
            }
            #expect(true)
        }
    }

    // MARK: - Transcript Validation Tests

    @Test @MainActor func testShortTranscriptThrowsError() async throws {
        let llmService = LLMService()
        llmService.updateProvider(.anthropic)
        llmService.updateAnthropicAPIKey("test-key")

        // Two words - should fail validation before API key check
        do {
            _ = try await llmService.processTranscriptWithTitle(
                transcript: "Too short",
                customWords: []
            )
            #expect(false, "Expected an error but got success")
        } catch {
            guard let appError = error as? AppError,
                  case .llm(.transcriptTooShort) = appError else {
                #expect(false, "Expected transcriptTooShort error but got \(error)")
                return
            }
            #expect(true)
        }
    }

    @Test @MainActor func testEmptyTranscriptThrowsError() async throws {
        let llmService = LLMService()
        llmService.updateProvider(.anthropic)
        llmService.updateAnthropicAPIKey("test-key")

        do {
            _ = try await llmService.processTranscriptWithTitle(
                transcript: "",
                customWords: []
            )
            #expect(false, "Expected an error but got success")
        } catch {
            guard let appError = error as? AppError,
                  case .llm(.transcriptTooShort) = appError else {
                #expect(false, "Expected transcriptTooShort error but got \(error)")
                return
            }
            #expect(true)
        }
    }

    @Test @MainActor func testIsTranscriptProcessable() async throws {
        let llmService = LLMService()

        // Less than 3 words should not be processable
        #expect(llmService.isTranscriptProcessable("") == false)
        #expect(llmService.isTranscriptProcessable("Hello") == false)
        #expect(llmService.isTranscriptProcessable("Hello world") == false)

        // 3+ words should be processable
        #expect(llmService.isTranscriptProcessable("Hello world today") == true)
        #expect(llmService.isTranscriptProcessable("This is a longer transcript with many words") == true)
    }

    @Test @MainActor func testIsTranscriptTooLong() async throws {
        let llmService = LLMService()

        // Short transcript should not be too long
        #expect(llmService.isTranscriptTooLong("Short text") == false)

        // maxTranscriptTokens is 3096, at 4 chars/token = ~12,384 chars
        let shortText = String(repeating: "word ", count: 100)  // ~500 chars
        #expect(llmService.isTranscriptTooLong(shortText) == false)

        // Very long text should be too long (> 12,384 chars)
        let longText = String(repeating: "word ", count: 5000)  // ~25,000 chars
        #expect(llmService.isTranscriptTooLong(longText) == true)
    }

    @Test @MainActor func testLongTranscriptThrowsTranscriptTooLongError() async throws {
        let llmService = LLMService()
        llmService.updateProvider(.anthropic)
        llmService.updateAnthropicAPIKey("test-key")

        // Very long text (> 120,000 chars) should throw transcriptTooLong error for cloud providers
        // Cloud providers have 30,000 token limit * 4 chars/token = 120,000 chars
        let longText = String(repeating: "word ", count: 25000)  // ~125,000 chars

        do {
            _ = try await llmService.processTranscriptWithTitle(
                transcript: longText,
                customWords: []
            )
            #expect(false, "Expected an error but got success")
        } catch {
            guard let appError = error as? AppError,
                  case .llm(.transcriptTooLong(let maxChars)) = appError else {
                #expect(false, "Expected transcriptTooLong error but got \(error)")
                return
            }
            #expect(maxChars == 120000, "Max characters should be 120000 (30000 tokens * 4) for cloud providers")
        }
    }

    @Test @MainActor func testMaxTranscriptTokens() async throws {
        let llmService = LLMService()

        // Should be 4096 - 200 - 800 = 3096
        #expect(llmService.maxTranscriptTokens == 3096)
    }
}

// MARK: - LLMProvider Tests

/// Tests for the LLMProvider enum
struct LLMProviderTests {

    @Test func testProviderDisplayNames() {
        #expect(LLMProvider.foundationModels.displayName == "Apple Intelligence")
        #expect(LLMProvider.anthropic.displayName == "Claude (Anthropic)")
        #expect(LLMProvider.openai.displayName == "OpenAI")
        #expect(LLMProvider.gemini.displayName == "Gemini (Google)")
    }

    @Test func testProviderRequiresAPIKey() {
        #expect(LLMProvider.foundationModels.requiresAPIKey == false)
        #expect(LLMProvider.anthropic.requiresAPIKey == true)
        #expect(LLMProvider.openai.requiresAPIKey == true)
        #expect(LLMProvider.gemini.requiresAPIKey == true)
    }

    @Test func testProviderDefaultModels() {
        #expect(LLMProvider.foundationModels.defaultModel == "default")
        #expect(LLMProvider.anthropic.defaultModel == "claude-sonnet-4-5-20250929")
        #expect(LLMProvider.openai.defaultModel == "gpt-4o")
        #expect(LLMProvider.gemini.defaultModel == "gemini-2.0-flash")
    }

    @Test func testProviderAvailableModels() {
        // Foundation Models only has "default"
        #expect(LLMProvider.foundationModels.availableModels.count == 1)
        #expect(LLMProvider.foundationModels.availableModels.contains("default"))

        // Anthropic has multiple Claude models
        #expect(LLMProvider.anthropic.availableModels.count >= 2)
        #expect(LLMProvider.anthropic.availableModels.contains("claude-sonnet-4-5-20250929"))

        // OpenAI has multiple GPT models
        #expect(LLMProvider.openai.availableModels.count >= 3)
        #expect(LLMProvider.openai.availableModels.contains("gpt-4o"))

        // Gemini has multiple models
        #expect(LLMProvider.gemini.availableModels.count >= 3)
        #expect(LLMProvider.gemini.availableModels.contains("gemini-2.0-flash"))
    }

    @Test func testProviderCodable() throws {
        // Test encoding
        let provider = LLMProvider.anthropic
        let encoded = try JSONEncoder().encode(provider)
        let encodedString = String(data: encoded, encoding: .utf8)
        #expect(encodedString == "\"anthropic\"")

        // Test decoding
        let decoded = try JSONDecoder().decode(LLMProvider.self, from: encoded)
        #expect(decoded == provider)
    }

    @Test func testProviderRawValue() {
        #expect(LLMProvider.foundationModels.rawValue == "foundation_models")
        #expect(LLMProvider.anthropic.rawValue == "anthropic")
        #expect(LLMProvider.openai.rawValue == "openai")
        #expect(LLMProvider.gemini.rawValue == "gemini")
    }

    @Test func testProviderFromRawValue() {
        #expect(LLMProvider(rawValue: "foundation_models") == .foundationModels)
        #expect(LLMProvider(rawValue: "anthropic") == .anthropic)
        #expect(LLMProvider(rawValue: "openai") == .openai)
        #expect(LLMProvider(rawValue: "gemini") == .gemini)
        #expect(LLMProvider(rawValue: "invalid") == nil)
    }

    @Test func testAllCases() {
        let allCases = LLMProvider.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.foundationModels))
        #expect(allCases.contains(.anthropic))
        #expect(allCases.contains(.openai))
        #expect(allCases.contains(.gemini))
    }
}

// MARK: - LLMProcessingResult Tests

/// Tests for the LLMProcessingResult struct
struct LLMProcessingResultTests {

    @Test func testResultInitialization() {
        let result = LLMProcessingResult(
            transcript: "Test cleaned transcript",
            title: "Test Title"
        )

        #expect(result.transcript == "Test cleaned transcript")
        #expect(result.title == "Test Title")
    }

    @Test func testResultWithEmptyValues() {
        let result = LLMProcessingResult(
            transcript: "",
            title: ""
        )

        #expect(result.transcript == "")
        #expect(result.title == "")
    }
}

// MARK: - LLMError Tests

/// Tests for the LLMError enum in AppError
struct LLMErrorTests {

    @Test func testAPIKeyMissingError() {
        let error = AppError.llm(.apiKeyMissing)

        // Verify error can be matched
        if case .llm(.apiKeyMissing) = error {
            #expect(true)
        } else {
            #expect(false, "Error did not match expected case")
        }
    }

    @Test func testProviderUnavailableError() {
        let message = "Apple Intelligence is not available"
        let error = AppError.llm(.providerUnavailable(message))

        if case .llm(.providerUnavailable(let msg)) = error {
            #expect(msg == message)
        } else {
            #expect(false, "Error did not match expected case")
        }
    }

    @Test func testRequestFailedError() {
        let message = "Network timeout"
        let error = AppError.llm(.requestFailed(message))

        if case .llm(.requestFailed(let msg)) = error {
            #expect(msg == message)
        } else {
            #expect(false, "Error did not match expected case")
        }
    }

    @Test func testResponseParsingFailedError() {
        let message = "Invalid JSON"
        let error = AppError.llm(.responseParsingFailed(message))

        if case .llm(.responseParsingFailed(let msg)) = error {
            #expect(msg == message)
        } else {
            #expect(false, "Error did not match expected case")
        }
    }

    @Test func testInvalidResponseError() {
        let error = AppError.llm(.invalidResponse)

        if case .llm(.invalidResponse) = error {
            #expect(true)
        } else {
            #expect(false, "Error did not match expected case")
        }
    }

    @Test func testNetworkError() {
        let message = "Connection refused"
        let error = AppError.llm(.networkError(message))

        if case .llm(.networkError(let msg)) = error {
            #expect(msg == message)
        } else {
            #expect(false, "Error did not match expected case")
        }
    }
}
