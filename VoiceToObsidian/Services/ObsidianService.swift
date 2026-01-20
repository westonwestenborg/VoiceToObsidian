import Foundation
import Security
import OSLog

/// A service that manages interactions with the Obsidian vault.
///
/// `ObsidianService` provides functionality for creating and managing notes in an Obsidian vault.
/// It handles operations such as:
/// - Creating markdown files for voice notes
/// - Copying audio files to the vault's attachments directory
/// - Managing vault path configuration
/// - Handling security-scoped bookmark access
///
/// This service works closely with the `SecurityManager` to ensure proper access to the
/// Obsidian vault directory across app launches.
///
/// ## Example Usage
/// ```swift
/// let obsidianService = ObsidianService(vaultPath: "/path/to/vault")
///
/// // Save a voice note to the Obsidian vault
/// do {
///     let result = try await obsidianService.createVoiceNoteFile(for: voiceNote)
///     if result.success {
///         print("Note saved at: \(result.path ?? "")")
///     }
/// } catch {
///     print("Failed to save note: \(error)")
/// }
///
/// // Copy an audio file to the vault
/// do {
///     let success = try await obsidianService.copyAudioFileToVault(from: audioURL)
///     if success {
///         print("Audio file copied successfully")
///     }
/// } catch {
///     print("Failed to copy audio file: \(error)")
/// }
/// ```
class ObsidianService {
    /// The file manager used for file operations.
    private let fileManager = FileManager.default
    
    /// The path to the Obsidian vault directory.
    ///
    /// This path is used as a fallback when security-scoped bookmarks are not available.
    /// It can be updated using the `updateVaultPath(_:)` method.
    private var vaultPath: String
    
    /// Initializes a new ObsidianService instance.
    ///
    /// - Parameter vaultPath: The path to the Obsidian vault directory
    init(vaultPath: String) {
        self.vaultPath = vaultPath
    }
    
    // MARK: - Public Methods
    
    /// Logger for structured logging of Obsidian operations.
    ///
    /// Uses OSLog for efficient and structured logging of file operations and errors.
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "ObsidianService")
    
    /// Creates a new note in the Obsidian vault with the voice note content.
    ///
    /// This method creates a markdown file in the Obsidian vault's "Voice Notes" directory
    /// containing the formatted content of the provided voice note. It handles:
    /// - Accessing the vault using security-scoped bookmarks
    /// - Creating necessary directories if they don't exist
    /// - Generating markdown content with proper formatting
    /// - Writing the file to disk
    /// - Error handling for various file system issues
    ///
    /// - Parameter voiceNote: The voice note to save to Obsidian
    /// - Returns: A tuple containing:
    ///   - `success`: Boolean indicating whether the operation succeeded
    ///   - `path`: The relative path to the created note within the vault, if successful
    /// - Throws: `AppError.obsidian` with details about what went wrong
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let result = try await obsidianService.createVoiceNoteFile(for: voiceNote)
    ///     if result.success {
    ///         print("Note created at: \(result.path ?? "")")
    ///     }
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
    func createVoiceNoteFile(for voiceNote: VoiceNote) async throws -> (success: Bool, path: String?) {
        logger.info("📝 Creating voice note file in Obsidian vault at: \(self.vaultPath)")

        // Check if vault path is set
        guard !vaultPath.isEmpty else {
            logger.error("❌ Obsidian vault path is not set")
            throw AppError.obsidian(.vaultPathMissing)
        }

        // Try to access the vault using the security-scoped bookmark
        var vaultURL: URL?
        var didStartAccessing = false

        // Resolve bookmark without using Task, which is causing compile issues
        do {
            // Use the SecurityManager to resolve the bookmark
            let result = try SecurityManager.resolveBookmark()
            vaultURL = result.url
            didStartAccessing = result.didStartAccessing
            logger.info("📍 Bookmark resolution: url=\(result.url?.path ?? "nil"), didStartAccessing=\(didStartAccessing)")
        } catch {
            logger.error("❌ Error resolving bookmark: \(error.localizedDescription)")
            // We'll continue with the file URL path as fallback
        }

        // If we couldn't access the vault with the bookmark, fall back to the path
        let baseURL = vaultURL ?? URL(fileURLWithPath: vaultPath)
        let usingFallback = vaultURL == nil
        logger.info("📂 Using baseURL: \(baseURL.path), usingFallback=\(usingFallback), didStartAccessing=\(didStartAccessing)")

        // Create the directory structure if needed
        let voiceNotesDirectory = baseURL.appendingPathComponent("Voice Notes")
        
        do {
            if !fileManager.fileExists(atPath: voiceNotesDirectory.path) {
                logger.debug("Creating Voice Notes directory at: \(voiceNotesDirectory.path)")
                try fileManager.createDirectory(at: voiceNotesDirectory, withIntermediateDirectories: true)
            }
            
            // Create the markdown file
            let sanitizedTitle = voiceNote.title.sanitizedForFilename()
            let notePath = "Voice Notes/\(sanitizedTitle).md"
            let noteURL = baseURL.appendingPathComponent(notePath)
            logger.debug("Creating markdown file at: \(noteURL.path)")
            
            // Generate the markdown content
            let markdownContent = generateMarkdownContent(for: voiceNote)
            
            // Write to file
            try markdownContent.write(to: noteURL, atomically: true, encoding: .utf8)
            logger.debug("Successfully wrote markdown content to file")
            
            // No longer updating daily note - using bidirectional links instead
            
            // Stop accessing the security-scoped resource if we started
            if didStartAccessing, let url = vaultURL {
                SecurityManager.stopAccessingSecurityScopedResource(url: url)
            }
            
            return (true, notePath)
        } catch {
            logger.error("Error creating voice note file: \(error.localizedDescription)")
            
            // Stop accessing the security-scoped resource if we started
            if didStartAccessing, let url = vaultURL {
                SecurityManager.stopAccessingSecurityScopedResource(url: url)
            }
            
            // Determine the specific error type and throw appropriate AppError
            if let nsError = error as NSError?, nsError.domain == NSCocoaErrorDomain {
                switch nsError.code {
                case NSFileWriteNoPermissionError:
                    logger.error("No permission to write to file")
                    throw AppError.obsidian(.fileCreationFailed("No permission to write to file"))
                case NSFileWriteOutOfSpaceError:
                    logger.error("Out of disk space")
                    throw AppError.obsidian(.fileCreationFailed("Out of disk space"))
                default:
                    logger.error("File system error: \(nsError.localizedDescription)")
                    throw AppError.obsidian(.fileCreationFailed(nsError.localizedDescription))
                }
            }
            
            throw AppError.obsidian(.fileCreationFailed("Unknown error"))
        }
    }
    
    /// Updates the configuration with a new vault path.
    ///
    /// This method updates the path to the Obsidian vault directory. This path is used
    /// as a fallback when security-scoped bookmarks are not available or cannot be resolved.
    ///
    /// - Parameter path: The new path to the Obsidian vault directory
    ///
    /// ## Example
    /// ```swift
    /// // Update the vault path after user selects a new directory
    /// obsidianService.updateVaultPath("/Users/username/Documents/MyObsidianVault")
    /// ```
    func updateVaultPath(_ path: String) {
        vaultPath = path
        logger.debug("Updated Obsidian vault path")
    }
    
    /// Copies the audio file to the Obsidian vault's attachments directory.
    ///
    /// This method copies an audio file from the provided URL to the Obsidian vault's
    /// "Attachments" directory. It handles:
    /// - Accessing the vault using security-scoped bookmarks
    /// - Creating the attachments directory if it doesn't exist
    /// - Checking for and handling existing files with the same name
    /// - Copying the file with proper error handling
    ///
    /// - Parameter audioURL: The URL of the audio file to copy
    /// - Returns: A boolean indicating whether the operation succeeded
    /// - Throws: `AppError.obsidian` with details about what went wrong
    ///
    /// - Important: This method requires the source audio file to exist at the provided URL.
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let success = try await obsidianService.copyAudioFileToVault(from: audioURL)
    ///     if success {
    ///         print("Audio file copied successfully")
    ///     }
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
    func copyAudioFileToVault(from audioURL: URL) async throws -> Bool {
        logger.debug("Copying audio file from \(audioURL.path) to Obsidian vault")
        
        // Check if vault path is set
        guard !vaultPath.isEmpty else {
            logger.error("Obsidian vault path is not set")
            throw AppError.obsidian(.vaultPathMissing)
        }
        
        // Check if source file exists
        guard fileManager.fileExists(atPath: audioURL.path) else {
            logger.error("Source audio file does not exist at: \(audioURL.path)")
            throw AppError.obsidian(.fileNotFound("Source audio file not found"))
        }
        
        // Try to access the vault using the security-scoped bookmark
        var vaultURL: URL?
        var didStartAccessing = false
        
        // Resolve bookmark without using Task, which is causing compile issues
        do {
            // Use the SecurityManager to resolve the bookmark
            let result = try SecurityManager.resolveBookmark()
            vaultURL = result.url
            didStartAccessing = result.didStartAccessing
        } catch {
            logger.error("Error resolving bookmark: \(error.localizedDescription)")
            // We'll continue with the file URL path as fallback
        }
        
        // If we couldn't access the vault with the bookmark, fall back to the path
        let baseURL = vaultURL ?? URL(fileURLWithPath: vaultPath)
        
        // Create the attachments directory if needed
        let attachmentsDirectory = baseURL.appendingPathComponent("Attachments")
        
        do {
            if !fileManager.fileExists(atPath: attachmentsDirectory.path) {
                logger.debug("Creating Attachments directory at: \(attachmentsDirectory.path)")
                try fileManager.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
            }
            
            // Destination path for the audio file
            let destinationURL = attachmentsDirectory.appendingPathComponent(audioURL.lastPathComponent)
            logger.debug("Destination URL for audio file: \(destinationURL.path)")
            
            // Copy the file
            if fileManager.fileExists(atPath: destinationURL.path) {
                logger.debug("Removing existing audio file at destination")
                try fileManager.removeItem(at: destinationURL)
            }
            
            // Verify source file exists
            if !fileManager.fileExists(atPath: audioURL.path) {
                logger.error("Source audio file does not exist at: \(audioURL.path)")
                
                // Stop accessing the security-scoped resource if we started
                if didStartAccessing, let url = vaultURL {
                    SecurityManager.stopAccessingSecurityScopedResource(url: url)
                }
                
                throw AppError.obsidian(.fileNotFound("Source audio file not found"))
            }
            
            try fileManager.copyItem(at: audioURL, to: destinationURL)
            logger.debug("Successfully copied audio file to: \(destinationURL.path)")
            
            // Stop accessing the security-scoped resource if we started
            if didStartAccessing, let url = vaultURL {
                SecurityManager.stopAccessingSecurityScopedResource(url: url)
            }
            
            return true
        } catch {
            logger.error("Error copying audio file: \(error.localizedDescription)")
            
            // Stop accessing the security-scoped resource if we started
            if didStartAccessing, let url = vaultURL {
                SecurityManager.stopAccessingSecurityScopedResource(url: url)
            }
            
            throw AppError.obsidian(.fileCreationFailed("Failed to copy audio file"))
        }
    }
    

    
    // MARK: - Private Helper Methods
    
    /// Formats a time interval as a string in mm:ss format.
    ///
    /// This method converts a time interval (in seconds) to a human-readable
    /// string format (minutes:seconds). It uses the centralized DateFormatUtil
    /// to ensure consistent formatting throughout the app.
    ///
    /// - Parameter duration: The duration to format (in seconds)
    /// - Returns: A formatted string (e.g., "2:35")
    private func formatDuration(_ duration: TimeInterval) -> String {
        return DateFormatUtil.shared.formatTimeShort(duration)
    }
    
    // MARK: - Private Methods
    
    /// Generates formatted markdown content for a voice note.
    ///
    /// This method creates properly formatted markdown content for the given voice note,
    /// including:
    /// - YAML frontmatter with metadata (date, duration, daily note reference)
    /// - An embedded audio player for the recording
    /// - A backlink to the daily note
    /// - The cleaned transcript with proper formatting
    ///
    /// The generated markdown follows Obsidian's conventions for embedding media,
    /// creating backlinks, and structuring content. The YAML frontmatter enables
    /// structured queries and filtering in Obsidian.
    ///
    /// - Parameter voiceNote: The voice note to generate markdown for
    /// - Returns: A string containing the formatted markdown content
    ///
    /// ## Example Output
    /// ```markdown
    /// ---
    /// date: 2023-05-15 14:30:25
    /// duration: 2:45
    /// daily: "2023-05-15"
    /// ---
    ///
    /// ![[Attachments/recording.m4a]]
    ///
    /// > Related to daily note: [[2023-05-15]]
    ///
    /// ## Transcript
    ///
    /// This is the cleaned transcript text of the voice note...
    /// ```
    private func generateMarkdownContent(for voiceNote: VoiceNote) -> String {
        // Get today's date in the format YYYY-MM-DD for linking to daily note
        let dailyNoteDate = DateFormatUtil.shared.formatTimestamp(date: Date()).prefix(10)

        // Format the creation timestamp
        let dateString = DateFormatUtil.shared.formatTimestamp(date: voiceNote.creationDate)

        // Build optional LLM fields for frontmatter
        var llmFields = ""
        if let provider = voiceNote.llmProvider {
            llmFields += "llm_provider: \(provider)\n"
        }
        if let model = voiceNote.llmModel {
            llmFields += "llm_model: \(model)\n"
        }

        // Generate markdown without repeating the title (since the filename will be the title)
        // Using Option 3: Keep the property in YAML for structured queries and add a proper backlink in the body
        let markdown = """
        ---
        date: \(dateString)
        duration: \(formatDuration(voiceNote.duration))
        \(llmFields)---

        ![[Attachments/\(voiceNote.audioFilename)]]

        > Related to daily note: [[\(dailyNoteDate)]]

        ## Transcript

        \(voiceNote.cleanedTranscript)
        """

        return markdown
    }
    
    // Daily note updating has been removed in favor of bidirectional links
}
