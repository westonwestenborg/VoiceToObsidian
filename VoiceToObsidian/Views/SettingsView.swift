import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices

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
                VStack(spacing: 20) {
                    content
                }
                .padding()
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
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color.flexokiText)
                .padding(.leading, 16)
            
            VStack(spacing: 2) {
                content
            }
            .padding(16)
            .background(Color.flexokiBackground2)
            .cornerRadius(10)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var voiceNoteStore: VoiceNoteStore
    @State private var anthropicAPIKey: String = UserDefaults.standard.string(forKey: "AnthropicAPIKey") ?? ""
    @State private var obsidianVaultPath: String = UserDefaults.standard.string(forKey: "ObsidianVaultPath") ?? ""
    @State private var showingAPIKeyAlert = false
    @State private var showingVaultPathAlert = false
    @State private var showingDirectoryPicker = false
    
    var body: some View {
        FlexokiFormView {
            // API Key Section
            FlexokiSectionView("Anthropic API") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("API Key")
                        .font(.subheadline)
                        .foregroundColor(Color.flexokiText2)
                    
                    SecureField("Enter your Anthropic API key", text: $anthropicAPIKey)
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
                    
                    Button(action: {
                        hideKeyboard()
                        if !anthropicAPIKey.isEmpty {
                            voiceNoteStore.setAnthropicAPIKey(anthropicAPIKey)
                            showingAPIKeyAlert = true
                        }
                    }) {
                        Text("Save API Key")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.flexokiPaper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.flexokiAccentBlue)
                            .cornerRadius(8)
                    }
                }
            }
            
            // Obsidian Vault Section
            FlexokiSectionView("Obsidian Vault") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Vault Path")
                        .font(.subheadline)
                        .foregroundColor(Color.flexokiText2)
                    
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
                    
                    Button(action: {
                        showingDirectoryPicker = true
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
                    }
                    
                    Button(action: {
                        hideKeyboard()
                        if !obsidianVaultPath.isEmpty {
                            voiceNoteStore.setObsidianVaultPath(obsidianVaultPath)
                            showingVaultPathAlert = true
                        }
                    }) {
                        Text("Save Vault Path")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.flexokiPaper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.flexokiAccentBlue)
                            .cornerRadius(8)
                    }
                }
            }
            
            // About Section
            FlexokiSectionView("About") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Voice to Obsidian")
                        .font(.headline)
                        .foregroundColor(Color.flexokiText)
                    
                    Text("Version 1.0")
                        .font(.subheadline)
                        .foregroundColor(Color.flexokiText2)
                    
                    Text("This app records voice memos, transcribes them, cleans them up using Anthropic's Claude API, and saves them to your Obsidian vault.")
                        .font(.caption)
                        .foregroundColor(Color.flexokiText2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Settings")
        .alert("API Key Saved", isPresented: $showingAPIKeyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your Anthropic API key has been saved.")
        }
        .alert("Vault Path Saved", isPresented: $showingVaultPathAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your Obsidian vault path has been saved.")
        }
        .sheet(isPresented: $showingDirectoryPicker) {
            DocumentPicker(selectedURL: { url in
                // Handle the selected directory URL
                obsidianVaultPath = url.path
                voiceNoteStore.setObsidianVaultPath(url.path)
                showingVaultPathAlert = true
            })
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environmentObject(VoiceNoteStore())
        }
    }
}

// Helper extension to hide keyboard
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
