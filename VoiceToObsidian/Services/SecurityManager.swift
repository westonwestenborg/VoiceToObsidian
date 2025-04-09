import Foundation
import Security

/// Manages security-related operations in the app, focusing on security-scoped bookmarks
class SecurityManager {
    
    // MARK: - Constants
    
    /// Keys for storing data
    enum StorageKey: String {
        case obsidianVaultBookmark = "ObsidianVaultBookmark"
    }
    
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
        
        print("Successfully created and stored security-scoped bookmark")
    }
    
    /// Resolves a security-scoped bookmark and starts accessing the resource
    /// - Returns: A tuple containing the URL and a flag indicating if access was started
    /// - Throws: Error if bookmark resolution fails
    static func resolveBookmark() throws -> (url: URL?, didStartAccessing: Bool) {
        // Get bookmark data using property wrapper
        let bookmarkData = obsidianVaultBookmark
        
        guard let bookmarkData = bookmarkData else {
            print("No bookmark data found")
            return (nil, false)
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("Bookmark is stale, attempting to recreate")
                // Try to recreate the bookmark if possible
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    // Create a new bookmark
                    let newBookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                    
                    // Store the new bookmark using property wrapper
                    obsidianVaultBookmark = newBookmarkData
                    
                    print("Successfully recreated stale bookmark")
                } else {
                    print("Could not access resource to recreate stale bookmark")
                    return (url, false)
                }
            }
            
            // Start accessing the resource
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            if !didStartAccessing {
                print("Failed to start accessing security-scoped resource")
            } else {
                print("Successfully started accessing security-scoped resource")
            }
            
            return (url, didStartAccessing)
        } catch {
            print("Error resolving bookmark: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Stops accessing a security-scoped resource
    /// - Parameter url: The URL to stop accessing
    static func stopAccessingSecurityScopedResource(url: URL) {
        url.stopAccessingSecurityScopedResource()
        print("Stopped accessing security-scoped resource")
    }
    
    // MARK: - Data Cleanup
    
    /// Removes all security-scoped bookmark data
    static func clearBookmarkData() {
        // Property wrapper handles the deletion
        obsidianVaultBookmark = nil
        print("Security-scoped bookmark data has been cleared")
    }
}
