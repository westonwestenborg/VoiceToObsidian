import SwiftUI

/// A reusable view component for displaying error messages to the user
struct ErrorBannerView: View {
    let error: AppError
    let dismissAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 18))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.failureReason ?? "Error")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(error.errorDescription ?? "An unknown error occurred")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Spacer()
                
                Button(action: dismissAction) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(999) // Ensure it appears above other content
    }
}

/// A modifier that adds error handling to any view
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: AppError?
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented, let error = error {
                VStack {
                    ErrorBannerView(error: error) {
                        withAnimation {
                            isPresented = false
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: isPresented)
                .zIndex(100)
            }
        }
    }
}

extension View {
    /// Adds an error banner that appears when an error is present
    /// - Parameters:
    ///   - error: Binding to the error that should be displayed
    ///   - isPresented: Binding to control the visibility of the error banner
    /// - Returns: A view with the error banner capability
    func errorBanner(error: Binding<AppError?>, isPresented: Binding<Bool>) -> some View {
        self.modifier(ErrorAlertModifier(error: error, isPresented: isPresented))
    }
}

// MARK: - Preview
#if DEBUG
struct ErrorBannerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ErrorBannerView(
                error: AppError.recording(.permissionDenied)
            ) {
                print("Dismissed")
            }
            
            ErrorBannerView(
                error: AppError.anthropic(.apiKeyMissing)
            ) {
                print("Dismissed")
            }
            
            ErrorBannerView(
                error: AppError.obsidian(.fileCreationFailed("Could not create file"))
            ) {
                print("Dismissed")
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
