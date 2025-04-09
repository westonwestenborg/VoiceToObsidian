import Foundation
import SwiftUI
import OSLog

/// A property wrapper for securely storing values in the Keychain with UserDefaults fallback.
/// This is a generic wrapper that can be used for any Codable type.
@propertyWrapper
struct SecureStorage<T: Codable> {
    private let key: String
    private let defaultValue: T
    private let useUserDefaultsFallback: Bool
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "SecureStorage")
    
    init(wrappedValue: T, key: String, useUserDefaultsFallback: Bool = true) {
        self.key = key
        self.defaultValue = wrappedValue
        self.useUserDefaultsFallback = useUserDefaultsFallback
    }
    
    var wrappedValue: T {
        get {
            // Try to retrieve from Keychain first
            do {
                if let data = try KeychainManager.getData(forKey: key) {
                    let decoder = JSONDecoder()
                    return try decoder.decode(T.self, from: data)
                }
            } catch {
                logger.error("Failed to retrieve \(key) from keychain: \(error.localizedDescription)")
            }
            
            // Fall back to UserDefaults if enabled
            if useUserDefaultsFallback {
                if let data = UserDefaults.standard.data(forKey: key) {
                    let decoder = JSONDecoder()
                    do {
                        return try decoder.decode(T.self, from: data)
                    } catch {
                        logger.error("Failed to decode \(key) from UserDefaults: \(error.localizedDescription)")
                    }
                }
            }
            
            // Return default value if not found
            return defaultValue
        }
        set {
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(newValue)
                
                // Store in Keychain
                try KeychainManager.saveData(data, forKey: key)
                
                // Also store in UserDefaults if fallback is enabled
                if useUserDefaultsFallback {
                    UserDefaults.standard.set(data, forKey: key)
                }
            } catch {
                logger.error("Failed to store \(key) in keychain: \(error.localizedDescription)")
            }
        }
    }
    
    var projectedValue: Binding<T> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}

/// A property wrapper for storing bookmark data securely in the Keychain with UserDefaults fallback.
/// This wrapper is specifically designed for security-scoped bookmarks.
@propertyWrapper
struct SecureBookmark {
    private let key: String
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "SecureBookmark")
    
    init(key: String) {
        self.key = key
    }
    
    var wrappedValue: Data? {
        get {
            // Try to get bookmark from keychain first
            do {
                if let data = try KeychainManager.getData(forKey: key) {
                    return data
                }
            } catch {
                logger.error("Error retrieving bookmark from keychain: \(error.localizedDescription)")
            }
            
            // Fall back to UserDefaults if not found in keychain
            let data = UserDefaults.standard.data(forKey: key)
            
            // If found in UserDefaults but not in keychain, save to keychain for future use
            if let data = data {
                do {
                    try KeychainManager.saveData(data, forKey: key)
                    logger.info("Migrated bookmark from UserDefaults to keychain")
                } catch {
                    logger.error("Failed to migrate bookmark to keychain: \(error.localizedDescription)")
                }
            }
            
            return data
        }
        set {
            if let newValue = newValue {
                do {
                    // Store in Keychain
                    try KeychainManager.saveData(newValue, forKey: key)
                    
                    // Also store in UserDefaults for backward compatibility
                    UserDefaults.standard.set(newValue, forKey: key)
                } catch {
                    logger.error("Failed to store bookmark in keychain: \(error.localizedDescription)")
                }
            } else {
                // Remove from both storages
                do {
                    try KeychainManager.deleteData(forKey: key)
                } catch {
                    logger.error("Failed to delete bookmark from keychain: \(error.localizedDescription)")
                }
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
