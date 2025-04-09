import Foundation
import SwiftUI
import OSLog

/// A utility class for managing secure bookmarks throughout the app.
/// This provides a single source of truth for accessing and modifying bookmarks.
final class BookmarkManager {
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "BookmarkManager")
    
    /// The shared instance of the BookmarkManager
    static let shared = BookmarkManager()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// The key used for storing the Obsidian vault bookmark
    private let obsidianVaultBookmarkKey = "ObsidianVaultBookmark"
    
    /// Retrieves the Obsidian vault bookmark
    /// - Returns: The bookmark data if available, nil otherwise
    func getObsidianVaultBookmark() -> Data? {
        do {
            return try KeychainManager.getData(forKey: obsidianVaultBookmarkKey)
        } catch {
            logger.error("Failed to retrieve Obsidian vault bookmark: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Sets the Obsidian vault bookmark
    /// - Parameter data: The bookmark data to store
    func setObsidianVaultBookmark(_ data: Data) {
        do {
            try KeychainManager.saveData(data, forKey: obsidianVaultBookmarkKey)
            logger.info("Successfully saved Obsidian vault bookmark")
        } catch {
            logger.error("Failed to save Obsidian vault bookmark: \(error.localizedDescription)")
        }
    }
    
    /// Clears the Obsidian vault bookmark
    func clearObsidianVaultBookmark() {
        do {
            try KeychainManager.deleteData(forKey: obsidianVaultBookmarkKey)
            logger.info("Successfully cleared Obsidian vault bookmark")
        } catch {
            logger.error("Failed to clear Obsidian vault bookmark: \(error.localizedDescription)")
        }
    }
}
