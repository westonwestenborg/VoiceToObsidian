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
    /// - Returns: The data if found, nil otherwise
    static func readData(forKey key: String) -> Data? {
        do {
            if let data = try KeychainManager.getData(forKey: key) {
                return data
            }
        } catch {
            logger.error("Failed to retrieve \(key) from keychain: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Write data to secure storage
    /// - Parameters:
    ///   - data: The data to write
    ///   - key: The key to write to
    static func writeData(_ data: Data?, forKey key: String) {
        if let data = data {
            do {
                try KeychainManager.saveData(data, forKey: key)
            } catch {
                logger.error("Failed to store \(key) in keychain: \(error.localizedDescription)")
            }
        } else {
            do {
                try KeychainManager.deleteData(forKey: key)
            } catch {
                logger.error("Failed to delete \(key) from keychain: \(error.localizedDescription)")
            }
        }
    }
    
    /// Read a Codable value from secure storage
    /// - Parameters:
    ///   - type: The type to decode
    ///   - key: The key to read
    ///   - defaultValue: The default value if not found
    /// - Returns: The decoded value or default value
    static func readCodable<T: Codable>(_ type: T.Type, forKey key: String, defaultValue: T) -> T {
        guard let data = readData(forKey: key) else {
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
    static func writeCodable<T: Codable>(_ value: T, forKey key: String) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(value)
            writeData(data, forKey: key)
        } catch {
            logger.error("Failed to encode \(key): \(error.localizedDescription)")
        }
    }
    
    /// Create a binding for a Codable value
    /// - Parameters:
    ///   - type: The type to bind
    ///   - key: The key to bind to
    ///   - defaultValue: The default value if not found
    /// - Returns: A binding to the value
    static func createBinding<T: Codable>(_ type: T.Type, forKey key: String, defaultValue: T) -> Binding<T> {
        return Binding(
            get: {
                return readCodable(type, forKey: key, defaultValue: defaultValue)
            },
            set: { newValue in
                writeCodable(newValue, forKey: key)
            }
        )
    }
    
    /// Create a binding for optional Data
    /// - Parameters:
    ///   - key: The key to bind to
    /// - Returns: A binding to the data
    static func createDataBinding(forKey key: String) -> Binding<Data?> {
        return Binding(
            get: {
                return readData(forKey: key)
            },
            set: { newValue in
                writeData(newValue, forKey: key)
            }
        )
    }
}

// MARK: - SecureStorage Property Wrapper

/// A property wrapper that securely stores Codable data in the iOS Keychain.
///
/// Usage:
/// ```swift
/// @SecureStorage(wrappedValue: "", key: "user_auth_token")
/// private var authToken: String
/// ```
/// This will automatically load `authToken` from the Keychain or store it when changed.
/// Internally, it relies on `KeychainManager` for all read/write operations.
/// Note: No fallback to `UserDefaults` is used.
@propertyWrapper
struct SecureStorage<T: Codable> {
    private let key: String
    private let defaultValue: T
    
    init(wrappedValue: T, key: String) {
        self.key = key
        self.defaultValue = wrappedValue
        
        // Initialize with default value if not already set
        if SecureStorageHelper.readData(forKey: key) == nil {
            SecureStorageHelper.writeCodable(wrappedValue, forKey: key)
        }
    }
    
    var wrappedValue: T {
        get {
            return SecureStorageHelper.readCodable(T.self, forKey: key, defaultValue: defaultValue)
        }
        set {
            SecureStorageHelper.writeCodable(newValue, forKey: key)
        }
    }
    
    var projectedValue: Binding<T> {
        return SecureStorageHelper.createBinding(T.self, forKey: key, defaultValue: defaultValue)
    }
}

// MARK: - SecureBookmark Property Wrapper

/// A property wrapper for storing security-scoped bookmarks in the iOS Keychain.
///
/// Usage:
/// ```swift
/// @SecureBookmark(key: "obsidian_vault_bookmark")
/// private var vaultBookmark: Data?
/// ```
/// This will automatically load and store folder bookmarks in the Keychain.
/// No fallback to UserDefaults is used.
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
