import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices
import Combine
import Security
import UIKit
import OSLog

// Custom form components for Flexoki styling
struct FlexokiFormView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Background that extends to all edges
            Color.flexokiBackground
                .edgesIgnoringSafeArea(.all)
            
            // Content with styling
            ScrollView {
                VStack(spacing: 24) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }
}

struct FlexokiSectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.flexokiText)
                .dynamicTypeSize(.small...(.accessibility5))
            
            content
                .padding(16)
                .background(Color.flexokiBackground2)
                .cornerRadius(10)
        }
    }
}

// API Key Section View Component
struct APIKeySection: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @Binding var anthropicAPIKey: String
    @Binding var isLoadingAPIKey: Bool
    @Binding var showingAPIKeyAlert: Bool
    @Binding var showingClearedAlert: Bool
    
    // Use a binding to the secure storage instead of a property wrapper
    @Binding var secureAnthropicAPIKey: String
    
    var body: some View {
        FlexokiSectionView("Anthropic API") {
            VStack(alignment: .leading, spacing: 16) {
                Text("API Key")
                    .font(.subheadline)
                    .foregroundColor(Color.flexokiText2)
                    .dynamicTypeSize(.small...(.accessibility5))
                
                ZStack(alignment: .trailing) {
                    SecureField("Enter your Anthropic API key", text: $anthropicAPIKey)
                        .padding(8)
                        .background(Color.flexokiBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.flexokiUI, lineWidth: 1)
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .foregroundColor(Color.flexokiText)
                        .frame(minHeight: 44)
                        .disabled(isLoadingAPIKey)
                    
                    // Loading indicator
                    if isLoadingAPIKey {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.flexokiAccentBlue))
                            .scaleEffect(0.7)
                            .padding(.trailing, 12)
                    }
                }
                
                HStack(spacing: 8) {
                    Button(action: {
                        hideKeyboard()
                        if !anthropicAPIKey.isEmpty {
                            // Update the coordinator
                            coordinator.setAnthropicAPIKey(anthropicAPIKey)
                            // The binding will update the secure storage
                            secureAnthropicAPIKey = anthropicAPIKey
                            showingAPIKeyAlert = true
                        }
                    }) {
                        Text("Save API Key")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.flexokiPaper)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .padding(.horizontal, 16)
                            .background(Color.flexokiAccentBlue)
                            .cornerRadius(8)
                            .dynamicTypeSize(.small...(.accessibility5))
                    }
                    .disabled(isLoadingAPIKey)
                    .accessibilityHint("Securely saves your API key to the device")
                    
                    Button(action: {
                        hideKeyboard()
                        coordinator.clearAnthropicAPIKey()
                        secureAnthropicAPIKey = ""
                        anthropicAPIKey = ""
                        showingClearedAlert = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.flexokiPaper)
                            .frame(width: 44, height: 44)
                            .background(Color.flexokiRed)
                            .cornerRadius(8)
                    }
                    .disabled(isLoadingAPIKey || anthropicAPIKey.isEmpty)
                    .accessibilityLabel("Clear API Key")
                    .accessibilityHint("Removes the API key from the device")
                }
            }
        }
    }
}

// Vault Path Section View Component
struct VaultPathSection: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @Binding var obsidianVaultPath: String
    @Binding var isLoadingVaultPath: Bool
    @Binding var showingDocumentPicker: Bool
    @Binding var showingVaultPathAlert: Bool
    
    // Use a binding to the secure storage instead of a property wrapper
    @Binding var secureObsidianVaultPath: String
    
    var body: some View {
        FlexokiSectionView("Obsidian Vault") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Vault Path")
                    .font(.subheadline)
                    .foregroundColor(Color.flexokiText2)
                
                ZStack(alignment: .trailing) {
                    TextField("Path to your Obsidian vault", text: $obsidianVaultPath)
                        .padding(10)
                        .background(Color.flexokiBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.flexokiUI, lineWidth: 1)
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .foregroundColor(Color.flexokiText)
                        .disabled(isLoadingVaultPath)
                        .accessibilityLabel("Obsidian vault path")
                        .accessibilityHint("The location where your voice notes will be saved")
                    
                    // Loading indicator
                    if isLoadingVaultPath {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.flexokiAccentBlue))
                            .scaleEffect(0.7)
                            .padding(.trailing, 12)
                            .accessibilityLabel("Loading vault path")
                    }
                }
                
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Select Vault Directory")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.flexokiPaper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.flexokiAccentBlue)
                    .cornerRadius(8)
                    .dynamicTypeSize(.small...(.accessibility5))
                }
                .accessibilityHint("Opens a file browser to select your Obsidian vault location")
                
                Button(action: {
                    coordinator.clearObsidianVaultPath()
                    secureObsidianVaultPath = ""
                    obsidianVaultPath = ""
                    showingVaultPathAlert = true
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.flexokiRed)
                        Text("Clear Vault Path")
                            .foregroundColor(Color.flexokiRed)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.flexokiBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.flexokiRed, lineWidth: 1)
                    )
                    .dynamicTypeSize(.small...(.accessibility5))
                }
                .disabled(isLoadingVaultPath || obsidianVaultPath.isEmpty)
                .accessibilityHint("Removes the saved Obsidian vault location")
            }
        }
    }
}

// Clear All Data Section View Component
struct ClearAllDataSection: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @Binding var isLoadingAPIKey: Bool
    @Binding var isLoadingVaultPath: Bool
    @Binding var showingClearAllAlert: Bool
    
    var body: some View {
        FlexokiSectionView("Data Management") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Clear All Sensitive Data")
                    .font(.subheadline)
                    .foregroundColor(Color.flexokiText2)
                    .dynamicTypeSize(.small...(.accessibility5))
                
                Button(action: {
                    showingClearAllAlert = true
                }) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(Color.flexokiRed)
                        Text("Clear All Sensitive Data")
                            .foregroundColor(Color.flexokiRed)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.flexokiBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.flexokiRed, lineWidth: 1)
                    )
                    .dynamicTypeSize(.small...(.accessibility5))
                }
                .disabled(isLoadingAPIKey || isLoadingVaultPath)
                .accessibilityHint("Removes all API keys, vault paths, and security bookmarks from the device")
            }
        }
    }
}

// Main Settings View
struct SettingsView: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    
    // Use property wrappers for settings
    @SecureStorage(wrappedValue: "", key: "AnthropicAPIKey")
    private var secureAnthropicAPIKey: String
    
    @SecureStorage(wrappedValue: "", key: "ObsidianVaultPath")
    private var secureObsidianVaultPath: String
    
    // Local state for editing
    @State private var anthropicAPIKey = ""
    @State private var obsidianVaultPath = ""
    
    // App preferences
    @AppPreference(wrappedValue: true, "ShowTranscriptionProgress")
    private var showTranscriptionProgress: Bool
    
    @AppPreference(wrappedValue: true, "UseHighQualityRecording")
    private var useHighQualityRecording: Bool
    
    @State private var isLoadingAPIKey = false
    @State private var isLoadingVaultPath = false
    @State private var showingDocumentPicker = false
    @State private var showingAPIKeyAlert = false
    @State private var showingClearedAlert = false
    @State private var showingVaultPathAlert = false
    @State private var showingClearAllAlert = false
    @State private var showingClearAllConfirmation = false
    
    // For local error handling
    @State private var localErrorState: AppError?
    @State private var isShowingLocalError: Bool = false
    
    var body: some View {
        NavigationView {
            FlexokiFormView {
                // Use the extracted API Key Section component
                APIKeySection(
                    anthropicAPIKey: $anthropicAPIKey,
                    isLoadingAPIKey: $isLoadingAPIKey,
                    showingAPIKeyAlert: $showingAPIKeyAlert,
                    showingClearedAlert: $showingClearedAlert,
                    secureAnthropicAPIKey: $secureAnthropicAPIKey
                )
                
                // Use the extracted Vault Path Section component
                VaultPathSection(
                    obsidianVaultPath: $obsidianVaultPath,
                    isLoadingVaultPath: $isLoadingVaultPath,
                    showingDocumentPicker: $showingDocumentPicker,
                    showingVaultPathAlert: $showingVaultPathAlert,
                    secureObsidianVaultPath: $secureObsidianVaultPath
                )
                
                // Use the extracted Clear All Data Section component
                ClearAllDataSection(
                    isLoadingAPIKey: $isLoadingAPIKey,
                    isLoadingVaultPath: $isLoadingVaultPath,
                    showingClearAllAlert: $showingClearAllAlert
                )
            }
            .navigationTitle("Settings")
            .onAppear {
                loadSavedSettings()
            }
            .errorBanner(error: $localErrorState, isPresented: $isShowingLocalError)
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { url in
                    handleVaultSelection(url)
                }
            }
            .alert("API Key Saved", isPresented: $showingAPIKeyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your Anthropic API key has been securely saved.")
            }
            .alert("API Key Cleared", isPresented: $showingClearedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your Anthropic API key has been removed.")
            }
            .alert("Vault Path Cleared", isPresented: $showingVaultPathAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your Obsidian vault path has been removed.")
            }
            .alert("Clear All Sensitive Data", isPresented: $showingClearAllAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    Task {
                        let _ = await coordinator.clearAllSensitiveDataAsync()
                        // These updates are redundant since the coordinator already updates these values,
                        // but we'll keep them to ensure the UI is updated
                        await MainActor.run {
                            anthropicAPIKey = ""
                            obsidianVaultPath = ""
                            showingClearAllConfirmation = true
                        }
                    }
                }
            } message: {
                Text("This will remove all API keys, vault paths, and security bookmarks. Are you sure?")
            }
            .alert("Data Cleared", isPresented: $showingClearAllConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("All sensitive data has been removed from the app.")
            }
        }
    }
    
    // Logger for SettingsView
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "SettingsView")
    
    private func loadSavedSettings() {
        logger.debug("Loading saved settings")
        
        // Load API Key from property wrapper
        isLoadingAPIKey = true
        DispatchQueue.main.async {
            self.anthropicAPIKey = self.secureAnthropicAPIKey
            self.isLoadingAPIKey = false
        }
        
        // Load Vault Path from property wrapper
        isLoadingVaultPath = true
        DispatchQueue.main.async {
            self.obsidianVaultPath = self.secureObsidianVaultPath
            self.isLoadingVaultPath = false
        }
    }
    
    private func handleVaultSelection(_ url: URL) {
        isLoadingVaultPath = true
        
        // Get the path string from the URL
        let path = url.path
        
        // Try to create a security-scoped bookmark using SecurityManager
        do {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                let error = AppError.securityScoped(.accessDenied)
                handleError(error)
                isLoadingVaultPath = false
                return
            }
            
            // Create and store the bookmark using SecurityManager
            try SecurityManager.createAndStoreBookmark(for: url)
            
            // Save the path using the coordinator
            coordinator.setObsidianVaultPath(path)
            
            // Use the property wrapper's projected value (binding) to update the value
            // This avoids the 'self is immutable' error
            _secureObsidianVaultPath.projectedValue.wrappedValue = path
            
            // Update the UI
            obsidianVaultPath = path
            isLoadingVaultPath = false
            showingVaultPathAlert = true
            
            // Stop accessing the security-scoped resource
            SecurityManager.stopAccessingSecurityScopedResource(url: url)
        } catch {
            logger.error("Failed to create security-scoped bookmark: \(error)")
            let appError = AppError.securityScoped(.bookmarkCreationFailed)
            handleError(appError)
            isLoadingVaultPath = false
        }
    }
    
    /// Handle errors in this view
    private func handleError(_ error: AppError) {
        DispatchQueue.main.async {
            self.localErrorState = error
            self.isShowingLocalError = true
        }
    }
}

// Helper function to hide the keyboard
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(VoiceNoteCoordinator())
    }
}
