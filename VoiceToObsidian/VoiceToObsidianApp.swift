import SwiftUI
import UIKit
import AVFoundation
import Combine

// Streamlined app implementation with proper resource management
@main
struct VoiceToObsidianApp: App {
    // Use AppCoordinator to manage service lifecycle
    @StateObject private var coordinator = AppCoordinator()
    
    // Basic UI state - minimal state to avoid memory pressure
    @State private var isFirstLaunch = true
    
    init() {
        // Minimal app initialization
        print("App initialization started - using lightweight approach")
        
        // Reduce URLCache size for startup
        URLCache.shared = URLCache(memoryCapacity: 100_000, diskCapacity: 1_000_000, directory: nil)
        
        // Don't register notification observation here - moved to onAppear in the body
    }
    
    // Set up memory warning notification handler - called from a non-escaping context
    private func setupMemoryWarningHandler() {
        // Store a reference to our coordinator to avoid capturing self
        let coordinatorRef = coordinator
        
        // Set memory warning notification with cleanup
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, 
                                               object: nil, 
                                               queue: .main) { _ in
            print("Memory warning received - performing cleanup")
            
            // Force memory cleanup without capturing self
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    // Clear URL cache
                    URLCache.shared.removeAllCachedResponses()
                    
                    // Ask coordinator to clean up resources without capturing self
                    DispatchQueue.main.async {
                        coordinatorRef.cleanup()
                    }
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Background color
                Color(UIColor.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                // Content based on app state
                switch coordinator.appState {
                case .initializing:
                    // Show simple loading screen
                    ProgressView("Loading...")
                        .onAppear {
                            // Start the coordinator's initialization process
                            coordinator.startInitialization()
                            
                            // Set up memory warning handler
                            setupMemoryWarningHandler()
                        }
                    
                case .uiReady, .ready:
                    // Main content view
                    ContentView()
                        .environmentObject(coordinator.voiceNoteCoordinator)
                        .transition(.opacity)
                        .animation(.easeIn, value: coordinator.appState != .initializing)
                        .onAppear {
                            if isFirstLaunch {
                                // Do minimal first-launch setup
                                configureAppearance()
                                isFirstLaunch = false
                            }
                        }
                }
            }
        }
    }
    
    // Configure appearance (standard approach)
    private func configureAppearance() {
        // Basic appearance configuration
        UINavigationBar.appearance().tintColor = UIColor.systemBlue
        
        // More detailed appearance configuration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            autoreleasepool {
                let navBarAppearance = UINavigationBarAppearance()
                navBarAppearance.configureWithOpaqueBackground()
                navBarAppearance.backgroundColor = UIColor(Color.flexokiBackground)
                navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.flexokiText)]
                navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.flexokiText)]
                
                UINavigationBar.appearance().standardAppearance = navBarAppearance
                UINavigationBar.appearance().compactAppearance = navBarAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
                
                UITableView.appearance().backgroundColor = UIColor(Color.flexokiBackground)
                UITableViewCell.appearance().backgroundColor = UIColor(Color.flexokiBackground2)
                
                UITableView.appearance().sectionHeaderTopPadding = 0
                UITableView.appearance().separatorColor = UIColor(Color.flexokiUI)
            }
        }
    }
}


