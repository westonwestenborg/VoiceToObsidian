import SwiftUI

@main
struct VoiceToObsidianApp: App {
    @StateObject private var voiceNoteStore = VoiceNoteStore()
    
    init() {
        configureAppAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(voiceNoteStore)
                .preferredColorScheme(.light) // Default to light mode for Flexoki colors
                .background(Color.flexokiBackground)
        }
    }
    
    private func configureAppAppearance() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(Color.flexokiBackground)
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.flexokiText)]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.flexokiText)]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color.flexokiAccentBlue)
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.flexokiBackground)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        UITabBar.appearance().tintColor = UIColor(Color.flexokiAccentBlue)
    }
}
