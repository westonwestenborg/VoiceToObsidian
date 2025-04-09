import Foundation
import SwiftUI
import OSLog

// MARK: - Preferences Helper

/// A helper class to handle preferences storage operations
/// Using a class (reference type) instead of a struct to avoid 'self is immutable' issues
private final class PreferencesHelper {
    static let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "AppPreference")
    
    /// Read a value from UserDefaults
    /// - Parameters:
    ///   - key: The key to read
    ///   - defaultValue: The default value if not found
    ///   - store: The UserDefaults store to use
    /// - Returns: The value or default value
    static func readValue<T>(_ key: String, defaultValue: T, store: UserDefaults = .standard) -> T {
        if let value = store.object(forKey: key) as? T {
            return value
        }
        return defaultValue
    }
    
    /// Write a value to UserDefaults
    /// - Parameters:
    ///   - value: The value to write
    ///   - key: The key to write to
    ///   - store: The UserDefaults store to use
    static func writeValue<T>(_ value: T, forKey key: String, store: UserDefaults = .standard) {
        store.set(value, forKey: key)
    }
    
    /// Create a binding for a value
    /// - Parameters:
    ///   - key: The key to bind to
    ///   - defaultValue: The default value if not found
    ///   - store: The UserDefaults store to use
    /// - Returns: A binding to the value
    static func createBinding<T>(_ key: String, defaultValue: T, store: UserDefaults = .standard) -> Binding<T> {
        return Binding(
            get: {
                return readValue(key, defaultValue: defaultValue, store: store)
            },
            set: { newValue in
                writeValue(newValue, forKey: key, store: store)
            }
        )
    }
}

// MARK: - AppPreference Property Wrapper

/// A property wrapper for storing non-sensitive data in UserDefaults.
///
/// Usage:
/// ```swift
/// @AppPreference(wrappedValue: false, "show_welcome_screen")
/// private var showWelcomeScreen: Bool
/// ```
/// This will automatically load and store values in UserDefaults.
/// For sensitive data, use @SecureStorage instead.
@propertyWrapper
struct AppPreference<T> {
    private let key: String
    private let defaultValue: T
    private let store: UserDefaults
    
    init(wrappedValue: T, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.store = store
        
        // Initialize the value in UserDefaults if it doesn't exist
        if store.object(forKey: key) == nil {
            PreferencesHelper.writeValue(wrappedValue, forKey: key, store: store)
        }
    }
    
    var wrappedValue: T {
        get {
            return PreferencesHelper.readValue(key, defaultValue: defaultValue, store: store)
        }
        set {
            PreferencesHelper.writeValue(newValue, forKey: key, store: store)
        }
    }
    
    var projectedValue: Binding<T> {
        return PreferencesHelper.createBinding(key, defaultValue: defaultValue, store: store)
    }
}
