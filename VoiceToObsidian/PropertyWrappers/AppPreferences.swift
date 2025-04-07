import Foundation
import SwiftUI
import OSLog

/// A property wrapper for app preferences that provides a consistent interface
/// for storing and retrieving user preferences with SwiftUI integration
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

/// A property wrapper specifically for boolean preferences
@propertyWrapper
struct BoolPreference {
    private let key: String
    private let defaultValue: Bool
    private let store: UserDefaults
    
    @available(iOS 14.0, *)
    private var appStorage: AppStorage<Bool>? = nil
    
    init(wrappedValue: Bool, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.store = store
        
        if #available(iOS 14.0, *) {
            self._appStorage = AppStorage(wrappedValue: wrappedValue, key, store: store)
        }
    }
    
    var wrappedValue: Bool {
        get {
            if #available(iOS 14.0, *) {
                return appStorage?.wrappedValue ?? defaultValue
            } else {
                return store.bool(forKey: key)
            }
        }
        set {
            if #available(iOS 14.0, *) {
                appStorage?.wrappedValue = newValue
            } else {
                store.set(newValue, forKey: key)
            }
        }
    }
    
    var projectedValue: Binding<Bool> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}

/// A property wrapper specifically for integer preferences
@propertyWrapper
struct IntPreference {
    private let key: String
    private let defaultValue: Int
    private let store: UserDefaults
    
    @available(iOS 14.0, *)
    private var appStorage: AppStorage<Int>? = nil
    
    init(wrappedValue: Int, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.store = store
        
        if #available(iOS 14.0, *) {
            self._appStorage = AppStorage(wrappedValue: wrappedValue, key, store: store)
        }
    }
    
    var wrappedValue: Int {
        get {
            if #available(iOS 14.0, *) {
                return appStorage?.wrappedValue ?? defaultValue
            } else {
                return store.integer(forKey: key)
            }
        }
        set {
            if #available(iOS 14.0, *) {
                appStorage?.wrappedValue = newValue
            } else {
                store.set(newValue, forKey: key)
            }
        }
    }
    
    var projectedValue: Binding<Int> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}

/// A property wrapper specifically for string preferences
@propertyWrapper
struct StringPreference {
    private let key: String
    private let defaultValue: String
    private let store: UserDefaults
    
    @available(iOS 14.0, *)
    private var appStorage: AppStorage<String>? = nil
    
    init(wrappedValue: String, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.store = store
        
        if #available(iOS 14.0, *) {
            self._appStorage = AppStorage(wrappedValue: wrappedValue, key, store: store)
        }
    }
    
    var wrappedValue: String {
        get {
            if #available(iOS 14.0, *) {
                return appStorage?.wrappedValue ?? defaultValue
            } else {
                return store.string(forKey: key) ?? defaultValue
            }
        }
        set {
            if #available(iOS 14.0, *) {
                appStorage?.wrappedValue = newValue
            } else {
                store.set(newValue, forKey: key)
            }
        }
    }
    
    var projectedValue: Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}

/// A property wrapper specifically for double preferences
@propertyWrapper
struct DoublePreference {
    private let key: String
    private let defaultValue: Double
    private let store: UserDefaults
    
    @available(iOS 14.0, *)
    private var appStorage: AppStorage<Double>? = nil
    
    init(wrappedValue: Double, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.store = store
        
        if #available(iOS 14.0, *) {
            self._appStorage = AppStorage(wrappedValue: wrappedValue, key, store: store)
        }
    }
    
    var wrappedValue: Double {
        get {
            if #available(iOS 14.0, *) {
                return appStorage?.wrappedValue ?? defaultValue
            } else {
                return store.double(forKey: key)
            }
        }
        set {
            if #available(iOS 14.0, *) {
                appStorage?.wrappedValue = newValue
            } else {
                store.set(newValue, forKey: key)
            }
        }
    }
    
    var projectedValue: Binding<Double> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}
