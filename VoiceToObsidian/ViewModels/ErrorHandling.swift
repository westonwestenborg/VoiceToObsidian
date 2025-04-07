import Foundation
import SwiftUI
import Combine

/// Protocol for view models that handle errors
protocol ErrorHandling: AnyObject {
    var errorState: AppError? { get set }
    var isShowingError: Bool { get set }
    
    /// Handle an error by setting the error state and showing the error UI
    func handleError(_ error: AppError)
    
    /// Dismiss the current error
    func dismissError()
}

/// Default implementation of error handling for view models
extension ErrorHandling {
    func handleError(_ error: AppError) {
        // Log the error
        error.log()
        
        // Update state on the main thread
        DispatchQueue.main.async {
            self.errorState = error
            self.isShowingError = true
        }
    }
    
    func dismissError() {
        DispatchQueue.main.async {
            self.isShowingError = false
            // Keep the error state for a moment to allow for smooth animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.errorState = nil
            }
        }
    }
}

/// Extension to make Result type work better with our error handling
extension Result where Failure == Error {
    /// Convert any error to an AppError
    var appError: Result<Success, AppError> {
        return self.mapError { error -> AppError in
            // If it's already an AppError, use it directly
            if let appErr = error as? AppError {
                return appErr
            }
            
            // Otherwise wrap it in a general error
            return AppError.general(error.localizedDescription)
        }
    }
}

/// Publisher extension to handle errors in a standardized way
extension Publisher where Failure == Error {
    /// Map any error to an AppError and handle it with the provided ErrorHandling object
    func handleError(with handler: ErrorHandling) -> AnyPublisher<Output, Never> {
        self.catch { error -> Empty<Output, Never> in
            // Convert to AppError if needed
            let appError: AppError
            if let appErr = error as? AppError {
                appError = appErr
            } else {
                appError = AppError.general(error.localizedDescription)
            }
            
            // Handle the error
            handler.handleError(appError)
            
            // Return an empty publisher to continue the chain
            return Empty()
        }
        .eraseToAnyPublisher()
    }
}
