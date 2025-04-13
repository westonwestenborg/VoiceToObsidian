import Foundation
import Security
import OSLog

/// Manages security-related operations in the app, focusing on security-scoped bookmarks
class SecurityManager {
    
    // MARK: - Constants
    
    /// Keys for storing data
    enum StorageKey: String {
        case obsidianVaultBookmark = "ObsidianVaultBookmark"
    }
    
    /// Logger for SecurityManager
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "SecurityManager")
    
    // Using SecureBookmark property wrapper for bookmark data
    @SecureBookmark(key: "ObsidianVaultBookmark")
    private static var obsidianVaultBookmark: Data?
    
    // MARK: - Security-Scoped Bookmark Management
    
    /// Creates and stores a security-scoped bookmark for the given URL
    /// - Parameter url: The URL to create a bookmark for
    /// - Throws: Error if bookmark creation fails
    static func createAndStoreBookmark(for url: URL) throws {
        // Create the bookmark
        let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        
        // Store using property wrapper (which handles both Keychain and UserDefaults)
        obsidianVaultBookmark = bookmarkData
        
        Self.logger.info("Successfully created and stored security-scoped bookmark")
    }
    
    /// Resolves a security-scoped bookmark and starts accessing the resource
    /// - Returns: A tuple containing the URL and a flag indicating if access was started
    /// - Throws: Error if bookmark resolution fails
    static func resolveBookmark() throws -> (url: URL?, didStartAccessing: Bool) {
        // Get bookmark data using property wrapper
        let bookmarkData = obsidianVaultBookmark
        
        guard let bookmarkData = bookmarkData else {
            Self.logger.info("No bookmark data found")
            return (nil, false)
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                Self.logger.warning("Bookmark is stale, attempting to recreate")
                // Try to recreate the bookmark if possible
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    // Create a new bookmark
                    let newBookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                    
                    // Store the new bookmark using property wrapper
                    obsidianVaultBookmark = newBookmarkData
                    
                    Self.logger.info("Successfully recreated stale bookmark")
                } else {
                    Self.logger.error("Could not access resource to recreate stale bookmark")
                    return (url, false)
                }
            }
            
            // Start accessing the resource
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            if !didStartAccessing {
                Self.logger.error("Failed to start accessing security-scoped resource")
            } else {
                Self.logger.info("Successfully started accessing security-scoped resource")
            }
            
            return (url, didStartAccessing)
        } catch {
            Self.logger.error("Error resolving bookmark: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Stops accessing a security-scoped resource
    /// - Parameter url: The URL to stop accessing
    static func stopAccessingSecurityScopedResource(url: URL) {
        url.stopAccessingSecurityScopedResource()
        Self.logger.info("Stopped accessing security-scoped resource")
    }
    
    // MARK: - Data Cleanup
    
    /// Removes all security-scoped bookmark data
    static func clearBookmarkData() {
        // Property wrapper handles the deletion
        obsidianVaultBookmark = nil
        Self.logger.info("Security-scoped bookmark data has been cleared")
    }
}
