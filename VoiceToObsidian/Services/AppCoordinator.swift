import Foundation
import SwiftUI
import Combine

/// Manages the lifecycle of app services with deferred initialization
class AppCoordinator: ObservableObject {
    // App state
    @Published var appState: AppState = .initializing
    
    // Service references - all lazy to defer creation
    private var _voiceNoteCoordinator: VoiceNoteCoordinator?
    
    // Public accessor with lazy initialization
    var voiceNoteCoordinator: VoiceNoteCoordinator {
        if _voiceNoteCoordinator == nil {
            print("Lazily creating VoiceNoteCoordinator on first access")
            _voiceNoteCoordinator = VoiceNoteCoordinator(loadImmediately: false)
        }
        return _voiceNoteCoordinator!
    }
    
    init() {
        print("AppCoordinator initialized - NO services created yet")
    }
    
    /// Start the app initialization sequence
    func startInitialization() {
        // Initially just show UI, don't create any services
        DispatchQueue.main.async {
            self.appState = .uiReady
            
            // Schedule essential services initialization after UI is visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.initializeEssentialServices()
            }
        }
    }
    
    /// Initialize only the absolutely necessary services for basic app function
    private func initializeEssentialServices() {
        // Note: We don't actually create any services here, we just mark the app
        // as ready for user interaction. Services will be created on-demand when accessed.
        print("App ready for interaction - services will initialize on demand")
        appState = .ready
    }
    
    /// Prepare for recording (called when user wants to record)
    func prepareForRecording() {
        // This is where we'd initialize recording-specific services
        // For now, just accessing voiceNoteCoordinator will initialize it
        _ = voiceNoteCoordinator
    }
    
    /// Clean up resources when app is backgrounded or terminated
    func cleanup() {
        _voiceNoteCoordinator?.cleanup()
    }
}

/// Represents the current state of the app
enum AppState: Equatable {
    case initializing
    case uiReady
    case ready
}
