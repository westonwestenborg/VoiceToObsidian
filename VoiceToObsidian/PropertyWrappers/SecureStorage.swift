import Foundation
import SwiftUI

/// A property wrapper for securely storing values in the Keychain with UserDefaults fallback
@propertyWrapper
struct SecureStorage<T: Codable> {
    private let key: String
    private let defaultValue: T
    private let useUserDefaultsFallback: Bool
    
    init(key: String, defaultValue: T, useUserDefaultsFallback: Bool = true) {
        self.key = key
        self.defaultValue = defaultValue
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
                print("Failed to retrieve \(key) from keychain: \(error)")
            }
            
            // Fall back to UserDefaults if enabled
            if useUserDefaultsFallback {
                if let data = UserDefaults.standard.data(forKey: key) {
                    let decoder = JSONDecoder()
                    do {
                        return try decoder.decode(T.self, from: data)
                    } catch {
                        print("Failed to decode \(key) from UserDefaults: \(error)")
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
                print("Failed to store \(key) in keychain: \(error)")
            }
        }
    }
}

/// A property wrapper for securely storing strings in the Keychain with UserDefaults fallback
@propertyWrapper
struct SecureString {
    private let key: String
    private let defaultValue: String
    private let useUserDefaultsFallback: Bool
    
    init(key: String, defaultValue: String = "", useUserDefaultsFallback: Bool = true) {
        self.key = key
        self.defaultValue = defaultValue
        self.useUserDefaultsFallback = useUserDefaultsFallback
    }
    
    var wrappedValue: String {
        get {
            // Try to retrieve from Keychain first
            do {
                if let value = try KeychainManager.getString(forKey: key) {
                    return value
                }
            } catch {
                print("Failed to retrieve \(key) from keychain: \(error)")
            }
            
            // Fall back to UserDefaults if enabled
            if useUserDefaultsFallback {
                if let value = UserDefaults.standard.string(forKey: key) {
                    // Migrate to Keychain for future use
                    do {
                        try KeychainManager.saveString(value, forKey: key)
                    } catch {
                        print("Failed to migrate \(key) to keychain: \(error)")
                    }
                    return value
                }
            }
            
            // Return default value if not found
            return defaultValue
        }
        set {
            do {
                // Store in Keychain
                try KeychainManager.updateString(newValue, forKey: key)
                
                // Also store in UserDefaults if fallback is enabled
                if useUserDefaultsFallback {
                    UserDefaults.standard.set(newValue, forKey: key)
                }
            } catch {
                print("Failed to store \(key) in keychain: \(error)")
            }
        }
    }
}

/// A property wrapper for storing bookmark data securely
@propertyWrapper
struct SecureBookmark {
    private let key: String
    
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
                print("Error retrieving bookmark from keychain: \(error)")
            }
            
            // Fall back to UserDefaults if not found in keychain
            let data = UserDefaults.standard.data(forKey: key)
            
            // If found in UserDefaults but not in keychain, save to keychain for future use
            if let data = data {
                do {
                    try KeychainManager.saveData(data, forKey: key)
                    print("Migrated bookmark from UserDefaults to keychain")
                } catch {
                    print("Failed to migrate bookmark to keychain: \(error)")
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
                    print("Failed to store bookmark in keychain: \(error)")
                }
            } else {
                // Remove from both storages
                do {
                    try KeychainManager.deleteData(forKey: key)
                } catch {
                    print("Failed to delete bookmark from keychain: \(error)")
                }
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}

/// A property wrapper for AppStorage with a projected value for binding
@propertyWrapper
struct AppPreference<T> {
    @AppStorage private var storage: T
    
    init(wrappedValue: T, _ key: String, store: UserDefaults? = nil) where T: RawRepresentable, T.RawValue == String {
        self._storage = AppStorage(wrappedValue: wrappedValue, key)
    }
    
    init(wrappedValue: T, _ key: String, store: UserDefaults? = nil) where T: RawRepresentable, T.RawValue == Int {
        self._storage = AppStorage(wrappedValue: wrappedValue, key)
    }
    
    init(wrappedValue: T, _ key: String, store: UserDefaults? = nil) where T == Bool {
        self._storage = AppStorage(wrappedValue: wrappedValue, key)
    }
    
    init(wrappedValue: T, _ key: String, store: UserDefaults? = nil) where T == Int {
        self._storage = AppStorage(wrappedValue: wrappedValue, key)
    }
    
    init(wrappedValue: T, _ key: String, store: UserDefaults? = nil) where T == Double {
        self._storage = AppStorage(wrappedValue: wrappedValue, key)
    }
    
    init(wrappedValue: T, _ key: String, store: UserDefaults? = nil) where T == String {
        self._storage = AppStorage(wrappedValue: wrappedValue, key)
    }
    
    init(wrappedValue: T, _ key: String, store: UserDefaults? = nil) where T == URL {
        self._storage = AppStorage(wrappedValue: wrappedValue, key)
    }
    
    init(wrappedValue: T, _ key: String, store: UserDefaults? = nil) where T == Data {
        self._storage = AppStorage(wrappedValue: wrappedValue, key)
    }
    
    var wrappedValue: T {
        get { storage }
        set { storage = newValue }
    }
    
    var projectedValue: Binding<T> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}
