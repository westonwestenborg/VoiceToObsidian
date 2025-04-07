import Foundation
import Security

class ObsidianService {
    private let fileManager = FileManager.default
    
    // Path to the Obsidian vault
    private var vaultPath: String
    
    init(vaultPath: String) {
        self.vaultPath = vaultPath
    }
    
    // MARK: - Public Methods
    
    /// Creates a new note in the Obsidian vault with the voice note content
    /// - Parameters:
    ///   - voiceNote: The voice note to save
    ///   - completion: Completion handler with success status and path to the created note
    func createVoiceNoteFile(for voiceNote: VoiceNote, completion: @escaping (Bool, String?) -> Void) {
        print("Creating voice note file in Obsidian vault at: \(vaultPath)")
        
        // Try to access the vault using the security-scoped bookmark
        var vaultURL: URL?
        var didStartAccessing = false
        
        // Use autoreleasepool to help with memory management when resolving bookmarks
        autoreleasepool {
            // First try to get bookmark from keychain
            var bookmarkData: Data? = nil
            do {
                bookmarkData = try KeychainManager.getData(forKey: "ObsidianVaultBookmark")
            } catch {
                print("Error retrieving bookmark from keychain: \(error.localizedDescription)")
            }
            
            // Fall back to UserDefaults if not found in keychain
            if bookmarkData == nil {
                bookmarkData = UserDefaults.standard.data(forKey: "ObsidianVaultBookmark")
                
                // If found in UserDefaults but not in keychain, save to keychain for future use
                if let data = bookmarkData {
                    do {
                        try KeychainManager.saveData(data, forKey: "ObsidianVaultBookmark")
                        print("Migrated bookmark from UserDefaults to keychain")
                    } catch {
                        print("Failed to migrate bookmark to keychain: \(error)")
                    }
                }
            }
            
            if let bookmarkData = bookmarkData {
                do {
                    var isStale = false
                    vaultURL = try URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale)
                    
                    if !isStale {
                        didStartAccessing = vaultURL?.startAccessingSecurityScopedResource() ?? false
                        print("Started accessing security-scoped resource: \(didStartAccessing)")
                    } else {
                        print("Bookmark is stale, need to recreate")
                    }
                } catch {
                    print("Error resolving bookmark: \(error.localizedDescription)")
                }
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
                url.stopAccessingSecurityScopedResource()
                print("Stopped accessing security-scoped resource")
            }
            
            completion(true, notePath)
        } catch {
            print("Error creating voice note file: \(error.localizedDescription)")
            
            // Stop accessing the security-scoped resource if we started
            if didStartAccessing, let url = vaultURL {
                url.stopAccessingSecurityScopedResource()
                print("Stopped accessing security-scoped resource")
            }
            
            completion(false, nil)
        }
    }
    
    /// Updates the configuration with a new vault path
    /// - Parameter path: The path to the Obsidian vault
    func updateVaultPath(_ path: String) {
        vaultPath = path
    }
    
    /// Copies the audio file to the Obsidian vault
    /// - Parameters:
    ///   - audioURL: The URL of the audio file
    ///   - completion: Completion handler with success status
    func copyAudioFileToVault(from audioURL: URL, completion: @escaping (Bool) -> Void) {
        print("Copying audio file from \(audioURL.path) to Obsidian vault")
        
        // Try to access the vault using the security-scoped bookmark
        var vaultURL: URL?
        var didStartAccessing = false
        
        // Use autoreleasepool to help with memory management when resolving bookmarks
        autoreleasepool {
            // First try to get bookmark from keychain
            var bookmarkData: Data? = nil
            do {
                bookmarkData = try KeychainManager.getData(forKey: "ObsidianVaultBookmark")
            } catch {
                print("Error retrieving bookmark from keychain: \(error.localizedDescription)")
            }
            
            // Fall back to UserDefaults if not found in keychain
            if bookmarkData == nil {
                bookmarkData = UserDefaults.standard.data(forKey: "ObsidianVaultBookmark")
                
                // If found in UserDefaults but not in keychain, save to keychain for future use
                if let data = bookmarkData {
                    do {
                        try KeychainManager.saveData(data, forKey: "ObsidianVaultBookmark")
                        print("Migrated bookmark from UserDefaults to keychain")
                    } catch {
                        print("Failed to migrate bookmark to keychain: \(error)")
                    }
                }
            }
            
            if let bookmarkData = bookmarkData {
                do {
                    var isStale = false
                    vaultURL = try URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale)
                    
                    if !isStale {
                        didStartAccessing = vaultURL?.startAccessingSecurityScopedResource() ?? false
                        print("Started accessing security-scoped resource: \(didStartAccessing)")
                    } else {
                        print("Bookmark is stale, need to recreate")
                    }
                } catch {
                    print("Error resolving bookmark: \(error.localizedDescription)")
                }
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
                    url.stopAccessingSecurityScopedResource()
                    print("Stopped accessing security-scoped resource")
                }
                
                completion(false)
                return
            }
            
            try fileManager.copyItem(at: audioURL, to: destinationURL)
            print("Successfully copied audio file to: \(destinationURL.path)")
            
            // Stop accessing the security-scoped resource if we started
            if didStartAccessing, let url = vaultURL {
                url.stopAccessingSecurityScopedResource()
                print("Stopped accessing security-scoped resource")
            }
            
            completion(true)
        } catch {
            print("Error copying audio file: \(error.localizedDescription)")
            
            // Stop accessing the security-scoped resource if we started
            if didStartAccessing, let url = vaultURL {
                url.stopAccessingSecurityScopedResource()
                print("Stopped accessing security-scoped resource")
            }
            
            completion(false)
        }
    }
    
    /// Formats a time interval as a string
    /// - Parameter duration: The duration to format
    /// - Returns: A formatted string (e.g., "2:35")
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Private Methods
    
    /// Generates markdown content for a voice note
    /// - Parameter voiceNote: The voice note to generate content for
    /// - Returns: Markdown content as a string
    private func generateMarkdownContent(for voiceNote: VoiceNote) -> String {
        // Get today's date in the format YYYY-MM-DD for linking to daily note
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dailyNoteDate = dateFormatter.string(from: Date())
        
        // Format the creation timestamp
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = dateFormatter.string(from: voiceNote.creationDate)
        
        // Generate markdown without repeating the title (since the filename will be the title)
        let markdown = """
        ---
        date: \(dateString)
        duration: \(formatDuration(voiceNote.duration))
        daily: [[\(dailyNoteDate)]]
        ---
        
        ![[Attachments/\(voiceNote.audioFilename)]]
        
        ## Transcript
        
        \(voiceNote.cleanedTranscript)
        """
        
        return markdown
    }
    
    // Daily note updating has been removed in favor of bidirectional links
}
