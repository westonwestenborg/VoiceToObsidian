import Foundation
import SwiftUI
import Combine
import OSLog

/// Manages the lifecycle of app services with deferred initialization
class AppCoordinator: ObservableObject, ErrorHandling {
    // App state
    @Published var appState: AppState = .initializing
    
    // Error handling properties
    @Published var errorState: AppError?
    @Published var isShowingError: Bool = false
    
    // Service references - all lazy to defer creation
    private var _voiceNoteCoordinator: VoiceNoteCoordinator?
    
    // Public accessor with lazy initialization
    var voiceNoteCoordinator: VoiceNoteCoordinator {
        if _voiceNoteCoordinator == nil {
            logger.debug("Lazily creating VoiceNoteCoordinator on first access")
            _voiceNoteCoordinator = VoiceNoteCoordinator(loadImmediately: false)
        }
        return _voiceNoteCoordinator!
    }
    
    // Logger for AppCoordinator
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "AppCoordinator")
    
    init() {
        logger.debug("AppCoordinator initialized - NO services created yet")
    }
    
    /// Handles errors from child coordinators
    func handleChildError(_ error: AppError) {
        // Forward errors to our own error handling
        handleError(error)
    }
    
    /// Start the app initialization sequence
    func startInitialization() {
        // Initially just show UI, don't create any services
        DispatchQueue.main.async {
            self.appState = .uiReady
            self.logger.debug("UI ready, scheduling essential services initialization")
            
            // Schedule essential services initialization after UI is visible
            // Using Task instead of DispatchQueue for better memory management
            Task { @MainActor in
                // Add a small delay to ensure UI is fully rendered
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                do {
                    try await self.initializeEssentialServicesAsync()
                } catch let error as AppError {
                    self.handleError(error)
                } catch {
                    let appError = AppError.general("Failed to initialize app: \(error.localizedDescription)")
                    self.handleError(appError)
                }
            }
        }
    }
    
    /// Initialize only the absolutely necessary services for basic app function
    private func initializeEssentialServicesAsync() async throws {
        logger.debug("Initializing essential services asynchronously")
        
        // Note: We don't actually create any services here, we just mark the app
        // as ready for user interaction. Services will be created on-demand when accessed.
        
        // Set up error handling between coordinators
        if let voiceNoteCoord = _voiceNoteCoordinator {
            // Subscribe to errors from the voice note coordinator
            voiceNoteCoord.$errorState
                .compactMap { $0 }
                .sink { [weak self] error in
                    self?.handleChildError(error)
                }
                .store(in: &voiceNoteCoord.cancellables)
        }
        
        // Update app state on the main actor
        await MainActor.run {
            appState = .ready
            logger.debug("App initialization complete")
        }
    }
    
    /// Prepare for recording (called when user wants to record)
    func prepareForRecording() {
        // This is where we'd initialize recording-specific services
        // For now, just accessing voiceNoteCoordinator will initialize it
        logger.debug("Preparing for recording - initializing voice note coordinator")
        _ = voiceNoteCoordinator
    }
    
    /// Clean up resources when app is backgrounded or terminated
    func cleanup() {
        logger.debug("Cleaning up app resources")
        _voiceNoteCoordinator?.cleanup()
    }
}

/// Represents the current state of the app
enum AppState: Equatable {
    case initializing
    case uiReady
    case ready
}
