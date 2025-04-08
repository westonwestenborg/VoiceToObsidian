import Foundation
import OSLog

class AnthropicService {
    private var apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    // Logger for AnthropicService
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "AnthropicService")
    
    init(apiKey: String = "") {
        self.apiKey = apiKey
        logger.debug("AnthropicService initialized")
    }
    
    /// Updates the API key
    /// - Parameter key: The Anthropic API key
    func updateAPIKey(_ key: String) {
        self.apiKey = key
        logger.debug("API key updated")
    }
    
    // Deprecated callback-based method removed - using async version only
    
    /// Parses the LLM response to extract the title and cleaned transcript
    /// - Parameter response: The raw response from the LLM
    /// - Returns: A tuple containing the title and cleaned transcript
    private func parseResponse(_ response: String) -> (String?, String?) {
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
    
    // MARK: - Async Methods
    
    /// Processes a transcript with the Anthropic Claude API using async/await
    /// - Parameter transcript: The original transcript to process
    /// - Returns: The cleaned transcript
    /// - Throws: AppError if processing fails
    func processTranscriptAsync(transcript: String) async throws -> String {
        logger.debug("Processing transcript with Anthropic API using async/await")
        
        guard !apiKey.isEmpty else {
            logger.error("Anthropic API key not set")
            throw AppError.anthropic(.apiKeyMissing)
        }
        
        // Create the request
        guard let url = URL(string: baseURL) else {
            logger.error("Invalid URL: \(self.baseURL)")
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
            logger.error("Error creating request body: \(error.localizedDescription)")
            throw AppError.anthropic(.requestCreationFailed)
        }
        
        // Make the request using async/await
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for HTTP errors
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid HTTP response")
                throw AppError.anthropic(.invalidResponse)
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                logger.error("HTTP error: \(httpResponse.statusCode)")
                
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
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Received API response: \(responseString.prefix(100))...")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                logger.error("Failed to parse API response")
                throw AppError.anthropic(.responseParsingFailed("Invalid response format"))
            }
            
            // Parse the response to extract title and cleaned transcript
            let (title, cleanedTranscript) = self.parseResponse(text)
            
            if let cleanedTranscript = cleanedTranscript {
                logger.debug("Successfully processed transcript with Anthropic API")
                return cleanedTranscript
            } else {
                // If we couldn't extract the cleaned transcript, return the original text
                logger.warning("Could not extract cleaned transcript, using original response")
                return text
            }
        } catch {
            if let appError = error as? AppError {
                logger.error("AppError: \(appError.localizedDescription)")
                throw appError
            } else {
                logger.error("Error processing transcript: \(error.localizedDescription)")
                throw AppError.anthropic(.networkError(error.localizedDescription))
            }
        }
    }
    
    /// Processes a transcript with the Anthropic Claude API using async/await and returns both title and transcript
    /// - Parameter transcript: The original transcript to process
    /// - Returns: A tuple containing the cleaned transcript and suggested title
    /// - Throws: AppError if processing fails
    func processTranscriptWithTitleAsync(transcript: String) async throws -> (transcript: String, title: String) {
        logger.debug("Processing transcript with title using Anthropic API")
        
        guard !apiKey.isEmpty else {
            logger.error("Anthropic API key not set")
            throw AppError.anthropic(.apiKeyMissing)
        }
        
        // Create the request
        guard let url = URL(string: baseURL) else {
            logger.error("Invalid URL: \(self.baseURL)")
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
            logger.error("Error creating request body: \(error.localizedDescription)")
            throw AppError.anthropic(.requestCreationFailed)
        }
        
        // Make the request using async/await
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for HTTP errors
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid HTTP response")
                throw AppError.anthropic(.invalidResponse)
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                logger.error("HTTP error: \(httpResponse.statusCode)")
                
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
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Received API response: \(responseString.prefix(100))...")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                logger.error("Failed to parse API response")
                throw AppError.anthropic(.responseParsingFailed("Invalid response format"))
            }
            
            // Parse the response to extract title and cleaned transcript
            let (title, cleanedTranscript) = self.parseResponse(text)
            
            if let cleanedTranscript = cleanedTranscript, let title = title {
                logger.debug("Successfully processed transcript with title")
                return (transcript: cleanedTranscript, title: title)
            } else {
                // If we couldn't extract the title or cleaned transcript, use defaults
                logger.warning("Could not extract title or cleaned transcript, using defaults")
                let defaultTitle = "Voice Note \(DateFormatUtil.shared.formatTimestamp(date: Date()))"
                return (transcript: text, title: title ?? defaultTitle)
            }
        } catch {
            if let appError = error as? AppError {
                logger.error("AppError: \(appError.localizedDescription)")
                throw appError
            } else {
                logger.error("Error processing transcript: \(error.localizedDescription)")
                throw AppError.anthropic(.networkError(error.localizedDescription))
            }
        }
    }
}
