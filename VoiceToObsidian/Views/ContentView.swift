import SwiftUI
import UIKit

// Custom tab view style to ensure consistent tab bar appearance
struct FlexokiTabViewStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(Color.flexokiBackground)
                
                UITabBar.appearance().standardAppearance = appearance
                if #available(iOS 15.0, *) {
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
            }
    }
}

// We're keeping the FlexokiTabViewStyle modifier but not using the extension method

// Lightweight view that loads minimal content at startup
struct ContentView: View {
    @EnvironmentObject var voiceNoteStore: VoiceNoteStore
    @State private var isRecording = false
    @State private var selectedTab = 0
    @State private var isReady = false
    
    var body: some View {
        // Use a lightweight loading view until ready
        ZStack {
            Color.flexokiBackground.edgesIgnoringSafeArea(.all)
            
            if !isReady {
                // Show a simple loading view
                VStack(spacing: 16) {
                    Text("Voice to Obsidian")
                        .font(.largeTitle)
                        .foregroundColor(Color.flexokiText)
                        .padding(.horizontal, 16)
                        .dynamicTypeSize(.small...(.accessibility5))
                    
                    // Simple loading indicator
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.flexokiAccentBlue, lineWidth: 3)
                        .frame(width: 30, height: 30)
                        .rotationEffect(Angle(degrees: isReady ? 0 : 360))
                        .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isReady)
                }
                .padding(.horizontal, 16)
                .onAppear {
                    // Delay full initialization
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isReady = true
                    }
                }
            } else {
                // Main content
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
                    
                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(2)
                }
                .accentColor(Color.flexokiAccentBlue)
                .modifier(FlexokiTabViewStyle())
            }
        }
        // No longer configuring appearance here, it's now centralized in VoiceToObsidianApp.swift
    }
}

// UI appearance configuration has been moved to VoiceToObsidianApp.swift

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(VoiceNoteStore())
            .background(Color.flexokiBackground)
    }
}
