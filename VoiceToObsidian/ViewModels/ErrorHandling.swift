import Foundation
import SwiftUI
import Combine

/// A protocol that defines a standardized approach to error handling across view models.
///
/// `ErrorHandling` provides a consistent pattern for managing and displaying errors
/// throughout the application. It defines the required properties and methods for
/// error state management and provides default implementations for common error
/// handling operations.
///
/// Types conforming to this protocol can easily handle errors by calling the `handleError(_:)`
/// method, which will update the error state and trigger UI updates to display the error.
///
/// ## Example Implementation
/// ```swift
/// class MyViewModel: ObservableObject, ErrorHandling {
///     @Published var errorState: AppError?
///     @Published var isShowingError: Bool = false
///     
///     func performRiskyOperation() {
///         do {
///             try someRiskyOperation()
///         } catch let error as AppError {
///             handleError(error)
///         } catch {
///             handleError(AppError.general(error.localizedDescription))
///         }
///     }
/// }
/// ```
///
/// ## Example Usage in SwiftUI
/// ```swift
/// struct MyView: View {
///     @StateObject var viewModel = MyViewModel()
///     
///     var body: some View {
///         VStack {
///             // View content
///         }
///         .alert(isPresented: $viewModel.isShowingError) {
///             Alert(
///                 title: Text(viewModel.errorState?.failureReason ?? "Error"),
///                 message: Text(viewModel.errorState?.errorDescription ?? ""),
///                 dismissButton: .default(Text("OK"), action: viewModel.dismissError)
///             )
///         }
///     }
/// }
/// ```
protocol ErrorHandling: AnyObject {
    /// The current error state, if any.
    ///
    /// This property holds the current `AppError` that needs to be displayed to the user.
    /// It should be `nil` when no error is present.
    var errorState: AppError? { get set }
    
    /// Indicates whether an error is currently being shown to the user.
    ///
    /// This property controls the visibility of error UI components like alerts or banners.
    /// It should be bound to the appropriate SwiftUI view modifiers.
    var isShowingError: Bool { get set }
    
    /// Handles an error by setting the error state and showing the error UI.
    ///
    /// This method should update the `errorState` property with the provided error
    /// and set `isShowingError` to `true` to display the error to the user.
    ///
    /// - Parameter error: The `AppError` to handle and display
    func handleError(_ error: AppError)
    
    /// Dismisses the current error.
    ///
    /// This method should set `isShowingError` to `false` and eventually clear the `errorState`.
    /// The default implementation includes a short delay before clearing the error state
    /// to allow for smooth animations.
    func dismissError()
}

/// Default implementation of error handling for view models.
///
/// This extension provides standard implementations of the `ErrorHandling` protocol methods
/// that can be used by any conforming type without additional code. The implementations are
/// marked with `@MainActor` to ensure UI updates happen on the main thread.
extension ErrorHandling {
    /// Handles an error by logging it and updating the error state.
    ///
    /// This implementation logs the error using the `log()` method on `AppError`,
    /// then updates the error state properties to trigger UI updates. Since it's
    /// marked with `@MainActor`, all UI updates will happen on the main thread.
    ///
    /// - Parameter error: The `AppError` to handle and display
    @MainActor
    func handleError(_ error: AppError) {
        // Log the error
        error.log()
        
        // Update state directly on the main actor
        errorState = error
        isShowingError = true
    }
    
    /// Dismisses the current error with a short delay before clearing the error state.
    ///
    /// This implementation immediately sets `isShowingError` to `false` to hide any error UI,
    /// then waits a short period (0.3 seconds) before clearing the `errorState` property.
    /// This delay allows for smooth animations when dismissing error UI components.
    ///
    /// Since it's marked with `@MainActor`, all UI updates will happen on the main thread.
    @MainActor
    func dismissError() {
        isShowingError = false
        
        // Keep the error state for a moment to allow for smooth animation
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            errorState = nil
        }
    }
}

/// Extension to make the `Result` type work better with our error handling system.
///
/// This extension adds a convenience property to convert any `Result` with an `Error` failure
/// type to a `Result` with an `AppError` failure type, making it easier to integrate with
/// the application's error handling system.
extension Result where Failure == Error {
    /// Converts any error in the `Result` to an `AppError`.
    ///
    /// This property maps the error in a `Result<Success, Error>` to an `AppError`,
    /// either by using the error directly if it's already an `AppError`, or by
    /// wrapping it in an `AppError.general` case.
    ///
    /// - Returns: A new `Result` with the same success value but with any error converted to an `AppError`
    ///
    /// ## Example
    /// ```swift
    /// let result = someOperation() // Returns Result<Data, Error>
    /// switch result.appError {
    /// case .success(let data):
    ///     // Use the data
    /// case .failure(let appError):
    ///     handleError(appError)
    /// }
    /// ```
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

/// Extension to add error handling capabilities to Combine publishers.
///
/// This extension adds a method to `Publisher` that integrates with the application's
/// error handling system, making it easier to handle errors in Combine pipelines.
extension Publisher where Failure == Error {
    /// Maps any error to an `AppError` and handles it with the provided `ErrorHandling` object.
    ///
    /// This method catches any error from the publisher, converts it to an `AppError` if needed,
    /// and passes it to the provided error handler. It then returns a new publisher that never fails,
    /// allowing the Combine pipeline to continue without propagating the error.
    ///
    /// - Parameter handler: An object conforming to `ErrorHandling` that will handle any errors
    /// - Returns: A new publisher that never fails (`AnyPublisher<Output, Never>`)
    ///
    /// ## Example
    /// ```swift
    /// somePublisher
    ///     .handleError(with: self) // self conforms to ErrorHandling
    ///     .sink { value in
    ///         // Process the value
    ///     }
    ///     .store(in: &cancellables)
    /// ```
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
