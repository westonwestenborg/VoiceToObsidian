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
    
    /// Processes a transcript with the Anthropic Claude API
    /// - Parameters:
    ///   - transcript: The original transcript to process
    ///   - completion: Completion handler with success status, cleaned transcript, and suggested title
    /// - Note: This method is deprecated. Use the async version with AsyncBridge for better memory management.
    @available(*, deprecated, message: "Use processTranscriptAsync(transcript:) async throws -> String with AsyncBridge instead")
    func processTranscript(_ transcript: String, completion: @escaping (Bool, String?, String?) -> Void) {
        guard !apiKey.isEmpty else {
            logger.error("Anthropic API key not set")
            let error = AppError.anthropic(.apiKeyMissing)
            // We can't directly handle the error here since this is a service class
            // The caller will need to handle this error based on the false success status
            completion(false, nil, nil)
            return
        }
        
        // Create the request
        guard let url = URL(string: baseURL) else {
            let error = AppError.anthropic(.requestCreationFailed)
            print("Invalid URL: \(baseURL)")
            completion(false, nil, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        // Note: According to the docs, we only need x-api-key, not Authorization
        
        // Create the request body
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
            let appError = AppError.anthropic(.requestCreationFailed)
            print("Error creating request body: \(error.localizedDescription)")
            completion(false, nil, nil)
            return
        }
        
        // Make the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error making API request: \(error.localizedDescription)")
                let appError = AppError.anthropic(.networkError(error.localizedDescription))
                print(appError.errorDescription ?? "Network error")
                completion(false, nil, nil)
                return
            }
            
            guard let data = data else {
                let appError = AppError.anthropic(.invalidResponse)
                print(appError.errorDescription ?? "No data received")
                completion(false, nil, nil)
                return
            }
            
            do {
                // Print the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw API response: \(responseString.prefix(200))...")
                }
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Based on the documentation, the response format should be:
                    // { "content": [ { "text": "...", "type": "text" } ], ... }
                    if let content = json["content"] as? [[String: Any]],
                       let firstContent = content.first,
                       let text = firstContent["text"] as? String {
                        
                        print("Successfully parsed API response")
                        // Parse the response to extract title and cleaned transcript
                        let (title, cleanedTranscript) = self.parseResponse(text)
                        
                        if let title = title, let cleanedTranscript = cleanedTranscript {
                            print("Extracted title: \(title)")
                            print("Extracted transcript length: \(cleanedTranscript.count) characters")
                            
                            DispatchQueue.main.async {
                                completion(true, cleanedTranscript, title)
                            }
                        } else {
                            print("Failed to extract title or transcript from response")
                            // If parsing fails, use the original text and a default title
                            let defaultTitle = "Voice Note \(DateFormatUtil.shared.formatTimestamp(date: Date()))" 
                            DispatchQueue.main.async {
                                completion(true, text, defaultTitle)
                            }
                        }
                    } else {
                        print("Unexpected API response format: \(json)")
                        // If we can't parse the response properly, use the transcript as is
                        let title = "Voice Note \(DateFormatUtil.shared.formatTimestamp(date: Date()))" 
                        DispatchQueue.main.async {
                            completion(true, transcript, title)
                        }
                    }
                } else {
                    let appError = AppError.anthropic(.responseParsingFailed("Failed to parse JSON response"))
                    print(appError.errorDescription ?? "Failed to parse JSON response")
                    completion(false, nil, nil)
                }
            } catch {
                let appError = AppError.anthropic(.responseParsingFailed(error.localizedDescription))
                print("Error parsing API response: \(error.localizedDescription)")
                completion(false, nil, nil)
            }
        }
        
        task.resume()
    }
    
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
}
