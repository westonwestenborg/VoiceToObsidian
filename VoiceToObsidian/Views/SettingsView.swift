import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices
import Combine
import Security
import UIKit
import OSLog

// MARK: - Form Components

// Custom form components for Flexoki styling
struct FlexokiFormView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
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

// MARK: - State Coordinator

/// Coordinator class that manages all state for the Settings view
/// This approach avoids the 'self is immutable' errors in SwiftUI by using a reference type
@MainActor
class SettingsStateCoordinator: ObservableObject {
    // Reference to the main coordinator
    var voiceNoteCoordinator: VoiceNoteCoordinator
    
    // Logger for structured logging
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "SettingsCoordinator")
    
    // Published properties for UI state
    @Published var anthropicAPIKey = ""
    @Published var obsidianVaultPath = ""
    @Published var isLoadingAPIKey = false
    @Published var isLoadingVaultPath = false
    @Published var showingDocumentPicker = false
    @Published var showingAPIKeyAlert = false
    @Published var showingClearedAlert = false
    @Published var showingVaultPathAlert = false
    @Published var showingClearAllAlert = false
    @Published var showingClearAllConfirmation = false
    @Published var localErrorState: AppError?
    @Published var isShowingLocalError = false
    
    // Secure storage references
    @SecureStorage(wrappedValue: "", key: "AnthropicAPIKey")
    var secureAnthropicAPIKey: String
    
    @SecureStorage(wrappedValue: "", key: "ObsidianVaultPath")
    var secureObsidianVaultPath: String
    
    init(coordinator: VoiceNoteCoordinator) {
        self.voiceNoteCoordinator = coordinator
        loadSavedSettings()
    }
    
    /// Loads saved settings from secure storage
    func loadSavedSettings() {
        logger.debug("Loading saved settings")
        
        // Load API Key from property wrapper
        isLoadingAPIKey = true
        anthropicAPIKey = secureAnthropicAPIKey
        isLoadingAPIKey = false
        
        // Load Vault Path from property wrapper
        isLoadingVaultPath = true
        obsidianVaultPath = secureObsidianVaultPath
        isLoadingVaultPath = false
    }
    
    /// Clears all sensitive data asynchronously
    func clearAllSensitiveData() async {
        logger.debug("Clearing all sensitive data")
        
        // Clear data through the coordinator
        await voiceNoteCoordinator.clearAllSensitiveDataAsync()
        
        // Update state variables
        anthropicAPIKey = ""
        obsidianVaultPath = ""
        secureAnthropicAPIKey = ""
        secureObsidianVaultPath = ""
        showingClearAllConfirmation = true
    }
    
    /// Handles vault selection from document picker
    func handleVaultSelection(_ url: URL) async {
        isLoadingVaultPath = true
        
        // Get the path string from the URL
        let path = url.path
        logger.debug("Selected vault path: \(path)")
        
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
            
            // Stop accessing the security-scoped resource
            url.stopAccessingSecurityScopedResource()
            
            // Update the coordinator
            await voiceNoteCoordinator.setObsidianVaultPath(path)
            
            // Update the secure storage and UI state
            secureObsidianVaultPath = path
            obsidianVaultPath = path
            showingVaultPathAlert = true
        } catch {
            logger.error("Failed to create security-scoped bookmark: \(error)")
            handleError(AppError.securityScoped(.bookmarkCreationFailed))
        }
        
        isLoadingVaultPath = false
    }
    
    /// Handles errors by updating state for display
    private func handleError(_ error: AppError) {
        logger.error("Error in settings: \(error.localizedDescription)")
        localErrorState = error
        isShowingLocalError = true
    }
}

// MARK: - Settings View

/// Main settings view for the application
struct SettingsView: View {
    // Environment object for the main coordinator
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    
    // State coordinator to manage all state for this view
    @StateObject private var stateCoordinator: SettingsStateCoordinator
    
    // StateObject for managing custom words/phrases
    @StateObject private var customWordsManager = CustomWordsManager.shared
    
    // Logger for structured logging
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "SettingsView")
    
    // Initialize the state coordinator
    init() {
        // Create a temporary coordinator for initialization
        // The actual coordinator will be provided by the environment
        let tempCoordinator = VoiceNoteCoordinator()
        _stateCoordinator = StateObject(wrappedValue: SettingsStateCoordinator(coordinator: tempCoordinator))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Use the extracted API Key Section component
                    APIKeySection(
                        anthropicAPIKey: $stateCoordinator.anthropicAPIKey,
                        isLoadingAPIKey: $stateCoordinator.isLoadingAPIKey,
                        showingAPIKeyAlert: $stateCoordinator.showingAPIKeyAlert,
                        showingClearedAlert: $stateCoordinator.showingClearedAlert,
                        secureAnthropicAPIKey: $stateCoordinator.secureAnthropicAPIKey
                    )
                    
                    // Use the extracted Vault Path Section component
                    VaultPathSection(
                        obsidianVaultPath: $stateCoordinator.obsidianVaultPath,
                        isLoadingVaultPath: $stateCoordinator.isLoadingVaultPath,
                        showingDocumentPicker: $stateCoordinator.showingDocumentPicker,
                        showingVaultPathAlert: $stateCoordinator.showingVaultPathAlert,
                        secureObsidianVaultPath: $stateCoordinator.secureObsidianVaultPath
                    )
                    
                    // --- Custom Words Section ---
                    FlexokiSectionView("Custom Words & Phrases") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add words or phrases you commonly use to improve transcription accuracy.")
                                .font(.footnote)
                                .foregroundColor(.flexokiText2)
                                .padding(.bottom, 4)
                            
                            NavigationLink(destination: CustomWordsView(customWordsManager: customWordsManager)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Manage Custom Words")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.flexokiText)
                                        
                                        if customWordsManager.customWords.isEmpty {
                                            Text("No custom words added")
                                                .font(.footnote)
                                                .foregroundColor(.flexokiText2)
                                        } else {
                                            Text("\(customWordsManager.customWords.count) word\(customWordsManager.customWords.count == 1 ? "" : "s") added")
                                                .font(.footnote)
                                                .foregroundColor(.flexokiText2)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.flexokiAccentBlue)
                                        .font(.footnote)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    // --- END Custom Words Section ---
                    
                    // Use the extracted Clear All Data Section component
                    ClearAllDataSection(
                        isLoadingAPIKey: $stateCoordinator.isLoadingAPIKey,
                        isLoadingVaultPath: $stateCoordinator.isLoadingVaultPath,
                        showingClearAllAlert: $stateCoordinator.showingClearAllAlert
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .background(Color.flexokiBackground.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("Settings", displayMode: .large)
        .onAppear {
            // Update the state coordinator with the actual coordinator from the environment
            stateCoordinator.voiceNoteCoordinator = coordinator
        }
        .errorBanner(error: $stateCoordinator.localErrorState, isPresented: $stateCoordinator.isShowingLocalError)
        .sheet(isPresented: $stateCoordinator.showingDocumentPicker) {
            DocumentPicker { url in
                // Use Task to handle the async vault selection
                Task { @MainActor in
                    await stateCoordinator.handleVaultSelection(url)
                }
            }
        }
        .alert("API Key Saved", isPresented: $stateCoordinator.showingAPIKeyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your Anthropic API key has been securely saved.")
        }
        .alert("API Key Cleared", isPresented: $stateCoordinator.showingClearedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your Anthropic API key has been removed.")
        }
        .alert("Vault Path Cleared", isPresented: $stateCoordinator.showingVaultPathAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your Obsidian vault path has been removed.")
        }
        .alert("Clear All Sensitive Data", isPresented: $stateCoordinator.showingClearAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                // Use Task to handle the async operation
                Task {
                    await stateCoordinator.clearAllSensitiveData()
                }
            }
        } message: {
            Text("This will remove your API key and vault path from secure storage.")
        }
        .alert("Data Cleared", isPresented: $stateCoordinator.showingClearAllConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("All sensitive data has been removed from the app.")
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
