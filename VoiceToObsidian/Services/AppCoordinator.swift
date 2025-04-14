import Foundation
import SwiftUI
import Combine
import OSLog

/// Coordinates the application lifecycle and manages service initialization.
///
/// `AppCoordinator` serves as the central coordinator for the Voice to Obsidian app,
/// managing the lifecycle of various services and providing a deferred initialization pattern
/// to optimize app startup time. It handles:
/// - App state management
/// - Lazy initialization of services
/// - Coordination between app components
/// - Centralized error handling
///
/// The coordinator implements the `ErrorHandling` protocol to provide consistent error
/// management throughout the app. It is marked with `@MainActor` to ensure all UI updates
/// and state changes happen on the main thread.
///
/// ## Architecture
/// This class follows the Coordinator pattern, acting as the central point of coordination
/// for the app's MVVM architecture. Child coordinators handle specific feature domains.
///
/// ## Example Usage
/// ```swift
/// let appCoordinator = AppCoordinator()
/// appCoordinator.startInitialization()
///
/// // Later, when user wants to record
/// appCoordinator.prepareForRecording()
/// ```
@MainActor
class AppCoordinator: ObservableObject, ErrorHandling {
    /// The current state of the application.
    ///
    /// This published property reflects the app's current lifecycle state and is used by
    /// UI components to determine what to display. It progresses through the following states:
    /// - `.initializing`: App is starting up
    /// - `.uiReady`: UI is ready but services may not be fully initialized
    /// - `.ready`: App is fully initialized and ready for user interaction
    @Published var appState: AppState = .initializing
    
    // MARK: - Error Handling Properties
    
    /// The current error state of the application, if any.
    ///
    /// When an error occurs in the app, this property is updated with the error details.
    /// UI components observe this property to display appropriate error messages.
    @Published var errorState: AppError?
    
    /// Indicates whether an error message should be displayed to the user.
    ///
    /// This property controls the visibility of error UI components.
    @Published var isShowingError: Bool = false
    
    // MARK: - Service References
    
    /// Private backing field for the voice note coordinator.
    ///
    /// This property is nil until the coordinator is first accessed, implementing lazy initialization.
    private var _voiceNoteCoordinator: VoiceNoteCoordinator?
    
    /// Provides access to the voice note coordinator with lazy initialization.
    ///
    /// This property creates the VoiceNoteCoordinator on first access, implementing
    /// a deferred initialization pattern to optimize app startup time and resource usage.
    /// 
    /// - Returns: The initialized VoiceNoteCoordinator instance
    var voiceNoteCoordinator: VoiceNoteCoordinator {
        if _voiceNoteCoordinator == nil {
            logger.debug("Lazily creating VoiceNoteCoordinator on first access")
            _voiceNoteCoordinator = VoiceNoteCoordinator(loadImmediately: false)
        }
        return _voiceNoteCoordinator!
    }
    
    /// Logger for structured logging of coordinator operations.
    ///
    /// Uses OSLog for efficient and structured logging throughout the coordinator lifecycle.
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "AppCoordinator")
    
    /// Initializes a new AppCoordinator instance.
    ///
    /// This initializer is lightweight and doesn't set up any services immediately.
    /// Services are created on-demand when accessed to optimize app startup time.
    init() {
        logger.debug("AppCoordinator initialized - NO services created yet")
    }
    
    /// Handles errors propagated from child coordinators.
    ///
    /// This method provides a centralized error handling mechanism for errors that occur
    /// in child coordinators. It forwards the errors to the AppCoordinator's own error
    /// handling system.
    ///
    /// - Parameter error: The error from a child coordinator
    func handleChildError(_ error: AppError) {
        // Forward errors to our own error handling
        handleError(error)
    }
    
    /// Starts the application initialization sequence.
    ///
    /// This method implements a staged initialization approach:
    /// 1. First, it updates the app state to indicate the UI is ready
    /// 2. Then it schedules the initialization of essential services after a small delay
    ///    to ensure the UI is fully rendered and responsive
    ///
    /// This approach prioritizes UI responsiveness over immediate service availability,
    /// creating a better user experience during app startup.
    ///
    /// - Note: Services are initialized asynchronously to avoid blocking the main thread
    func startInitialization() {
        // Initially just show UI, don't create any services
        appState = .uiReady
        logger.debug("UI ready, scheduling essential services initialization")
        
        // Schedule essential services initialization after UI is visible
        Task {
            // Add a small delay to ensure UI is fully rendered
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            do {
                try await initializeEssentialServicesAsync()
            } catch let error as AppError {
                handleError(error)
            } catch {
                let appError = AppError.general("Failed to initialize app: \(error.localizedDescription)")
                handleError(appError)
            }
        }
    }
    
    /// Initializes only the absolutely necessary services for basic app functionality.
    ///
    /// This method implements the deferred initialization pattern. Instead of creating all
    /// services at startup, it:
    /// 1. Sets up error handling between coordinators that are already initialized
    /// 2. Updates the app state to indicate readiness
    ///
    /// Services are created on-demand when accessed, optimizing resource usage and startup time.
    ///
    /// - Throws: An error if initialization fails
    /// - Note: This method is called asynchronously from `startInitialization()`
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
    
    /// Prepares the app for recording functionality.
    ///
    /// This method is called when the user indicates they want to start recording.
    /// It ensures that all necessary services for recording are initialized before
    /// the recording UI is presented.
    ///
    /// The method leverages the lazy initialization pattern by simply accessing
    /// the `voiceNoteCoordinator` property, which triggers its creation if needed.
    ///
    /// - Note: This method should be called before showing recording UI to the user
    func prepareForRecording() {
        // This is where we'd initialize recording-specific services
        // For now, just accessing voiceNoteCoordinator will initialize it
        logger.debug("Preparing for recording - initializing voice note coordinator")
        _ = voiceNoteCoordinator
    }
    
    /// Cleans up resources when the app is backgrounded or terminated.
    ///
    /// This method ensures proper cleanup of all services and resources when the app
    /// is about to enter the background or be terminated. It delegates cleanup to
    /// each child coordinator.
    ///
    /// - Note: This should be called from the app delegate's applicationWillResignActive
    ///   or similar lifecycle methods
    func cleanup() {
        logger.debug("Cleaning up app resources")
        _voiceNoteCoordinator?.cleanup()
    }
}

/// Represents the current state of the application lifecycle.
///
/// This enum defines the possible states the app can be in during its lifecycle,
/// providing a clear indication of readiness for different operations.
///
/// - `initializing`: The app is starting up and initializing core components
/// - `uiReady`: The UI is ready to be displayed, but background services may still be initializing
/// - `ready`: The app is fully initialized and ready for all operations
enum AppState: Equatable {
    /// The app is in the process of starting up and initializing core components.
    case initializing
    
    /// The UI is ready to be displayed, but background services may still be initializing.
    case uiReady
    
    /// The app is fully initialized and ready for all operations.
    case ready
}
