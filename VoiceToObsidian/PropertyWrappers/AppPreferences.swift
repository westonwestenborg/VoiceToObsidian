import Foundation
import SwiftUI
import OSLog

/// A property wrapper for app preferences that provides a consistent interface
/// for storing and retrieving user preferences with SwiftUI integration.
/// This is a generic wrapper that can be used for any type supported by UserDefaults
/// and SwiftUI's AppStorage.
@propertyWrapper
struct AppPreference<T> {
    private let key: String
    private let defaultValue: T
    private let store: UserDefaults
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "AppPreference")
    
    @available(iOS 14.0, *)
    private var appStorage: AppStorage<T>? = nil
    
    init(wrappedValue: T, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.store = store
        
        if #available(iOS 14.0, *) {
            self._appStorage = AppStorage(wrappedValue: wrappedValue, key, store: store)
        }
    }
    
    var wrappedValue: T {
        get {
            if #available(iOS 14.0, *) {
                return appStorage?.wrappedValue ?? defaultValue
            } else {
                // Fall back to UserDefaults for iOS 13
                if let value = store.object(forKey: key) as? T {
                    return value
                }
                return defaultValue
            }
        }
        set {
            if #available(iOS 14.0, *) {
                appStorage?.wrappedValue = newValue
            } else {
                // Fall back to UserDefaults for iOS 13
                store.set(newValue, forKey: key)
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
