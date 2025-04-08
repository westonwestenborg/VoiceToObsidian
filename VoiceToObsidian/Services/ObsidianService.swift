import Foundation
import Security
import OSLog

class ObsidianService {
    private let fileManager = FileManager.default
    
    // Path to the Obsidian vault
    private var vaultPath: String
    
    init(vaultPath: String) {
        self.vaultPath = vaultPath
    }
    
    // MARK: - Public Methods
    
    // Logger for ObsidianService
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "ObsidianService")
    
    /// Creates a new note in the Obsidian vault with the voice note content
    /// - Parameter voiceNote: The voice note to save
    /// - Returns: A tuple containing success status and path to the created note (if successful)
    /// - Throws: AppError if the operation fails
    @available(iOS 15.0, *)
    func createVoiceNoteFile(for voiceNote: VoiceNote) async throws -> (success: Bool, path: String?) {
        logger.debug("Creating voice note file in Obsidian vault at: \(self.vaultPath)")
        
        // Check if vault path is set
        guard !vaultPath.isEmpty else {
            logger.error("Obsidian vault path is not set")
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
        } catch {
            logger.error("Error resolving bookmark: \(error.localizedDescription)")
            // We'll continue with the file URL path as fallback
        }
        
        // If we couldn't access the vault with the bookmark, fall back to the path
        let baseURL = vaultURL ?? URL(fileURLWithPath: vaultPath)
        
        // Create the directory structure if needed
        let voiceNotesDirectory = baseURL.appendingPathComponent("Voice Notes")
        
        do {
            if !fileManager.fileExists(atPath: voiceNotesDirectory.path) {
                logger.debug("Creating Voice Notes directory at: \(voiceNotesDirectory.path)")
                try fileManager.createDirectory(at: voiceNotesDirectory, withIntermediateDirectories: true)
            }
            
            // Create the markdown file
            let notePath = "Voice Notes/\(voiceNote.title).md"
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
    
    /// Updates the configuration with a new vault path
    /// - Parameter path: The path to the Obsidian vault
    func updateVaultPath(_ path: String) {
        vaultPath = path
        logger.debug("Updated Obsidian vault path")
    }
    
    /// Copies the audio file to the Obsidian vault using async/await
    /// - Parameter audioURL: The URL of the audio file
    /// - Returns: A boolean indicating success
    /// - Throws: AppError if the operation fails
    @available(iOS 15.0, *)
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
    
    // MARK: - Legacy Methods (For Backward Compatibility)
    
    /// Legacy method for creating a voice note file (uses completion handler)
    /// - Parameters:
    ///   - voiceNote: The voice note to save
    ///   - completion: Completion handler with success status and path to the created note
    /// - Note: This method is deprecated. Use the async version with AsyncBridge for better memory management.
    @available(*, deprecated, message: "Use createVoiceNoteFile(for:) async throws -> (success:path:) with AsyncBridge instead")
    func createVoiceNoteFile(for voiceNote: VoiceNote, completion: @escaping (Bool, String?) -> Void) {
        if #available(iOS 15.0, *) {
            Task {
                do {
                    let result = try await createVoiceNoteFile(for: voiceNote)
                    completion(result.success, result.path)
                } catch {
                    logger.error("Error in legacy createVoiceNoteFile: \(error.localizedDescription)")
                    completion(false, nil)
                }
            }
        } else {
            // Fallback implementation for iOS < 15
            legacyCreateVoiceNoteFile(for: voiceNote, completion: completion)
        }
    }
    
    /// Legacy method for copying audio file to vault (uses completion handler)
    /// - Parameters:
    ///   - audioURL: The URL of the audio file
    ///   - completion: Completion handler with success status
    /// - Note: This method is deprecated. Use the async version with AsyncBridge for better memory management.
    @available(*, deprecated, message: "Use copyAudioFileToVault(from:) async throws -> Bool with AsyncBridge instead")
    func copyAudioFileToVault(from audioURL: URL, completion: @escaping (Bool) -> Void) {
        if #available(iOS 15.0, *) {
            Task {
                do {
                    let success = try await copyAudioFileToVault(from: audioURL)
                    completion(success)
                } catch {
                    logger.error("Error in legacy copyAudioFileToVault: \(error.localizedDescription)")
                    completion(false)
                }
            }
        } else {
            // Fallback implementation for iOS < 15
            legacyCopyAudioFileToVault(from: audioURL, completion: completion)
        }
    }
    
    // MARK: - Private Legacy Methods
    
    /// Legacy implementation of createVoiceNoteFile for iOS < 15
    private func legacyCreateVoiceNoteFile(for voiceNote: VoiceNote, completion: @escaping (Bool, String?) -> Void) {
        print("Creating voice note file in Obsidian vault at: \(vaultPath)")
        
        // Check if vault path is set
        guard !vaultPath.isEmpty else {
            print("Obsidian vault path is not set")
            completion(false, nil)
            return
        }
        
        // Try to access the vault using the security-scoped bookmark
        var vaultURL: URL?
        var didStartAccessing = false
        
        // Use autoreleasepool to help with memory management when resolving bookmarks
        autoreleasepool {
            do {
                // Use the SecurityManager to resolve the bookmark
                let result = try SecurityManager.resolveBookmark()
                vaultURL = result.url
                didStartAccessing = result.didStartAccessing
            } catch {
                print("Error resolving bookmark: \(error.localizedDescription)")
                // We'll continue with the file URL path as fallback
            }
        }
        
        // If we couldn't access the vault with the bookmark, fall back to the path
        let baseURL = vaultURL ?? URL(fileURLWithPath: vaultPath)
        
        // Create the directory structure if needed
        let voiceNotesDirectory = baseURL.appendingPathComponent("Voice Notes")
        
        do {
            if !fileManager.fileExists(atPath: voiceNotesDirectory.path) {
                print("Creating Voice Notes directory at: \(voiceNotesDirectory.path)")
                try fileManager.createDirectory(at: voiceNotesDirectory, withIntermediateDirectories: true)
            }
            
            // Create the markdown file
            let notePath = "Voice Notes/\(voiceNote.title).md"
            let noteURL = baseURL.appendingPathComponent(notePath)
            print("Creating markdown file at: \(noteURL.path)")
            
            // Generate the markdown content
            let markdownContent = generateMarkdownContent(for: voiceNote)
            
            // Write to file
            try markdownContent.write(to: noteURL, atomically: true, encoding: .utf8)
            print("Successfully wrote markdown content to file")
            
            // No longer updating daily note - using bidirectional links instead
            
            // Stop accessing the security-scoped resource if we started
            if didStartAccessing, let url = vaultURL {
                SecurityManager.stopAccessingSecurityScopedResource(url: url)
            }
            
            completion(true, notePath)
        } catch {
            print("Error creating voice note file: \(error.localizedDescription)")
            let errorMessage = error.localizedDescription
            
            // Stop accessing the security-scoped resource if we started
            if didStartAccessing, let url = vaultURL {
                SecurityManager.stopAccessingSecurityScopedResource(url: url)
            }
            
            // Determine the specific error type
            if (error as NSError).domain == NSCocoaErrorDomain {
                switch (error as NSError).code {
                case NSFileWriteNoPermissionError:
                    print("No permission to write to file")
                case NSFileWriteOutOfSpaceError:
                    print("Out of disk space")
                default:
                    print("File system error: \(errorMessage)")
                }
            }
            
            completion(false, nil)
        }
    }
    
    /// Legacy implementation of copyAudioFileToVault for iOS < 15
    private func legacyCopyAudioFileToVault(from audioURL: URL, completion: @escaping (Bool) -> Void) {
        print("Copying audio file from \(audioURL.path) to Obsidian vault")
        
        // Check if vault path is set
        guard !vaultPath.isEmpty else {
            print("Obsidian vault path is not set")
            completion(false)
            return
        }
        
        // Check if source file exists
        guard fileManager.fileExists(atPath: audioURL.path) else {
            print("Source audio file does not exist at: \(audioURL.path)")
            completion(false)
            return
        }
        
        // Try to access the vault using the security-scoped bookmark
        var vaultURL: URL?
        var didStartAccessing = false
        
        // Use autoreleasepool to help with memory management when resolving bookmarks
        autoreleasepool {
            do {
                // Use the SecurityManager to resolve the bookmark
                let result = try SecurityManager.resolveBookmark()
                vaultURL = result.url
                didStartAccessing = result.didStartAccessing
            } catch {
                print("Error resolving bookmark: \(error.localizedDescription)")
                // We'll continue with the file URL path as fallback
            }
        }
        
        // If we couldn't access the vault with the bookmark, fall back to the path
        let baseURL = vaultURL ?? URL(fileURLWithPath: vaultPath)
        
        // Create the attachments directory if needed
        let attachmentsDirectory = baseURL.appendingPathComponent("Attachments")
        
        do {
            if !fileManager.fileExists(atPath: attachmentsDirectory.path) {
                print("Creating Attachments directory at: \(attachmentsDirectory.path)")
                try fileManager.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
            }
            
            // Destination path for the audio file
            let destinationURL = attachmentsDirectory.appendingPathComponent(audioURL.lastPathComponent)
            print("Destination URL for audio file: \(destinationURL.path)")
            
            // Copy the file
            if fileManager.fileExists(atPath: destinationURL.path) {
                print("Removing existing audio file at destination")
                try fileManager.removeItem(at: destinationURL)
            }
            
            // Verify source file exists
            if !fileManager.fileExists(atPath: audioURL.path) {
                print("Source audio file does not exist at: \(audioURL.path)")
                
                // Stop accessing the security-scoped resource if we started
                if didStartAccessing, let url = vaultURL {
                    SecurityManager.stopAccessingSecurityScopedResource(url: url)
                }
                
                completion(false)
                return
            }
            
            try fileManager.copyItem(at: audioURL, to: destinationURL)
            print("Successfully copied audio file to: \(destinationURL.path)")
            
            // Stop accessing the security-scoped resource if we started
            if didStartAccessing, let url = vaultURL {
                SecurityManager.stopAccessingSecurityScopedResource(url: url)
            }
            
            completion(true)
        } catch {
            print("Error copying audio file: \(error.localizedDescription)")
            
            // Stop accessing the security-scoped resource if we started
            if didStartAccessing, let url = vaultURL {
                SecurityManager.stopAccessingSecurityScopedResource(url: url)
            }
            
            completion(false)
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Formats a time interval as a string
    /// - Parameter duration: The duration to format
    /// - Returns: A formatted string (e.g., "2:35")
    private func formatDuration(_ duration: TimeInterval) -> String {
        return DateFormatUtil.shared.formatTimeShort(duration)
    }
    
    // MARK: - Private Methods
    
    /// Generates markdown content for a voice note
    /// - Parameter voiceNote: The voice note to generate content for
    /// - Returns: Markdown content as a string
    private func generateMarkdownContent(for voiceNote: VoiceNote) -> String {
        // Get today's date in the format YYYY-MM-DD for linking to daily note
        let dailyNoteDate = DateFormatUtil.shared.formatTimestamp(date: Date()).prefix(10)
        
        // Format the creation timestamp
        let dateString = DateFormatUtil.shared.formatTimestamp(date: voiceNote.creationDate)
        
        // Generate markdown without repeating the title (since the filename will be the title)
        // Using Option 3: Keep the property in YAML for structured queries and add a proper backlink in the body
        let markdown = """
        ---
        date: \(dateString)
        duration: \(formatDuration(voiceNote.duration))
        daily: "\(dailyNoteDate)"  # Store as plain text for clean YAML
        ---
        
        ![[Attachments/\(voiceNote.audioFilename)]]
        
        > Related to daily note: [[\(dailyNoteDate)]]
        
        ## Transcript
        
        \(voiceNote.cleanedTranscript)
        """
        
        return markdown
    }
    
    // Daily note updating has been removed in favor of bidirectional links
}
