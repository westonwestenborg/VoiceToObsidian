import SwiftUI
import UIKit
import AVFoundation
import Combine
import OSLog

// Streamlined app implementation with proper resource management
@main
struct VoiceToObsidianApp: App {
    // Use AppCoordinator to manage service lifecycle
    @StateObject private var coordinator = AppCoordinator()
    
    // Logger for app-level logging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "VoiceToObsidianApp")
    
    init() {
        logger.debug("App initialization started - using lightweight approach")

        // Reduce URLCache size for startup
        URLCache.shared = URLCache(memoryCapacity: 100_000, diskCapacity: 1_000_000, directory: nil)

        // Configure navigation bar appearance BEFORE any views render
        Self.configureAppearance()
    }
    
    // Set up memory warning notification handler - called from a non-escaping context
    private func setupMemoryWarningHandler() {
        // Store a reference to our coordinator to avoid capturing self
        let coordinatorRef = coordinator
        
        // Set memory warning notification with cleanup
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, 
                                               object: nil, 
                                               queue: .main) { _ in
            logger.warning("Memory warning received - performing cleanup")
            
            // Force memory cleanup without capturing self
            Task(priority: .utility) {
                // Clear URL cache
                URLCache.shared.removeAllCachedResponses()
                
                // Ask coordinator to clean up resources without capturing self
                await MainActor.run {
                    coordinatorRef.cleanup()
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch coordinator.appState {
                case .initializing:
                    // Show simple loading screen
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.flexokiBackground)
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
                }
            }
        }
    }
    
    /// Configure UIKit appearance proxies synchronously before views render
    private static func configureAppearance() {
        // Standard appearance (used when scrolled, inline title)
        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithOpaqueBackground()
        standardAppearance.backgroundColor = UIColor(Color.flexokiBackground)
        standardAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.flexokiText)]
        standardAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.flexokiText)]

        // Scroll edge appearance (used at top, large title visible)
        // Use transparent background so large title renders correctly
        let scrollEdgeAppearance = UINavigationBarAppearance()
        scrollEdgeAppearance.configureWithTransparentBackground()
        scrollEdgeAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.flexokiText)]
        scrollEdgeAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.flexokiText)]

        UINavigationBar.appearance().tintColor = UIColor.systemBlue
        UINavigationBar.appearance().standardAppearance = standardAppearance
        UINavigationBar.appearance().compactAppearance = standardAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdgeAppearance

        UITableView.appearance().backgroundColor = UIColor(Color.flexokiBackground)
        UITableViewCell.appearance().backgroundColor = UIColor(Color.flexokiBackground2)
        UITableView.appearance().sectionHeaderTopPadding = 0
        UITableView.appearance().separatorColor = UIColor(Color.flexokiUI)
    }
}


