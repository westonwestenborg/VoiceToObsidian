import Foundation
import Security
import OSLog

/// A utility class that manages secure storage of sensitive data using the iOS Keychain.
///
/// `KeychainManager` provides a simplified interface for storing, retrieving, updating,
/// and deleting sensitive data in the iOS Keychain. It supports both string values and
/// binary data, making it suitable for storing various types of sensitive information such as:
/// - API keys
/// - Authentication tokens
/// - Security-scoped bookmarks
/// - Encrypted data
///
/// All operations are performed using a consistent service name to organize the app's
/// keychain items and prevent conflicts with other apps.
///
/// ## Example Usage
/// ```swift
/// // Store a string value
/// do {
///     try KeychainManager.saveString("api_key_12345", forKey: "ApiKey")
/// } catch {
///     print("Failed to save API key: \(error)")
/// }
///
/// // Retrieve a string value
/// do {
///     if let apiKey = try KeychainManager.getString(forKey: "ApiKey") {
///         // Use the API key
///     }
/// } catch {
///     print("Failed to retrieve API key: \(error)")
/// }
///
/// // Store binary data
/// do {
///     try KeychainManager.saveData(bookmarkData, forKey: "VaultBookmark")
/// } catch {
///     print("Failed to save bookmark data: \(error)")
/// }
/// ```
class KeychainManager {
    
    /// Errors that can occur during Keychain operations.
    ///
    /// This enum defines specific error cases that can occur when interacting with
    /// the Keychain, providing more context than the raw OSStatus codes.
    enum KeychainError: Error {
        /// The requested item was not found in the Keychain.
        case itemNotFound
        
        /// An attempt was made to add an item that already exists.
        case duplicateItem
        
        /// An unexpected status was returned by a Keychain operation.
        /// - Parameter OSStatus: The raw status code returned by the Keychain.
        case unexpectedStatus(OSStatus)
        
        /// An error occurred when converting between data types.
        case conversionError
    }
    
    /// Service name used for all keychain items in this app.
    ///
    /// This identifier is used to group all keychain items belonging to this app.
    /// It helps organize keychain items and prevents conflicts with other apps.
    private static let serviceName = "com.voicetoobsidian.app"
    
    /// Logger for structured logging of Keychain operations.
    ///
    /// Uses OSLog for efficient and structured logging of keychain operations and errors.
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "KeychainManager")
    
    /// Saves a string value to the Keychain.
    ///
    /// This method securely stores a string value in the Keychain under the specified key.
    /// If an item with the same key already exists, it will be replaced.
    ///
    /// - Parameters:
    ///   - value: The string value to store
    ///   - key: The key to store the value under
    /// - Throws: `KeychainError` if the operation fails
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     try KeychainManager.saveString("api_key_12345", forKey: "ApiKey")
    ///     // String saved successfully
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
    static func saveString(_ value: String, forKey key: String) throws {
        // Convert string to data
        guard let valueData = value.data(using: .utf8) else {
            return
        }
        
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: valueData
        ]
        
        // First try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // Check status
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Retrieves a string value from the Keychain.
    ///
    /// This method securely retrieves a string value from the Keychain using the specified key.
    /// If the item doesn't exist, the method returns nil instead of throwing an error.
    ///
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: The stored string value, or nil if not found
    /// - Throws: `KeychainError` if the operation fails for reasons other than the item not existing
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     if let apiKey = try KeychainManager.getString(forKey: "ApiKey") {
    ///         // Use the API key
    ///     } else {
    ///         // API key not found
    ///     }
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
    static func getString(forKey key: String) throws -> String? {
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        // Query the keychain
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        // Check status
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        
        // Convert result to string
        guard let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    /// Updates a string value in the Keychain.
    ///
    /// This method updates an existing string value in the Keychain with a new value.
    /// If the item doesn't exist, it will be created.
    ///
    /// - Parameters:
    ///   - value: The new string value
    ///   - key: The key to update the value for
    /// - Throws: `KeychainError` if the operation fails
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     try KeychainManager.updateString("new_api_key_67890", forKey: "ApiKey")
    ///     // String updated successfully
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
    static func updateString(_ value: String, forKey key: String) throws {
        // Convert string to data
        guard let valueData = value.data(using: .utf8) else {
            return
        }
        
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // Create update dictionary
        let attributes: [String: Any] = [
            kSecValueData as String: valueData
        ]
        
        // Update the item
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // If item doesn't exist, try to add it
        if status == errSecItemNotFound {
            try saveString(value, forKey: key)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Deletes a string value from the Keychain.
    ///
    /// This method removes a string value from the Keychain using the specified key.
    /// If the item doesn't exist, the method completes successfully without throwing an error.
    ///
    /// - Parameter key: The key to delete the value for
    /// - Throws: `KeychainError` if the operation fails for reasons other than the item not existing
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     try KeychainManager.deleteString(forKey: "ApiKey")
    ///     // String deleted successfully or didn't exist
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
    static func deleteString(forKey key: String) throws {
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // Delete the item
        let status = SecItemDelete(query as CFDictionary)
        
        // Check status (ignore if item not found)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // MARK: - Data Methods
    
    /// Saves binary data to the Keychain.
    ///
    /// This method securely stores binary data in the Keychain under the specified key.
    /// If an item with the same key already exists, it will be replaced. This method is
    /// particularly useful for storing security-scoped bookmarks, certificates, or other
    /// binary data that needs to be secured.
    ///
    /// - Parameters:
    ///   - data: The binary data to store
    ///   - key: The key to store the data under
    /// - Throws: `KeychainError` if the operation fails
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let bookmarkData = try url.bookmarkData(options: .minimalBookmark)
    ///     try KeychainManager.saveData(bookmarkData, forKey: "VaultBookmark")
    ///     // Data saved successfully
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
    static func saveData(_ data: Data, forKey key: String) throws {
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // First try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // Check status
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Retrieves binary data from the Keychain.
    ///
    /// This method securely retrieves binary data from the Keychain using the specified key.
    /// If the item doesn't exist, the method returns nil instead of throwing an error.
    ///
    /// - Parameter key: The key to retrieve the data for
    /// - Returns: The stored binary data, or nil if not found
    /// - Throws: `KeychainError` if the operation fails for reasons other than the item not existing
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     if let bookmarkData = try KeychainManager.getData(forKey: "VaultBookmark") {
    ///         var isStale = false
    ///         let url = try URL(resolvingBookmarkData: bookmarkData, 
    ///                           options: [], 
    ///                           relativeTo: nil, 
    ///                           bookmarkDataIsStale: &isStale)
    ///         // Use the URL
    ///     } else {
    ///         // Bookmark not found
    ///     }
    /// } catch {
    ///     // Handle error
    /// }
    /// ```
    static func getData(forKey key: String) throws -> Data? {
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        // Query the keychain
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        // Check status
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        
        // Convert result to data
        guard let data = item as? Data else {
            return nil
        }
        
        return data
    }
    
    /// Updates binary data in the keychain
    /// - Parameters:
    ///   - data: The new data
    ///   - key: The key to update the data for
    /// - Throws: KeychainError if the operation fails
    static func updateData(_ data: Data, forKey key: String) throws {
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // Create update dictionary
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        // Update the item
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // If item doesn't exist, try to add it
        if status == errSecItemNotFound {
            try saveData(data, forKey: key)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Deletes binary data from the keychain
    /// - Parameter key: The key to delete the data for
    /// - Throws: KeychainError if the operation fails
    static func deleteData(forKey key: String) throws {
        // This is functionally the same as deleteString, but kept separate for API clarity
        try deleteString(forKey: key)
    }
    
    // MARK: - Utility Methods
    
    /// Clears legacy sensitive data from the keychain
    /// - Returns: A dictionary with keys that were attempted to be deleted and any errors that occurred
    /// - Note: This method is primarily for backward compatibility. New code should use property wrappers.
    @discardableResult
    static func clearAllSensitiveData() -> [String: Error] {
        // List of legacy sensitive keys that might not be handled by property wrappers
        let legacyKeys = [
            "ObsidianVaultBookmark"
        ]
        
        var errors = [String: Error]()
        
        // Attempt to delete each key
        for key in legacyKeys {
            do {
                try deleteString(forKey: key)
                Self.logger.info("Successfully cleared \(key) from keychain")
            } catch {
                Self.logger.error("Error clearing \(key) from keychain: \(error)")
                errors[key] = error
            }
        }
        
        return errors
    }
}
