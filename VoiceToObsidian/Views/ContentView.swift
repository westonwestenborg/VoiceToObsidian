import SwiftUI

struct ContentView: View {
    @EnvironmentObject var voiceNoteStore: VoiceNoteStore
    @State private var isRecording = false
    @State private var selectedTab = 0
    
    var body: some View {
        // Configure global appearance for Forms and Lists
        ZStack {
            Color.flexokiBackground.edgesIgnoringSafeArea(.all)
            
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
        .background(Color.flexokiBackground)
        .accentColor(Color.flexokiAccentBlue)
        }
        .onAppear {
            // Configure global appearance for the entire app
            configureGlobalAppearance()
        }
    }
}

// Configure global appearance settings
func configureGlobalAppearance() {
    // Table view appearance (affects Forms and Lists)
    UITableView.appearance().backgroundColor = UIColor(Color.flexokiBackground)
    UITableViewCell.appearance().backgroundColor = UIColor(Color.flexokiBackground2)
    
    // Navigation bar appearance
    let navBarAppearance = UINavigationBarAppearance()
    navBarAppearance.configureWithOpaqueBackground()
    navBarAppearance.backgroundColor = UIColor(Color.flexokiBackground)
    navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.flexokiText)]
    navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.flexokiText)]
    
    UINavigationBar.appearance().standardAppearance = navBarAppearance
    UINavigationBar.appearance().compactAppearance = navBarAppearance
    UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    
    // Form appearance
    if #available(iOS 15.0, *) {
        UITableView.appearance().sectionHeaderTopPadding = 0
    }
    UITableView.appearance().separatorColor = UIColor(Color.flexokiUI)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(VoiceNoteStore())
            .background(Color.flexokiBackground)
    }
}
