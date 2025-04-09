import SwiftUI
import UIKit
import Combine

// Custom tab view style to ensure consistent tab bar appearance
struct FlexokiTabViewStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(Color.flexokiBackground)
                
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
    }
}

// We're keeping the FlexokiTabViewStyle modifier but not using the extension method

// Lightweight view that loads minimal content at startup
struct ContentView: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @State private var isRecording = false
    @State private var selectedTab = 0
    @State private var isReady = false
    
    // For error handling
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        // Use a lightweight loading view until ready
        ZStack {
            // Error banner will be displayed at the top of the screen
            // It uses the errorBanner modifier we created
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
                .errorBanner(error: Binding<AppError?>(get: { coordinator.errorState }, set: { coordinator.errorState = $0 }),
                             isPresented: Binding<Bool>(get: { coordinator.isShowingError }, set: { coordinator.isShowingError = $0 }))
            }
        }
        // No longer configuring appearance here, it's now centralized in VoiceToObsidianApp.swift
        .onAppear {
            // Set up subscribers for error handling
            setupErrorHandling()
        }
    }
}

// UI appearance configuration has been moved to VoiceToObsidianApp.swift

extension ContentView {
    /// Set up subscribers for error handling
    private func setupErrorHandling() {
        // Clear existing cancellables
        cancellables.removeAll()
        
        // Subscribe to error state changes
        coordinator.$isShowingError
            .sink { [weak coordinator] isShowing in
                if !isShowing {
                    // When error is dismissed, clear it after a delay to allow animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        coordinator?.errorState = nil
                    }
                }
            }
            .store(in: &cancellables)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(VoiceNoteCoordinator())
            .background(Color.flexokiBackground)
    }
}
