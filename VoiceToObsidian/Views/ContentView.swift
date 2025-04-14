import SwiftUI
import UIKit
import Combine
import OSLog

// Lightweight view that loads minimal content at startup
@MainActor
struct ContentView: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @State private var isRecording = false
    @State private var isReady = false
    // No longer using a tray for recording UI
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
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        
                        // Preload notes before showing the main view
                        coordinator.loadMoreVoiceNotes()
                        
                        // Set isReady after a short delay to ensure notes are loaded
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        isReady = true
                        logger.debug("Main view ready, notes count: \(coordinator.voiceNotes.count)")
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
                                Task {
                                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                                    // Force a view refresh to ensure notes appear
                                    viewRefreshTrigger.toggle()
                                    logger.debug("Forced view refresh triggered")
                                }
                            }
                        }
                    
                    // Record button with floating timer when recording
                    VStack {
                        Spacer()
                        RecordButton(isRecording: $isRecording)
                            .padding(.bottom, 20)
                    }
                }
                .animation(.spring(), value: isRecording)
            }
        }
        .onAppear {
            // Set up subscribers for error handling
            setupErrorHandling()
        }
    }
}

// UI appearance configuration has been moved to VoiceToObsidianApp.swift

// Record Button Component with integrated timer display
struct RecordButton: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @Binding var isRecording: Bool
    
    // Logger for RecordButton
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.VoiceToObsidian", category: "RecordButton")
    
    var body: some View {
        VStack(spacing: 8) {
            // Floating timer that appears when recording
            if isRecording {
                Text(timeString(time: coordinator.recordingDuration))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.flexokiAccentRed)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.flexokiBackground.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                    )
                    .transition(.scale.combined(with: .opacity))
                    .dynamicTypeSize(.small...(.accessibility5))
                    .accessibilityLabel("Recording time: \(timeStringSpoken(time: coordinator.recordingDuration))")
            }
            
            // Button changes appearance and function based on recording state
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.flexokiAccentRed : Color.flexokiAccentBlue)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                    
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            .accessibilityLabel(isRecording ? "Stop Recording" : "Record Voice Note")
            .accessibilityHint(isRecording ? "Stops the current recording" : "Starts recording a new voice note")
        }
    }
    
    // Helper functions moved outside of body
    func startRecording() {
        // Use Task to call the async method
        Task {
            do {
                // Call the async version directly
                let success = try await coordinator.startRecordingAsync()
                if success {
                    // Update UI on the main thread
                    await MainActor.run {
                        withAnimation(.spring()) {
                            isRecording = true
                        }
                    }
                }
            } catch {
                // Handle errors
                logger.error("Error starting recording: \(error.localizedDescription)")
            }
        }
    }
    
    func stopRecording() {
        // Update UI state immediately
        withAnimation(.spring()) {
            isRecording = false
        }
        
        // Use Task to call the async method
        Task {
            do {
                // Call the async version directly
                let _ = try await coordinator.stopRecordingAsync()
                // The coordinator will handle the processing and update its isProcessing state
            } catch {
                // Handle errors
                logger.error("Error stopping recording: \(error.localizedDescription)")
            }
        }
    }
    
    /// Formats the time interval for display
    func timeString(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time - floor(time)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
    
    /// Returns a spoken version of the time for accessibility
    func timeStringSpoken(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") and \(seconds) second\(seconds == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
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
    func setupErrorHandling() {
        // Clear existing cancellables
        cancellables.removeAll()
        
        // Subscribe to error state changes
        coordinator.$isShowingError
            .sink { [weak coordinator] isShowing in
                if !isShowing {
                    // When error is dismissed, clear it after a delay to allow animation
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                        coordinator?.errorState = nil
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for recording completion
        coordinator.$isProcessing
            .dropFirst() // Skip initial value
            .sink { isProcessing in
                if !isProcessing && self.isRecording == false {
                    // Recording has finished processing, refresh the view after a short delay
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        
                        // Force a view refresh to ensure new note appears in the list
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                        await MainActor.run {
                            self.viewRefreshTrigger.toggle()
                            self.logger.debug("Forced view refresh after recording completion")
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Monitor voice notes changes
        coordinator.voiceNoteStoreForObservation.$voiceNotes
            .dropFirst() // Skip initial value
            .sink { notes in
                self.logger.debug("Voice notes updated, count: \(notes.count)")
                // Force view refresh when notes change
                Task { @MainActor in
                    self.viewRefreshTrigger.toggle()
                    self.logger.debug("Forced view refresh due to notes update")
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
