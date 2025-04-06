import SwiftUI

struct ContentView: View {
    @EnvironmentObject var voiceNoteStore: VoiceNoteStore
    @State private var isRecording = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RecordView(isRecording: $isRecording)
                .tabItem {
                    Label("Record", systemImage: "mic")
                }
                .tag(0)
            
            VoiceNoteListView()
                .tabItem {
                    Label("Notes", systemImage: "list.bullet")
                }
                .tag(1)
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(2)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(VoiceNoteStore())
    }
}
