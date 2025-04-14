import Foundation
import Security
import OSLog

/// Manages security-related operations in the app, with a focus on security-scoped bookmarks.
///
/// `SecurityManager` provides functionality for creating, storing, and resolving security-scoped
/// bookmarks, which allow the app to maintain access to user-selected directories across app launches.
/// This is particularly important for accessing the Obsidian vault directory.
///
/// Security-scoped bookmarks are a macOS/iOS security feature that allows apps to maintain
/// access to files and directories that the user has explicitly granted permission to access,
/// even after the app is restarted.
///
/// This class uses the `SecureBookmark` property wrapper to securely store bookmark data
/// in both the Keychain and UserDefaults.
///
/// ## Example Usage
/// ```swift
/// // Create and store a bookmark for a user-selected directory
/// do {
///     try SecurityManager.createAndStoreBookmark(for: directoryURL)
/// } catch {
///     print("Failed to create bookmark: \(error)")
/// }
///
/// // Later, resolve the bookmark to access the directory
/// do {
///     let (url, didStartAccessing) = try SecurityManager.resolveBookmark()
///     if let url = url, didStartAccessing {
///         // Use the URL to access the directory
///         // ...
///         // When done, stop accessing
///         SecurityManager.stopAccessingSecurityScopedResource(url: url)
///     }
/// } catch {
///     print("Failed to resolve bookmark: \(error)")
/// }
/// ```
class SecurityManager {
    
    // MARK: - Constants
    
    /// Keys used for storing security-related data.
    ///
    /// These keys are used to identify different types of security data in storage systems
    /// like UserDefaults and Keychain.
    enum StorageKey: String {
        /// Key for storing the Obsidian vault directory bookmark.
        case obsidianVaultBookmark = "ObsidianVaultBookmark"
    }
    
    /// Logger for structured logging of security operations.
    ///
    /// Uses OSLog for efficient and structured logging of security-related operations.
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "SecurityManager")
    
    /// Securely stored bookmark data for the Obsidian vault directory.
    ///
    /// This property uses the `SecureBookmark` property wrapper to store the bookmark data
    /// securely in both the Keychain (for security) and UserDefaults (for quick access).
    /// The property wrapper handles the complexity of secure storage.
    @SecureBookmark(key: "ObsidianVaultBookmark")
    private static var obsidianVaultBookmark: Data?
    
    // MARK: - Security-Scoped Bookmark Management
    
    /// Creates and stores a security-scoped bookmark for the given URL.
    ///
    /// This method creates a security-scoped bookmark for a user-selected directory
    /// (typically the Obsidian vault) and stores it securely using the `SecureBookmark`
    /// property wrapper. The bookmark allows the app to maintain access to this
    /// directory across app launches.
    ///
    /// - Parameter url: The URL to create a bookmark for, typically a directory URL
    /// - Throws: Error if bookmark creation fails, which can happen if the URL is invalid
    ///           or if the app doesn't have permission to access the URL
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     try SecurityManager.createAndStoreBookmark(for: directoryURL)
    ///     // Bookmark created and stored successfully
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
    static func createAndStoreBookmark(for url: URL) throws {
        // Create the bookmark
        let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        
        // Store using property wrapper (which handles both Keychain and UserDefaults)
        obsidianVaultBookmark = bookmarkData
        
        Self.logger.info("Successfully created and stored security-scoped bookmark")
    }
    
    /// Resolves a security-scoped bookmark and starts accessing the resource.
    ///
    /// This method retrieves the stored security-scoped bookmark, resolves it to get a URL,
    /// and starts accessing the security-scoped resource. It also handles stale bookmarks
    /// by attempting to recreate them if possible.
    ///
    /// - Returns: A tuple containing:
    ///   - `url`: The resolved URL, or nil if no bookmark data was found
    ///   - `didStartAccessing`: A boolean indicating if access was successfully started
    /// - Throws: Error if bookmark resolution fails
    ///
    /// - Important: If this method returns a non-nil URL and `didStartAccessing` is true,
    ///              you must call `stopAccessingSecurityScopedResource(url:)` when done
    ///              accessing the resource.
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let (url, didStartAccessing) = try SecurityManager.resolveBookmark()
    ///     guard let url = url, didStartAccessing else {
    ///         // Handle case where bookmark couldn't be resolved or accessed
    ///         return
    ///     }
    ///     
    ///     // Use the URL to access the resource
    ///     // ...
    ///     
    ///     // When done, stop accessing the resource
    ///     SecurityManager.stopAccessingSecurityScopedResource(url: url)
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
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
    
    /// Stops accessing a security-scoped resource.
    ///
    /// This method should be called after you're done accessing a security-scoped resource
    /// that was started with `resolveBookmark()`. It releases the access claim on the resource.
    ///
    /// - Parameter url: The URL to stop accessing, as returned by `resolveBookmark()`
    ///
    /// - Important: Always call this method in a `defer` block or when you're done accessing
    ///              the security-scoped resource to avoid resource leaks.
    ///
    /// ## Example
    /// ```swift
    /// if let (url, didStartAccessing) = try? SecurityManager.resolveBookmark(),
    ///    let url = url, didStartAccessing {
    ///     defer {
    ///         SecurityManager.stopAccessingSecurityScopedResource(url: url)
    ///     }
    ///     
    ///     // Use the URL to access the resource
    /// }
    /// ```
    static func stopAccessingSecurityScopedResource(url: URL) {
        url.stopAccessingSecurityScopedResource()
        Self.logger.info("Stopped accessing security-scoped resource")
    }
    
    // MARK: - Data Cleanup
    
    /// Removes all security-scoped bookmark data.
    ///
    /// This method clears all stored security-scoped bookmark data, effectively
    /// removing the app's saved access to previously bookmarked directories.
    /// This might be used during logout, reset, or when the user wants to revoke
    /// previously granted permissions.
    ///
    /// - Note: After calling this method, the app will need to request access to
    ///         directories again and create new bookmarks.
    ///
    /// ## Example
    /// ```swift
    /// // When user logs out or resets app permissions
    /// SecurityManager.clearBookmarkData()
    /// ```
    static func clearBookmarkData() {
        // Property wrapper handles the deletion
        obsidianVaultBookmark = nil
        Self.logger.info("Security-scoped bookmark data has been cleared")
    }
}
