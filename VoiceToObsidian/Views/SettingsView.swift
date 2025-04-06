import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices

struct SettingsView: View {
    @EnvironmentObject var voiceNoteStore: VoiceNoteStore
    @State private var anthropicAPIKey: String = UserDefaults.standard.string(forKey: "AnthropicAPIKey") ?? ""
    @State private var obsidianVaultPath: String = UserDefaults.standard.string(forKey: "ObsidianVaultPath") ?? ""
    @State private var showingAPIKeyAlert = false
    @State private var showingVaultPathAlert = false
    @State private var showingDirectoryPicker = false
    
    var body: some View {
        Form {
            Section(header: Text("Anthropic API")) {
                SecureField("API Key", text: $anthropicAPIKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("Save API Key") {
                    if !anthropicAPIKey.isEmpty {
                        voiceNoteStore.setAnthropicAPIKey(anthropicAPIKey)
                        showingAPIKeyAlert = true
                    }
                }
            }
            
            Section(header: Text("Obsidian Vault")) {
                TextField("Vault Path", text: $obsidianVaultPath)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("Select Vault Directory") {
                    showingDirectoryPicker = true
                }
                
                Button("Save Vault Path") {
                    if !obsidianVaultPath.isEmpty {
                        voiceNoteStore.setObsidianVaultPath(obsidianVaultPath)
                        showingVaultPathAlert = true
                    }
                }
            }
            
            Section(header: Text("About")) {
                Text("Voice to Obsidian")
                    .font(.headline)
                
                Text("Version 1.0")
                    .foregroundColor(.secondary)
                
                Text("This app records voice memos, transcribes them, cleans them up using Anthropic's Claude API, and saves them to your Obsidian vault.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Settings")
        .alert("API Key Saved", isPresented: $showingAPIKeyAlert) {
            Button("OK", role: .cancel) {}
        }
        .alert("Vault Path Saved", isPresented: $showingVaultPathAlert) {
            Button("OK", role: .cancel) {}
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
