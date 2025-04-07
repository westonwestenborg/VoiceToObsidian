import SwiftUI
import UIKit
import AVFoundation

// Ultra-minimal app implementation to reduce memory pressure
@main
struct VoiceToObsidianApp: App {
    // Use StateObject only when the view appears, not during initialization
    // Using a lazy property wrapper to further delay initialization
    @StateObject private var voiceNoteStore = VoiceNoteStore(lazyInit: true)
    @State private var isAppReady = false
    @State private var isFirstLaunch = true
    
    init() {
        // Absolute minimal initialization - defer everything possible
        print("App initialization started")
        
        // Disable unnecessary system services during launch
        disableUnnecessaryServices()
        
        // Set memory warning notification
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, 
                                               object: nil, 
                                               queue: .main) { _ in
            print("Memory warning received")
            // Force memory cleanup
            autoreleasepool {
                URLCache.shared.removeAllCachedResponses()
                if #available(iOS 15.0, *) {
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Background color - use system color to reduce memory
                Color(UIColor.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                if !isAppReady {
                    // Ultra minimal loading view - no custom fonts or images
                    Text("Loading...")
                        .onAppear {
                            // Delay app initialization in stages
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // Stage 1: Just show UI
                                isAppReady = true
                                
                                // Stage 2: Configure minimal appearance after UI is shown
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    configureMinimalAppearance()
                                }
                            }
                        }
                } else {
                    // Main content - only loaded after delay
                    ContentView()
                        .environmentObject(voiceNoteStore)
                        .transition(.opacity)
                        .animation(.easeIn, value: isAppReady)
                        .onAppear {
                            if isFirstLaunch {
                                // Configure audio session with minimal settings
                                configureMinimalAudioSession()
                                isFirstLaunch = false
                            }
                        }
                }
            }
        }
    }
    
    // Disable unnecessary system services during launch
    private func disableUnnecessaryServices() {
        // Minimize audio session initialization
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Could not configure audio session: \(error)")
        }
        
        // Reduce URLCache size
        URLCache.shared = URLCache(memoryCapacity: 100_000, diskCapacity: 1_000_000, directory: nil)
    }
    
    // Configure minimal audio session when needed
    private func configureMinimalAudioSession() {
        DispatchQueue.global(qos: .utility).async {
            do {
                try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)
                print("Set minimal audio buffer size")
            } catch {
                print("Could not set preferred IO buffer duration: \(error)")
            }
        }
    }
}

// Minimal appearance configuration to reduce memory pressure
func configureMinimalAppearance() {
    // Only set essential appearance properties
    UINavigationBar.appearance().tintColor = UIColor.systemBlue
    UITabBar.appearance().tintColor = UIColor.systemBlue
    
    // Configure full appearance only when needed, with a longer delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        autoreleasepool {
            configureFullAppearance()
        }
    }
}

// Full appearance configuration deferred to much later
func configureFullAppearance() {
    autoreleasepool {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(Color.flexokiBackground)
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.flexokiText)]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.flexokiText)]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.flexokiBackground)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        
        // Table view appearance (affects Forms and Lists) - moved from ContentView
        UITableView.appearance().backgroundColor = UIColor(Color.flexokiBackground)
        UITableViewCell.appearance().backgroundColor = UIColor(Color.flexokiBackground2)
        
        // Form appearance - moved from ContentView
        if #available(iOS 15.0, *) {
            UITableView.appearance().sectionHeaderTopPadding = 0
        }
        UITableView.appearance().separatorColor = UIColor(Color.flexokiUI)
    }
}
