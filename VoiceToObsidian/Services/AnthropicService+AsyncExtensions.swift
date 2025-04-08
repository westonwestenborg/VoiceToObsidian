import Foundation
import OSLog

// MARK: - Swift Concurrency Extensions for AnthropicService
extension AnthropicService {
    
    // Logger for async extensions
    private var asyncLogger: Logger {
        Logger(subsystem: "com.voicetoobsidian.app", category: "AnthropicService.Async")
    }
    
    /// Processes a transcript with the Anthropic Claude API using async/await
    /// - Parameter transcript: The original transcript to process
    /// - Returns: The cleaned transcript
    /// - Throws: AppError if processing fails
    func processTranscriptAsync(transcript: String) async throws -> String {
        asyncLogger.debug("Processing transcript with Anthropic API using async/await")
        
        guard !apiKey.isEmpty else {
            asyncLogger.error("Anthropic API key not set")
            throw AppError.anthropic(.apiKeyMissing)
        }
        
        // Create the request
        guard let url = URL(string: baseURL) else {
            asyncLogger.error("Invalid URL: \(self.baseURL)")
            throw AppError.anthropic(.requestCreationFailed)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        // Create the request body with the same prompt as the original method
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
            asyncLogger.error("Error creating request body: \(error.localizedDescription)")
            throw AppError.anthropic(.requestCreationFailed)
        }
        
        // Make the request using async/await
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for HTTP errors
            guard let httpResponse = response as? HTTPURLResponse else {
                asyncLogger.error("Invalid HTTP response")
                throw AppError.anthropic(.invalidResponse)
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                asyncLogger.error("HTTP error: \(httpResponse.statusCode)")
                
                // Try to extract error message from response
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["error"] as? [String: Any],
                   let message = errorMessage["message"] as? String {
                    throw AppError.anthropic(.apiError(message))
                } else {
                    throw AppError.anthropic(.apiError("HTTP \(httpResponse.statusCode)"))
                }
            }
            
            // Parse the response
            if let responseString = String(data: data, encoding: .utf8) {
                asyncLogger.debug("Received API response: \(responseString.prefix(100))...")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                asyncLogger.error("Failed to parse API response")
                throw AppError.anthropic(.responseParsingFailed("Invalid response format"))
            }
            
            // Parse the response to extract title and cleaned transcript
            let (title, cleanedTranscript) = self.parseResponse(text)
            
            if let cleanedTranscript = cleanedTranscript {
                asyncLogger.debug("Successfully processed transcript with Anthropic API")
                return cleanedTranscript
            } else {
                // If we couldn't extract the cleaned transcript, return the original text
                asyncLogger.warning("Could not extract cleaned transcript, using original response")
                return text
            }
        } catch {
            if let appError = error as? AppError {
                asyncLogger.error("AppError: \(appError.localizedDescription)")
                throw appError
            } else {
                asyncLogger.error("Error processing transcript: \(error.localizedDescription)")
                throw AppError.anthropic(.networkError(error.localizedDescription))
            }
        }
    }
    
    /// Processes a transcript with the Anthropic Claude API using async/await and returns both title and transcript
    /// - Parameter transcript: The original transcript to process
    /// - Returns: A tuple containing the cleaned transcript and suggested title
    /// - Throws: AppError if processing fails
    func processTranscriptWithTitleAsync(transcript: String) async throws -> (transcript: String, title: String) {
        asyncLogger.debug("Processing transcript with title using Anthropic API")
        
        guard !apiKey.isEmpty else {
            asyncLogger.error("Anthropic API key not set")
            throw AppError.anthropic(.apiKeyMissing)
        }
        
        // Create the request
        guard let url = URL(string: baseURL) else {
            asyncLogger.error("Invalid URL: \(self.baseURL)")
            throw AppError.anthropic(.requestCreationFailed)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        // Create the request body with the same prompt as the original method
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
            asyncLogger.error("Error creating request body: \(error.localizedDescription)")
            throw AppError.anthropic(.requestCreationFailed)
        }
        
        // Make the request using async/await
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for HTTP errors
            guard let httpResponse = response as? HTTPURLResponse else {
                asyncLogger.error("Invalid HTTP response")
                throw AppError.anthropic(.invalidResponse)
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                asyncLogger.error("HTTP error: \(httpResponse.statusCode)")
                throw AppError.anthropic(.apiError("HTTP \(httpResponse.statusCode)"))
            }
            
            // Parse the response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                asyncLogger.error("Failed to parse API response")
                throw AppError.anthropic(.responseParsingFailed("Invalid response format"))
            }
            
            // Parse the response to extract title and cleaned transcript
            let (title, cleanedTranscript) = self.parseResponse(text)
            
            if let title = title, let cleanedTranscript = cleanedTranscript {
                asyncLogger.debug("Successfully processed transcript with title")
                return (transcript: cleanedTranscript, title: title)
            } else {
                // If we couldn't extract the title or transcript, use defaults
                let defaultTitle = "Voice Note \(DateFormatUtil.shared.formatTimestamp(date: Date()))"
                asyncLogger.warning("Could not extract title or transcript, using defaults")
                return (transcript: text, title: defaultTitle)
            }
        } catch {
            if let appError = error as? AppError {
                throw appError
            } else {
                asyncLogger.error("Error processing transcript: \(error.localizedDescription)")
                throw AppError.anthropic(.networkError(error.localizedDescription))
            }
        }
    }
}
