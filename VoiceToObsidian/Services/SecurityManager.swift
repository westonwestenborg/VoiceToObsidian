import Foundation
import Security

/// Manages all security-related operations in the app
class SecurityManager {
    
    // MARK: - Constants
    
    /// Keys for storing data
    enum StorageKey: String {
        case anthropicAPIKey = "AnthropicAPIKey"
        case obsidianVaultPath = "ObsidianVaultPath"
        case obsidianVaultBookmark = "ObsidianVaultBookmark"
    }
    
    // MARK: - API Key Management
    
    /// Securely stores the Anthropic API key in the keychain
    /// - Parameter apiKey: The API key to store
    /// - Throws: KeychainError if the operation fails
    static func storeAnthropicAPIKey(_ apiKey: String) throws {
        try KeychainManager.updateString(apiKey, forKey: StorageKey.anthropicAPIKey.rawValue)
        
        // Remove any legacy storage in UserDefaults for security
        UserDefaults.standard.removeObject(forKey: StorageKey.anthropicAPIKey.rawValue)
    }
    
    /// Retrieves the Anthropic API key from the keychain
    /// - Returns: The API key, or an empty string if not found
    /// - Throws: KeychainError if the operation fails
    static func retrieveAnthropicAPIKey() throws -> String {
        // Try to get from keychain first
        let apiKey = try KeychainManager.getString(forKey: StorageKey.anthropicAPIKey.rawValue) ?? ""
        
        // If empty and exists in UserDefaults, migrate it to keychain
        if apiKey.isEmpty, let legacyKey = UserDefaults.standard.string(forKey: StorageKey.anthropicAPIKey.rawValue) {
            if !legacyKey.isEmpty {
                try storeAnthropicAPIKey(legacyKey)
                return legacyKey
            }
        }
        
        return apiKey
    }
    
    // MARK: - Vault Path Management
    
    /// Securely stores the Obsidian vault path in the keychain
    /// - Parameter vaultPath: The vault path to store
    /// - Throws: KeychainError if the operation fails
    static func storeObsidianVaultPath(_ vaultPath: String) throws {
        try KeychainManager.updateString(vaultPath, forKey: StorageKey.obsidianVaultPath.rawValue)
        
        // Keep in UserDefaults for backward compatibility, but consider removing in future versions
        UserDefaults.standard.set(vaultPath, forKey: StorageKey.obsidianVaultPath.rawValue)
    }
    
    /// Retrieves the Obsidian vault path from secure storage
    /// - Returns: The vault path, or an empty string if not found
    /// - Throws: KeychainError if the operation fails
    static func retrieveObsidianVaultPath() throws -> String {
        // Try to get from keychain first
        let vaultPath = try KeychainManager.getString(forKey: StorageKey.obsidianVaultPath.rawValue) ?? ""
        
        // If empty, fall back to UserDefaults for backward compatibility
        if vaultPath.isEmpty {
            return UserDefaults.standard.string(forKey: StorageKey.obsidianVaultPath.rawValue) ?? ""
        }
        
        return vaultPath
    }
    
    // MARK: - Security-Scoped Bookmark Management
    
    /// Creates and stores a security-scoped bookmark for the given URL
    /// - Parameter url: The URL to create a bookmark for
    /// - Throws: Error if bookmark creation fails
    static func createAndStoreBookmark(for url: URL) throws {
        // Create the bookmark
        let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        
        // Store in keychain
        try KeychainManager.saveData(bookmarkData, forKey: StorageKey.obsidianVaultBookmark.rawValue)
        
        // Also store in UserDefaults for backward compatibility
        UserDefaults.standard.set(bookmarkData, forKey: StorageKey.obsidianVaultBookmark.rawValue)
        
        print("Successfully created and stored security-scoped bookmark")
    }
    
    /// Resolves a security-scoped bookmark and starts accessing the resource
    /// - Returns: A tuple containing the URL and a flag indicating if access was started
    /// - Throws: Error if bookmark resolution fails
    static func resolveBookmark() throws -> (url: URL?, didStartAccessing: Bool) {
        var bookmarkData: Data? = nil
        
        // Try to get bookmark from keychain first
        do {
            bookmarkData = try KeychainManager.getData(forKey: StorageKey.obsidianVaultBookmark.rawValue)
        } catch {
            print("Error retrieving bookmark from keychain: \(error.localizedDescription)")
            // Fall back to UserDefaults
        }
        
        // Fall back to UserDefaults if not found in keychain
        if bookmarkData == nil {
            bookmarkData = UserDefaults.standard.data(forKey: StorageKey.obsidianVaultBookmark.rawValue)
            
            // If found in UserDefaults but not in keychain, save to keychain for future use
            if let data = bookmarkData {
                do {
                    try KeychainManager.saveData(data, forKey: StorageKey.obsidianVaultBookmark.rawValue)
                    print("Migrated bookmark from UserDefaults to keychain")
                } catch {
                    print("Failed to migrate bookmark to keychain: \(error)")
                    // Continue anyway since we have the bookmark data
                }
            }
        }
        
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
                    
                    // Store the new bookmark
                    try KeychainManager.saveData(newBookmarkData, forKey: StorageKey.obsidianVaultBookmark.rawValue)
                    UserDefaults.standard.set(newBookmarkData, forKey: StorageKey.obsidianVaultBookmark.rawValue)
                    
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
    
    /// Removes all sensitive data from the app
    /// - Throws: Error if any operation fails
    static func clearAllSensitiveData() throws {
        // Remove API key
        try KeychainManager.deleteString(forKey: StorageKey.anthropicAPIKey.rawValue)
        UserDefaults.standard.removeObject(forKey: StorageKey.anthropicAPIKey.rawValue)
        
        // Remove vault path
        try KeychainManager.deleteString(forKey: StorageKey.obsidianVaultPath.rawValue)
        UserDefaults.standard.removeObject(forKey: StorageKey.obsidianVaultPath.rawValue)
        
        // Remove bookmark
        try KeychainManager.deleteData(forKey: StorageKey.obsidianVaultBookmark.rawValue)
        UserDefaults.standard.removeObject(forKey: StorageKey.obsidianVaultBookmark.rawValue)
        
        print("All sensitive data has been cleared")
    }
}
