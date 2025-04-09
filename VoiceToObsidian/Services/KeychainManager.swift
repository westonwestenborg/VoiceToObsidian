import Foundation
import Security

/// Manages secure storage of sensitive data using the iOS Keychain
class KeychainManager {
    
    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case unexpectedStatus(OSStatus)
        case conversionError
    }
    
    /// Service name used for all keychain items in this app
    private static let serviceName = "com.voicetoobsidian.app"
    
    /// Saves a string value to the keychain
    /// - Parameters:
    ///   - key: The key to store the value under
    ///   - value: The string value to store
    /// - Throws: KeychainError if the operation fails
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
    
    /// Retrieves a string value from the keychain
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: The stored string value, or nil if not found
    /// - Throws: KeychainError if the operation fails
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
    
    /// Updates a string value in the keychain
    /// - Parameters:
    ///   - key: The key to update the value for
    ///   - value: The new string value
    /// - Throws: KeychainError if the operation fails
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
    
    /// Deletes a string value from the keychain
    /// - Parameter key: The key to delete the value for
    /// - Throws: KeychainError if the operation fails
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
    
    /// Saves binary data to the keychain
    /// - Parameters:
    ///   - data: The data to store
    ///   - key: The key to store the data under
    /// - Throws: KeychainError if the operation fails
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
    
    /// Retrieves binary data from the keychain
    /// - Parameter key: The key to retrieve the data for
    /// - Returns: The stored data, or nil if not found
    /// - Throws: KeychainError if the operation fails
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
                print("Successfully cleared \(key) from keychain")
            } catch {
                print("Error clearing \(key) from keychain: \(error)")
                errors[key] = error
            }
        }
        
        return errors
    }
}
