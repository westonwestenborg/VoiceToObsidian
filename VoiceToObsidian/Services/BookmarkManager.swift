import Foundation
import SwiftUI
import OSLog

/// A utility class for managing security-scoped bookmarks throughout the app.
///
/// `BookmarkManager` provides a centralized system for storing, retrieving, and managing
/// security-scoped bookmarks. It serves as a single source of truth for accessing and
/// modifying bookmarks, using the Keychain for secure storage.
///
/// Security-scoped bookmarks allow the app to maintain access to user-selected directories
/// across app launches, which is essential for accessing the Obsidian vault directory.
///
/// This class follows the singleton pattern to ensure consistent access to bookmarks
/// throughout the app.
///
/// ## Example Usage
/// ```swift
/// // Get the Obsidian vault bookmark
/// if let bookmarkData = BookmarkManager.shared.getObsidianVaultBookmark() {
///     // Use the bookmark data
///     let url = try? URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: nil)
/// }
///
/// // Store a new bookmark
/// if let bookmarkData = try? url.bookmarkData() {
///     BookmarkManager.shared.setObsidianVaultBookmark(bookmarkData)
/// }
///
/// // Clear the bookmark
/// BookmarkManager.shared.clearObsidianVaultBookmark()
/// ```
final class BookmarkManager {
    /// Logger for structured logging of bookmark operations.
    ///
    /// Uses OSLog for efficient and structured logging of bookmark management operations.
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "BookmarkManager")
    
    /// The shared singleton instance of the BookmarkManager.
    ///
    /// Use this property to access the BookmarkManager throughout the app.
    /// This ensures that all bookmark operations use the same instance.
    static let shared = BookmarkManager()
    
    /// Private initializer to enforce the singleton pattern.
    ///
    /// This prevents creating multiple instances of the BookmarkManager,
    /// ensuring that all bookmark operations use the same instance.
    private init() {}
    
    /// The key used for storing the Obsidian vault bookmark in the Keychain.
    ///
    /// This key identifies the Obsidian vault bookmark in the Keychain storage.
    private let obsidianVaultBookmarkKey = "ObsidianVaultBookmark"
    
    /// Retrieves the Obsidian vault bookmark from the Keychain.
    ///
    /// This method securely retrieves the bookmark data for the Obsidian vault
    /// from the Keychain. If the bookmark doesn't exist or there's an error
    /// retrieving it, the method returns nil and logs the error.
    ///
    /// - Returns: The bookmark data if available, nil otherwise
    ///
    /// ## Example
    /// ```swift
    /// if let bookmarkData = BookmarkManager.shared.getObsidianVaultBookmark() {
    ///     var isStale = false
    ///     let url = try? URL(resolvingBookmarkData: bookmarkData, options: [], 
    ///                        relativeTo: nil, bookmarkDataIsStale: &isStale)
    ///     // Use the URL
    /// }
    /// ```
    func getObsidianVaultBookmark() -> Data? {
        do {
            return try KeychainManager.getData(forKey: obsidianVaultBookmarkKey)
        } catch {
            logger.error("Failed to retrieve Obsidian vault bookmark: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Sets the Obsidian vault bookmark in the Keychain.
    ///
    /// This method securely stores the provided bookmark data for the Obsidian vault
    /// in the Keychain. It replaces any existing bookmark data with the same key.
    /// The method logs the result of the operation for debugging purposes.
    ///
    /// - Parameter data: The security-scoped bookmark data to store
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let bookmarkData = try url.bookmarkData(options: .minimalBookmark)
    ///     BookmarkManager.shared.setObsidianVaultBookmark(bookmarkData)
    /// } catch {
    ///     print("Failed to create bookmark: \(error)")
    /// }
    /// ```
    func setObsidianVaultBookmark(_ data: Data) {
        do {
            try KeychainManager.saveData(data, forKey: obsidianVaultBookmarkKey)
            logger.info("Successfully saved Obsidian vault bookmark")
        } catch {
            logger.error("Failed to save Obsidian vault bookmark: \(error.localizedDescription)")
        }
    }
    
    /// Clears the Obsidian vault bookmark from the Keychain.
    ///
    /// This method removes the bookmark data for the Obsidian vault from the Keychain.
    /// It's typically used when the user wants to reset their vault selection or when
    /// the app needs to clean up resources. The method logs the result of the operation
    /// for debugging purposes.
    ///
    /// ## Example
    /// ```swift
    /// // When user selects "Reset Vault" in settings
    /// BookmarkManager.shared.clearObsidianVaultBookmark()
    /// ```
    func clearObsidianVaultBookmark() {
        do {
            try KeychainManager.deleteData(forKey: obsidianVaultBookmarkKey)
            logger.info("Successfully cleared Obsidian vault bookmark")
        } catch {
            logger.error("Failed to clear Obsidian vault bookmark: \(error.localizedDescription)")
        }
    }
}
