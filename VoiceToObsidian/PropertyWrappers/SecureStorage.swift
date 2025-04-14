import Foundation
import SwiftUI
import OSLog

/// A collection of property wrappers for secure data storage using the Keychain.
///
/// This file provides property wrappers that make it easy to store sensitive data
/// securely in the iOS Keychain. It includes:
/// - `SecureStorage`: For storing any `Codable` value in the Keychain
/// - `SecureBookmark`: Specifically for storing security-scoped bookmarks
///
/// These property wrappers abstract away the complexity of Keychain operations and
/// provide a simple, property-based interface for secure data storage.

// MARK: - Storage Helper

/// A helper class that handles secure storage operations for the property wrappers.
///
/// This class provides a set of static methods for reading and writing data to the Keychain,
/// with support for both raw `Data` and `Codable` types. It also creates SwiftUI `Binding`
/// objects for use with the property wrappers' projected values.
///
/// It's implemented as a class (reference type) instead of a struct to avoid 'self is immutable'
/// issues when used within property wrappers.
///
/// - Note: This is a private implementation detail of the property wrappers and not meant
///   to be used directly by client code.
private final class SecureStorageHelper {
    /// Logger for structured logging of secure storage operations.
    ///
    /// This logger uses the OSLog system for efficient and structured logging
    /// of Keychain operations and errors.
    static let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "SecureStorage")
    
    /// Reads raw data from the Keychain.
    ///
    /// This method attempts to retrieve data stored in the Keychain for the specified key.
    /// It handles any Keychain errors internally, logging them but returning nil rather than
    /// propagating exceptions to the caller.
    ///
    /// - Parameter key: The key to read from the Keychain
    /// - Returns: The data if found and successfully read, nil otherwise
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
    
    /// Writes raw data to the Keychain or deletes the entry if data is nil.
    ///
    /// This method handles both storing new data and deleting existing data from the Keychain.
    /// If the provided data is nil, it will attempt to delete any existing entry for the key.
    /// Otherwise, it will save the data to the Keychain.
    ///
    /// Any Keychain errors are logged but not propagated to the caller.
    ///
    /// - Parameters:
    ///   - data: The data to write, or nil to delete the entry
    ///   - key: The key to write to or delete from the Keychain
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
    
    /// Reads and decodes a Codable value from the Keychain.
    ///
    /// This method retrieves data from the Keychain and attempts to decode it as the specified
    /// Codable type. If the data doesn't exist or can't be decoded, it returns the provided
    /// default value instead.
    ///
    /// - Parameters:
    ///   - type: The Codable type to decode the data as
    ///   - key: The key to read from the Keychain
    ///   - defaultValue: The default value to return if the data doesn't exist or can't be decoded
    /// - Returns: The decoded value if successful, or the default value otherwise
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
    
    /// Encodes and writes a Codable value to the Keychain.
    ///
    /// This method encodes the provided Codable value as JSON data and stores it in the Keychain.
    /// Any encoding or Keychain errors are logged but not propagated to the caller.
    ///
    /// - Parameters:
    ///   - value: The Codable value to encode and store
    ///   - key: The key to write to in the Keychain
    static func writeCodable<T: Codable>(_ value: T, forKey key: String) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(value)
            writeData(data, forKey: key)
        } catch {
            logger.error("Failed to encode \(key): \(error.localizedDescription)")
        }
    }
    
    /// Creates a SwiftUI Binding for a Codable value stored in the Keychain.
    ///
    /// This method creates a SwiftUI Binding that reads from and writes to the Keychain.
    /// The Binding's getter reads and decodes the value from the Keychain, while the setter
    /// encodes and writes the value to the Keychain.
    ///
    /// This is used by property wrappers to implement their `projectedValue` property,
    /// allowing them to be used with SwiftUI's `$` prefix syntax.
    ///
    /// - Parameters:
    ///   - type: The Codable type to bind
    ///   - key: The key to bind to in the Keychain
    ///   - defaultValue: The default value to use if the value doesn't exist or can't be decoded
    /// - Returns: A SwiftUI Binding to the Keychain-stored value
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
    
    /// Creates a SwiftUI Binding for optional Data stored in the Keychain.
    ///
    /// This method creates a SwiftUI Binding that reads from and writes raw Data to the Keychain.
    /// The Binding's getter reads the data directly from the Keychain, while the setter
    /// writes the data directly to the Keychain.
    ///
    /// This is specifically used by the `SecureBookmark` property wrapper to implement its
    /// `projectedValue` property, allowing it to be used with SwiftUI's `$` prefix syntax.
    ///
    /// - Parameter key: The key to bind to in the Keychain
    /// - Returns: A SwiftUI Binding to the Keychain-stored Data
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
/// `SecureStorage` provides a convenient way to store sensitive data securely in the Keychain
/// while maintaining a simple property-based interface. It works with any type that conforms
/// to the `Codable` protocol, including Swift standard library types like `String`, `Int`,
/// and `Bool`, as well as custom types that implement `Codable`.
///
/// The property wrapper automatically handles:
/// - Reading values from the Keychain when the property is accessed
/// - Writing values to the Keychain when the property is assigned
/// - JSON encoding/decoding of Codable values
/// - Providing a SwiftUI Binding via the projected value
///
/// ## Security Considerations
/// - Data is stored in the Keychain, which provides encryption and secure storage
/// - No fallback to UserDefaults is used, ensuring sensitive data is always stored securely
/// - The Keychain persists across app reinstalls, providing data durability
///
/// ## Example Usage
/// ```swift
/// // Store a simple String
/// @SecureStorage(wrappedValue: "", key: "user_auth_token")
/// private var authToken: String
///
/// // Store a custom Codable type
/// @SecureStorage(wrappedValue: UserCredentials(), key: "user_credentials")
/// private var credentials: UserCredentials
///
/// // Use with SwiftUI
/// TextField("API Key", text: $apiKey)
/// ```
///
/// - Note: Internally, this property wrapper relies on `KeychainManager` for all
///   Keychain read/write operations.
@propertyWrapper
struct SecureStorage<T: Codable> {
    /// The key used to store the value in the Keychain.
    private let key: String
    
    /// The default value to use if no value is found in the Keychain.
    private let defaultValue: T
    
    /// Initializes the property wrapper with a default value and storage key.
    ///
    /// This initializer stores the key and default value, and also initializes
    /// the Keychain entry with the default value if it doesn't already exist.
    ///
    /// - Parameters:
    ///   - wrappedValue: The default value to use if no value is found in the Keychain
    ///   - key: The key to use for storing the value in the Keychain
    init(wrappedValue: T, key: String) {
        self.key = key
        self.defaultValue = wrappedValue
        
        // Initialize with default value if not already set
        if SecureStorageHelper.readData(forKey: key) == nil {
            SecureStorageHelper.writeCodable(wrappedValue, forKey: key)
        }
    }
    
    /// The value stored in the Keychain.
    ///
    /// When this property is accessed, it reads the value from the Keychain and decodes it.
    /// When this property is assigned, it encodes the new value and writes it to the Keychain.
    var wrappedValue: T {
        get {
            return SecureStorageHelper.readCodable(T.self, forKey: key, defaultValue: defaultValue)
        }
        set {
            SecureStorageHelper.writeCodable(newValue, forKey: key)
        }
    }
    
    /// A SwiftUI Binding to the value stored in the Keychain.
    ///
    /// This property enables the use of the `$` prefix syntax in SwiftUI views to create
    /// a binding to the securely stored value. For example:
    /// ```swift
    /// TextField("API Key", text: $apiKey)
    /// ```
    var projectedValue: Binding<T> {
        return SecureStorageHelper.createBinding(T.self, forKey: key, defaultValue: defaultValue)
    }
}

// MARK: - SecureBookmark Property Wrapper

/// A property wrapper specifically designed for storing security-scoped bookmarks in the iOS Keychain.
///
/// `SecureBookmark` provides a specialized property wrapper for working with security-scoped
/// bookmarks, which are used to maintain access to user-selected directories across app launches.
/// Security-scoped bookmarks are represented as `Data` objects and require secure storage to
/// maintain the security guarantees provided by the system.
///
/// The property wrapper automatically handles:
/// - Reading bookmark data from the Keychain when the property is accessed
/// - Writing bookmark data to the Keychain when the property is assigned
/// - Providing a SwiftUI Binding via the projected value
///
/// ## Security Considerations
/// - Bookmark data is stored in the Keychain, which provides encryption and secure storage
/// - No fallback to UserDefaults is used, ensuring bookmark data is always stored securely
/// - The Keychain persists across app reinstalls, preserving access to user-selected directories
///
/// ## Example Usage
/// ```swift
/// // Store a security-scoped bookmark
/// @SecureBookmark(key: "obsidian_vault_bookmark")
/// private var vaultBookmark: Data?
///
/// // Create a bookmark
/// func saveBookmark(for url: URL) {
///     do {
///         vaultBookmark = try url.bookmarkData(options: .securityScopeAllowOnlyReadAccess)
///     } catch {
///         print("Failed to create bookmark: \(error)")
///     }
/// }
///
/// // Use a bookmark to access a directory
/// func accessBookmarkedDirectory() {
///     guard let bookmark = vaultBookmark,
///           let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope),
///           url.startAccessingSecurityScopedResource() else {
///         return
///     }
///     
///     // Work with the directory...
///     
///     url.stopAccessingSecurityScopedResource()
/// }
/// ```
///
/// - Note: Internally, this property wrapper relies on `KeychainManager` for all
///   Keychain read/write operations.
@propertyWrapper
struct SecureBookmark {
    /// The key used to store the bookmark data in the Keychain.
    private let key: String
    
    /// Initializes the property wrapper with a storage key.
    ///
    /// - Parameter key: The key to use for storing the bookmark data in the Keychain
    init(key: String) {
        self.key = key
    }
    
    /// The bookmark data stored in the Keychain.
    ///
    /// When this property is accessed, it reads the bookmark data from the Keychain.
    /// When this property is assigned, it writes the new bookmark data to the Keychain.
    /// If nil is assigned, any existing bookmark data is deleted from the Keychain.
    var wrappedValue: Data? {
        get {
            return SecureStorageHelper.readData(forKey: key)
        }
        set {
            SecureStorageHelper.writeData(newValue, forKey: key)
        }
    }
    
    /// A SwiftUI Binding to the bookmark data stored in the Keychain.
    ///
    /// This property enables the use of the `$` prefix syntax in SwiftUI views to create
    /// a binding to the securely stored bookmark data. This is less commonly used with
    /// bookmark data than with other types, but is provided for consistency with the
    /// `SecureStorage` property wrapper.
    var projectedValue: Binding<Data?> {
        return SecureStorageHelper.createDataBinding(forKey: key)
    }
}
