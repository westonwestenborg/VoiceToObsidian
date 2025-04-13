import SwiftUI
import UIKit
import Combine
import OSLog

// Lightweight view that loads minimal content at startup
struct ContentView: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @State private var isRecording = false
    @State private var isReady = false
    @State private var showRecordingTray = false
    @State private var viewRefreshTrigger = false
    
    // For error handling
    @State private var cancellables = Set<AnyCancellable>()
    
    // Logger for debugging
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "ContentView")
    
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
                        // Preload notes before showing the main view
                        coordinator.loadMoreVoiceNotes()
                        
                        // Set isReady after a short delay to ensure notes are loaded
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isReady = true
                            logger.debug("Main view ready, notes count: \(coordinator.voiceNotes.count)")
                        }
                    }
                }
            } else {
                // Main content - Voice Note List is now the main view
                ZStack {
                    // Main list view
                    VoiceNoteListView()
                        .id(viewRefreshTrigger) // Force view recreation when needed
                        .errorBanner(error: Binding<AppError?>(get: { coordinator.errorState }, set: { coordinator.errorState = $0 }),
                                     isPresented: Binding<Bool>(get: { coordinator.isShowingError }, set: { coordinator.isShowingError = $0 }))
                        .onAppear {
                            // Set up a timer to force refresh if notes aren't showing
                            if !coordinator.voiceNotes.isEmpty {
                                logger.debug("Setting up delayed refresh check")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    // Force a view refresh to ensure notes appear
                                    viewRefreshTrigger.toggle()
                                    logger.debug("Forced view refresh triggered")
                                }
                            }
                        }
                    
                    // Record button (fixed at bottom center when not recording)
                    if !showRecordingTray {
                        VStack {
                            Spacer()
                            RecordButton(showRecordingTray: $showRecordingTray, isRecording: $isRecording)
                                .padding(.bottom, 20)
                        }
                    }
                    
                    // Recording tray that slides up from bottom
                    if showRecordingTray {
                        RecordingTrayView(isRecording: $isRecording, showTray: $showRecordingTray)
                            .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(10) // Ensure it's above everything else
                    }
                }
                .animation(.spring(), value: showRecordingTray)
            }
        }
        .onAppear {
            // Set up subscribers for error handling
            setupErrorHandling()
        }
    }
}

// UI appearance configuration has been moved to VoiceToObsidianApp.swift

// Record Button Component
struct RecordButton: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @Binding var showRecordingTray: Bool
    @Binding var isRecording: Bool
    
    // Logger for RecordButton
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "RecordButton")
    
    var body: some View {
        Button(action: {
            // Start recording immediately and show the tray
            startRecording()
            withAnimation {
                showRecordingTray = true
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.flexokiAccentBlue)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel("Record Voice Note")
    }
    
    private func startRecording() {
        // Use Task to call the async method
        Task {
            do {
                // Call the async version directly
                let success = try await coordinator.startRecordingAsync()
                if success {
                    // Update UI on the main thread
                    await MainActor.run {
                        isRecording = true
                    }
                }
            } catch {
                // Handle errors
                logger.error("Error starting recording: \(error.localizedDescription)")
            }
        }
    }
}

// Recording Tray View that slides up from bottom
struct RecordingTrayView: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @Binding var isRecording: Bool
    @Binding var showTray: Bool
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Only allow dismissing if not recording
                    if !isRecording {
                        withAnimation {
                            showTray = false
                        }
                    }
                }
            
            // Recording view container with animation
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Tray container that will slide up as a single unit
                    VStack(spacing: 0) {
                        // Handle indicator at top of tray
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 40, height: 5)
                            .cornerRadius(2.5)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                        
                        // Recording view content in a container
                        ZStack {
                            // Background for the tray
                            Rectangle()
                                .fill(Color.flexokiBackground)
                            
                            // Recording view content
                            RecordView(isRecording: $isRecording, onRecordingComplete: {
                                withAnimation {
                                    showTray = false
                                }
                            })
                            .padding(.top, 16)
                        }
                    }
                    .frame(height: geometry.size.height * 0.8)
                    .background(Color.flexokiBackground)
                    .cornerRadius(16, corners: [.topLeft, .topRight])
                }
            }
        }
    }
}

// Extension to apply corner radius to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// Custom shape for rounded corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

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
        
        // Listen for recording completion to hide the tray
        coordinator.$isProcessing
            .dropFirst() // Skip initial value
            .sink { isProcessing in
                if !isProcessing && isRecording == false {
                    // Recording has finished processing, hide the tray after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            showRecordingTray = false
                        }
                        
                        // Force a view refresh to ensure new note appears in the list
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            viewRefreshTrigger.toggle()
                            logger.debug("Forced view refresh after recording completion")
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Monitor voice notes changes
        coordinator.voiceNoteStoreForObservation.$voiceNotes
            .dropFirst() // Skip initial value
            .sink { notes in
                logger.debug("Voice notes updated, count: \(notes.count)")
                // Force view refresh when notes change
                DispatchQueue.main.async {
                    viewRefreshTrigger.toggle()
                    logger.debug("Forced view refresh due to notes update")
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
