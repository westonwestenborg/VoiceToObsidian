import Foundation
import OSLog

/// A service that interfaces with the Anthropic Claude API to process voice transcripts.
///
/// `AnthropicService` provides functionality to clean and format raw voice transcripts
/// using Anthropic's Claude AI model. It handles communication with the Anthropic API,
/// including request formatting, error handling, and response parsing.
///
/// The service can process transcripts to:
/// - Remove filler words (um, uh, like, etc.)
/// - Fix grammatical errors and repetitions
/// - Format text in a clear, readable way
/// - Generate appropriate titles based on content
///
/// - Important: This service requires a valid Anthropic API key to function.
///
/// ## Example Usage
/// ```swift
/// let anthropicService = AnthropicService(apiKey: "your-api-key")
///
/// // Process a transcript
/// do {
///     let cleanedTranscript = try await anthropicService.processTranscriptAsync(transcript: rawTranscript)
///     print("Cleaned transcript: \(cleanedTranscript)")
/// } catch {
///     print("Failed to process transcript: \(error)")
/// }
///
/// // Process a transcript and get a title
/// do {
///     let result = try await anthropicService.processTranscriptWithTitleAsync(transcript: rawTranscript)
///     print("Title: \(result.title)")
///     print("Cleaned transcript: \(result.transcript)")
/// } catch {
///     print("Failed to process transcript: \(error)")
/// }
/// ```
class AnthropicService {
    /// The API key used for authenticating with the Anthropic API.
    ///
    /// This key can be updated using the `updateAPIKey(_:)` method.
    private var apiKey: String
    
    /// The base URL for the Anthropic API messages endpoint.
    ///
    /// This is the endpoint used for all API requests to Claude.
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    /// Logger for structured logging of API operations.
    ///
    /// Uses OSLog for efficient and structured logging of API requests, responses, and errors.
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "AnthropicService")
    
    /// Initializes a new AnthropicService instance.
    ///
    /// - Parameter apiKey: The Anthropic API key to use for authentication. Can be empty
    ///                     and set later using `updateAPIKey(_:)`. Default is an empty string.
    init(apiKey: String = "") {
        self.apiKey = apiKey
        logger.debug("AnthropicService initialized")
    }
    
    /// Updates the API key used for authentication with the Anthropic API.
    ///
    /// This method allows changing the API key after initialization, which is useful
    /// when the key is obtained from user input or loaded from secure storage.
    ///
    /// - Parameter key: The new Anthropic API key to use
    ///
    /// ## Example
    /// ```swift
    /// // Update API key from settings
    /// anthropicService.updateAPIKey(userSettings.anthropicApiKey)
    /// ```
    func updateAPIKey(_ key: String) {
        self.apiKey = key
        logger.debug("API key updated")
    }
    

    
    /// Parses the LLM response to extract the title and cleaned transcript.
    ///
    /// This method parses the formatted response from Claude to extract the title
    /// and cleaned transcript sections. It expects the response to follow the format
    /// specified in the prompt, with "TITLE:" and "CLEANED TRANSCRIPT:" markers.
    ///
    /// - Parameter response: The raw text response from the LLM
    /// - Returns: A tuple containing:
    ///   - `title`: The extracted title, or nil if not found
    ///   - `cleanedTranscript`: The extracted cleaned transcript, or nil if not found
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
    
    /// Processes a transcript with the Anthropic Claude API using async/await pattern.
    ///
    /// This method sends the original transcript to the Anthropic Claude API for processing
    /// and returns the cleaned and formatted transcript. It handles the entire API communication
    /// process including:
    /// - Creating the API request with appropriate headers and body
    /// - Sending the request and handling responses
    /// - Parsing the response to extract the cleaned transcript
    /// - Error handling for various failure scenarios
    ///
    /// - Parameter transcript: The original transcript to process
    /// - Returns: The cleaned and formatted transcript
    /// - Throws: `AppError.anthropic` with details about what went wrong
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let cleanedTranscript = try await anthropicService.processTranscriptAsync(transcript: rawTranscript)
    ///     // Use the cleaned transcript
    /// } catch let error as AppError {
    ///     // Handle specific app error
    /// } catch {
    ///     // Handle other errors
    /// }
    /// ```
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
        
        // Create the request body with the prompt for transcript cleaning
        let promptText = """
        I have a voice memo transcript that needs to be cleaned up. Please:
        
        1. Remove filler words (um, uh, like, etc.)
        2. Fix any grammatical errors or repetitions
        3. Format the text in a clear, readable way. Add proper punctuation and spacing
        4. If the transcript lists items, format them in a bulleted list
        5. If the transcript lists to do items, format them in a bulleted list with checkboxes (- [ ])
        6. If the transcript gives you instructions, follow them to the best of your ability
        7. Suggest a concise title for this note (max 5-7 words)
        
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
    
    /// Processes a transcript with the Anthropic Claude API and returns both title and transcript.
    ///
    /// This method is similar to `processTranscriptAsync(transcript:)` but returns both the
    /// cleaned transcript and a suggested title for the note. It uses the same API call but
    /// parses the response differently to extract both pieces of information.
    ///
    /// - Parameter transcript: The original transcript to process
    /// - Returns: A tuple containing:
    ///   - `transcript`: The cleaned and formatted transcript
    ///   - `title`: A suggested title for the note based on its content
    /// - Throws: `AppError.anthropic` with details about what went wrong
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let result = try await anthropicService.processTranscriptWithTitleAsync(transcript: rawTranscript)
    ///     print("Title: \(result.title)")
    ///     print("Transcript: \(result.transcript)")
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
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
        
        // Create the request body with the prompt for transcript cleaning and title generation
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
