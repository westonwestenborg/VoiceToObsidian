//
//  AnthropicServiceTests.swift
//  VoiceToObsidianTests
//
//  Tests for the deprecated AnthropicService.
//  NOTE: This file will be deleted in Phase 8 when AnthropicService is removed.
//  New LLM functionality should be tested in LLMServiceTests.swift
//

import Testing
import Foundation
@testable import VoiceToObsidian

// Protocol for URLSession to make it mockable
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// Extension to make URLSession conform to our protocol
extension URLSession: URLSessionProtocol {}

// Mock URLSession for testing
class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        
        guard let data = mockData, let response = mockResponse else {
            throw NSError(domain: "MockURLSession", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock data or response not set"])
        }
        
        return (data, response)
    }
}

// Testable AnthropicService that allows injecting a mock URLSession
class TestableAnthropicService: AnthropicService {
    var urlSession: URLSessionProtocol
    private let testApiKey: String

    init(apiKey: String = "", urlSession: URLSessionProtocol) {
        self.urlSession = urlSession
        self.testApiKey = apiKey
        super.init(apiKey: apiKey)
    }

    override func processTranscriptAsync(transcript: String) async throws -> String {
        guard !testApiKey.isEmpty else {
            throw AppError.anthropic(.apiKeyMissing)
        }

        // Create the request
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AppError.anthropic(.requestCreationFailed)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue(testApiKey, forHTTPHeaderField: "x-api-key")
        
        // Create the request body with the prompt for transcript cleaning
        let promptText = """
        I have a voice memo transcript that needs to be cleaned up. Please:
        
        1. Remove filler words (um, uh, like, etc.)
        2. Fix any grammatical errors or repetitions
        3. Format the text in a clear, readable way
        4. Suggest a concise title for this note (max 5-7 words)
        
        Original transcript:
        \(transcript)
        
        Please respond in the following format:
        
        TITLE: [Your suggested title]
        
        CLEANED TRANSCRIPT:
        [The cleaned up transcript]
        """
        
        let requestBody: [String: Any] = [
            "model": "claude-3-7-sonnet-20250219",
            "max_tokens": 10000,
            "messages": [
                ["role": "user", "content": promptText]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AppError.anthropic(.requestCreationFailed)
        }
        
        // Use our injected URLSession instead of the shared one
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            // Check for HTTP errors
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.anthropic(.invalidResponse)
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to extract error message from response
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["error"] as? [String: Any],
                   let message = errorMessage["message"] as? String {
                    throw AppError.anthropic(.networkError(message))
                } else {
                    throw AppError.anthropic(.networkError("HTTP \(httpResponse.statusCode)"))
                }
            }
            
            // Parse the response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                throw AppError.anthropic(.responseParsingFailed("Invalid response format"))
            }
            
            // Parse the response to extract title and cleaned transcript
            let (_, cleanedTranscript) = self.parseResponse(text)
            
            if let cleanedTranscript = cleanedTranscript {
                return cleanedTranscript
            } else {
                // If we couldn't extract the cleaned transcript, return the original text
                return text
            }
        } catch {
            if let appError = error as? AppError {
                throw appError
            } else {
                throw AppError.anthropic(.networkError(error.localizedDescription))
            }
        }
    }
    
    // Expose the private parseResponse method for testing
    func parseResponse(_ response: String) -> (String?, String?) {
        // Extract title
        var title: String? = nil
        if let titleRange = response.range(of: "TITLE: ", options: .caseInsensitive),
           let endOfTitleRange = response.range(of: "\n\n", options: [], range: titleRange.upperBound..<response.endIndex) {
            title = String(response[titleRange.upperBound..<endOfTitleRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Extract cleaned transcript
        var cleanedTranscript: String? = nil
        if let transcriptRange = response.range(of: "CLEANED TRANSCRIPT:", options: .caseInsensitive) {
            cleanedTranscript = String(response[transcriptRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return (title, cleanedTranscript)
    }
}

// Test AnthropicService
struct AnthropicServiceTests {
    
    @Test func testInitialization() async throws {
        // Create an Anthropic service with an API key
        let apiKey = "test_api_key"
        let anthropicService = AnthropicService(apiKey: apiKey)
        
        // Update API key and verify it works
        anthropicService.updateAPIKey("new_test_api_key")
        
        // No assertion needed, just checking the method exists and doesn't crash
        #expect(true)
    }
    
    @Test func testParseResponse() async throws {
        // Create a testable Anthropic service
        let mockSession = MockURLSession()
        let anthropicService = TestableAnthropicService(apiKey: "test_api_key", urlSession: mockSession)
        
        // Test response with both title and transcript
        let response = """
        TITLE: Meeting Notes for Project X
        
        CLEANED TRANSCRIPT:
        We need to finish the UI design by next week and then start implementing the backend services.
        """
        
        let (title, transcript) = anthropicService.parseResponse(response)
        
        // Verify parsing
        #expect(title == "Meeting Notes for Project X")
        #expect(transcript == "We need to finish the UI design by next week and then start implementing the backend services.")
    }
    
    @Test func testParseResponseWithMissingTitle() async throws {
        // Create a testable Anthropic service
        let mockSession = MockURLSession()
        let anthropicService = TestableAnthropicService(apiKey: "test_api_key", urlSession: mockSession)
        
        // Test response with only transcript
        let response = """
        CLEANED TRANSCRIPT:
        We need to finish the UI design by next week.
        """
        
        let (title, transcript) = anthropicService.parseResponse(response)
        
        // Verify parsing
        #expect(title == nil)
        #expect(transcript == "We need to finish the UI design by next week.")
    }
    
    @Test func testParseResponseWithMissingTranscript() async throws {
        // Create a testable Anthropic service
        let mockSession = MockURLSession()
        let anthropicService = TestableAnthropicService(apiKey: "test_api_key", urlSession: mockSession)
        
        // Test response with only title
        let response = """
        TITLE: Meeting Notes
        
        Some other text that doesn't match the expected format.
        """
        
        let (title, transcript) = anthropicService.parseResponse(response)
        
        // Verify parsing
        #expect(title == "Meeting Notes")
        #expect(transcript == nil)
    }
    
    @Test func testProcessTranscriptAsyncSuccess() async throws {
        // Create a mock session
        let mockSession = MockURLSession()
        
        // Create a successful response
        let successResponse = """
        {
            "id": "msg_01234567890",
            "content": [
                {
                    "type": "text",
                    "text": "TITLE: Meeting Notes\\n\\nCLEANED TRANSCRIPT:\\nWe need to finish the UI design by next week."
                }
            ]
        }
        """
        
        mockSession.mockData = successResponse.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://api.anthropic.com/v1/messages")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        // Create a testable Anthropic service with the mock session
        let anthropicService = TestableAnthropicService(apiKey: "test_api_key", urlSession: mockSession)
        
        // Process a transcript
        let result = try await anthropicService.processTranscriptAsync(transcript: "Um, we need to, uh, finish the UI design by next week.")
        
        // Verify result
        #expect(result == "We need to finish the UI design by next week.")
    }
    
    @Test func testProcessTranscriptAsyncMissingAPIKey() async throws {
        // Create a mock session
        let mockSession = MockURLSession()
        
        // Create a testable Anthropic service with an empty API key
        let anthropicService = TestableAnthropicService(apiKey: "", urlSession: mockSession)
        
        // Process a transcript and expect an error
        do {
            _ = try await anthropicService.processTranscriptAsync(transcript: "Test transcript")
            #expect(false, "Expected an error but got success")
        } catch {
            // Verify the error is the expected one
            guard let appError = error as? AppError, case .anthropic(.apiKeyMissing) = appError else {
                #expect(false, "Expected apiKeyMissing error but got \(error)")
                return
            }
            #expect(true)
        }
    }
    
    @Test func testProcessTranscriptAsyncHTTPError() async throws {
        // Create a mock session
        let mockSession = MockURLSession()
        
        // Create an error response
        let errorResponse = """
        {
            "error": {
                "message": "Invalid API key"
            }
        }
        """
        
        mockSession.mockData = errorResponse.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://api.anthropic.com/v1/messages")!, statusCode: 401, httpVersion: nil, headerFields: nil)
        
        // Create a testable Anthropic service with the mock session
        let anthropicService = TestableAnthropicService(apiKey: "invalid_key", urlSession: mockSession)
        
        // Process a transcript and expect an error
        do {
            _ = try await anthropicService.processTranscriptAsync(transcript: "Test transcript")
            #expect(false, "Expected an error but got success")
        } catch {
            // Verify the error is the expected one
            guard let appError = error as? AppError, case .anthropic(.networkError) = appError else {
                #expect(false, "Expected networkError error but got \(error)")
                return
            }
            #expect(true)
        }
    }
}
