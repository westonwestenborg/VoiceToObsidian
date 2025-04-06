import SwiftUI

@main
struct VoiceToObsidianApp: App {
    @StateObject private var voiceNoteStore = VoiceNoteStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(voiceNoteStore)
        }
    }
}
