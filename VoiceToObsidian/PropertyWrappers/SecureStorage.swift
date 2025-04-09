import Foundation
import SwiftUI
import OSLog

// MARK: - Storage Helper

/// A helper class to handle secure storage operations
/// Using a class (reference type) instead of a struct to avoid 'self is immutable' issues
private final class SecureStorageHelper {
    static let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "SecureStorage")
    
    /// Read data from secure storage
    /// - Parameters:
    ///   - key: The key to read
    ///   - useFallback: Whether to use UserDefaults as fallback
    /// - Returns: The data if found, nil otherwise
    static func readData(forKey key: String, useFallback: Bool = true) -> Data? {
        // Try to retrieve from Keychain first
        do {
            if let data = try KeychainManager.getData(forKey: key) {
                return data
            }
        } catch {
            logger.error("Failed to retrieve \(key) from keychain: \(error.localizedDescription)")
        }
        
        // Fall back to UserDefaults if enabled
        if useFallback {
            return UserDefaults.standard.data(forKey: key)
        }
        
        return nil
    }
    
    /// Write data to secure storage
    /// - Parameters:
    ///   - data: The data to write
    ///   - key: The key to write to
    ///   - useFallback: Whether to use UserDefaults as fallback
    static func writeData(_ data: Data?, forKey key: String, useFallback: Bool = true) {
        if let data = data {
            do {
                // Store in Keychain
                try KeychainManager.saveData(data, forKey: key)
                
                // Also store in UserDefaults if fallback is enabled
                if useFallback {
                    UserDefaults.standard.set(data, forKey: key)
                }
            } catch {
                logger.error("Failed to store \(key) in keychain: \(error.localizedDescription)")
            }
        } else {
            // Remove from both storages
            do {
                try KeychainManager.deleteData(forKey: key)
            } catch {
                logger.error("Failed to delete \(key) from keychain: \(error.localizedDescription)")
            }
            
            if useFallback {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    
    /// Read a Codable value from secure storage
    /// - Parameters:
    ///   - type: The type to decode
    ///   - key: The key to read
    ///   - defaultValue: The default value if not found
    ///   - useFallback: Whether to use UserDefaults as fallback
    /// - Returns: The decoded value or default value
    static func readCodable<T: Codable>(_ type: T.Type, forKey key: String, defaultValue: T, useFallback: Bool = true) -> T {
        guard let data = readData(forKey: key, useFallback: useFallback) else {
            return defaultValue
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch {
            logger.error("Failed to decode \(key): \(error.localizedDescription)")
            return defaultValue
        }
    }
    
    /// Write a Codable value to secure storage
    /// - Parameters:
    ///   - value: The value to encode
    ///   - key: The key to write to
    ///   - useFallback: Whether to use UserDefaults as fallback
    static func writeCodable<T: Codable>(_ value: T, forKey key: String, useFallback: Bool = true) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(value)
            writeData(data, forKey: key, useFallback: useFallback)
        } catch {
            logger.error("Failed to encode \(key): \(error.localizedDescription)")
        }
    }
    
    /// Create a binding for a Codable value
    /// - Parameters:
    ///   - type: The type to bind
    ///   - key: The key to bind to
    ///   - defaultValue: The default value if not found
    ///   - useFallback: Whether to use UserDefaults as fallback
    /// - Returns: A binding to the value
    static func createBinding<T: Codable>(_ type: T.Type, forKey key: String, defaultValue: T, useFallback: Bool = true) -> Binding<T> {
        return Binding(
            get: {
                return readCodable(type, forKey: key, defaultValue: defaultValue, useFallback: useFallback)
            },
            set: { newValue in
                writeCodable(newValue, forKey: key, useFallback: useFallback)
            }
        )
    }
    
    /// Create a binding for optional Data
    /// - Parameters:
    ///   - key: The key to bind to
    ///   - useFallback: Whether to use UserDefaults as fallback
    /// - Returns: A binding to the data
    static func createDataBinding(forKey key: String, useFallback: Bool = true) -> Binding<Data?> {
        return Binding(
            get: {
                return readData(forKey: key, useFallback: useFallback)
            },
            set: { newValue in
                writeData(newValue, forKey: key, useFallback: useFallback)
            }
        )
    }
}

// MARK: - SecureStorage Property Wrapper

/// A property wrapper for securely storing values in the Keychain with UserDefaults fallback.
/// This is a generic wrapper that can be used for any Codable type.
@propertyWrapper
struct SecureStorage<T: Codable> {
    private let key: String
    private let defaultValue: T
    private let useUserDefaultsFallback: Bool
    
    init(wrappedValue: T, key: String, useUserDefaultsFallback: Bool = true) {
        self.key = key
        self.defaultValue = wrappedValue
        self.useUserDefaultsFallback = useUserDefaultsFallback
        
        // Initialize with default value if not already set
        if SecureStorageHelper.readData(forKey: key, useFallback: useUserDefaultsFallback) == nil {
            SecureStorageHelper.writeCodable(wrappedValue, forKey: key, useFallback: useUserDefaultsFallback)
        }
    }
    
    var wrappedValue: T {
        get {
            return SecureStorageHelper.readCodable(T.self, forKey: key, defaultValue: defaultValue, useFallback: useUserDefaultsFallback)
        }
        set {
            SecureStorageHelper.writeCodable(newValue, forKey: key, useFallback: useUserDefaultsFallback)
        }
    }
    
    var projectedValue: Binding<T> {
        return SecureStorageHelper.createBinding(T.self, forKey: key, defaultValue: defaultValue, useFallback: useUserDefaultsFallback)
    }
}

// MARK: - SecureBookmark Property Wrapper

/// A property wrapper for storing bookmark data securely in the Keychain with UserDefaults fallback.
/// This wrapper is specifically designed for security-scoped bookmarks.
@propertyWrapper
struct SecureBookmark {
    private let key: String
    
    init(key: String) {
        self.key = key
    }
    
    var wrappedValue: Data? {
        get {
            return SecureStorageHelper.readData(forKey: key)
        }
        set {
            SecureStorageHelper.writeData(newValue, forKey: key)
        }
    }
    
    var projectedValue: Binding<Data?> {
        return SecureStorageHelper.createDataBinding(forKey: key)
    }
}
