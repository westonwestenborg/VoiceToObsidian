import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices
import Security

struct DocumentPicker: UIViewControllerRepresentable {
    var selectedURL: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        documentPicker.delegate = context.coordinator
        documentPicker.allowsMultipleSelection = false
        return documentPicker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            
            // Create a security-scoped bookmark
            do {
                // We need to use the minimal bookmark option without read-only restriction
                // since we need to write to the Obsidian vault
                let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                
                // Store in UserDefaults for backward compatibility
                UserDefaults.standard.set(bookmarkData, forKey: "ObsidianVaultBookmark")
                
                // Store in Keychain for enhanced security
                do {
                    try KeychainManager.saveData(bookmarkData, forKey: "ObsidianVaultBookmark")
                    print("Created security-scoped bookmark and saved to keychain for: \(url.path)")
                } catch {
                    print("Failed to save bookmark to keychain: \(error)")
                }
            } catch {
                print("Failed to create bookmark: \(error.localizedDescription)")
            }
            
            // Stop accessing if we started
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            
            parent.selectedURL(url)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle cancel
        }
    }
}
