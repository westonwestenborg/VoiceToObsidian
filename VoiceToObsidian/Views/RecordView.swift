import SwiftUI
import AVFoundation
import Combine

struct RecordView: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @Binding var isRecording: Bool
    @State private var showingProcessingAlert = false
    
    // For direct error handling in this view
    @State private var localErrorState: AppError?
    @State private var isShowingLocalError: Bool = false
    
    // Callback for when recording completes
    var onRecordingComplete: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Background color
            Color.flexokiBackground
                .edgesIgnoringSafeArea(.all)
                
            VStack(spacing: 16) {
                Spacer()
                
                // Recording visualization with waveform
                ZStack {
                    // Main visualization
                    WaveformView(
                        isRecording: isRecording,
                        color: isRecording ? Color.flexokiAccentRed : Color.flexokiAccentBlue
                    )
                    .frame(width: 250, height: 250)
                    
                    // Pulsing circle when recording
                    if isRecording {
                        Circle()
                            .stroke(Color.flexokiAccentRed, lineWidth: 3)
                            .frame(width: 250, height: 250)
                            .scaleEffect(isRecording ? 1.1 : 1.0)
                            .opacity(isRecording ? 0.5 : 1.0)
                            .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRecording)
                    }
                }
                
                // Timer display
                Text(timeString(time: coordinator.recordingDuration))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(isRecording ? Color.flexokiAccentRed : Color.flexokiText)
                    .padding(.top, 16)
                    .dynamicTypeSize(.small...(.accessibility5))
                    .accessibilityLabel("Recording time: \(timeStringSpoken(time: coordinator.recordingDuration))")
                
                Spacer()
                
                // Stop Recording button (red microphone)
                Button(action: {
                    stopRecording()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.flexokiAccentRed)
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                .accessibilityLabel("Stop Recording")
                .accessibilityHint("Stops the current recording")
                .padding(.bottom, 24)
            }
            .alert("Processing Voice Note", isPresented: $showingProcessingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your voice note is being transcribed and processed...")
            }
            .errorBanner(error: $localErrorState, isPresented: $isShowingLocalError)
            .onReceive(coordinator.$isProcessing) { isProcessing in
                // Update the processing alert based on the coordinator's state
                showingProcessingAlert = isProcessing
            }
        }
    }
    
    // startRecording is now handled by the main record button in ContentView
    
    private func stopRecording() {
        // Update UI state immediately
        isRecording = false
        showingProcessingAlert = true
        
        // Use Task to call the async method
        Task {
            do {
                // Call the async version directly
                let success = try await coordinator.stopRecordingAsync()
                // The coordinator will handle the processing and update its isProcessing state
                // We'll observe this in the .onReceive modifier
                
                // Call the completion callback if provided after recording is complete
                if let completion = onRecordingComplete {
                    await MainActor.run {
                        completion()
                    }
                }
            } catch {
                // Handle errors and hide the processing alert
                await MainActor.run {
                    showingProcessingAlert = false
                    
                    if let appError = error as? AppError {
                        handleError(appError)
                    } else {
                        // Convert generic error to AppError
                        let genericError = AppError.general(error.localizedDescription)
                        handleError(genericError)
                    }
                }
            }
        }
    }
    
    /// Handle errors in this view
    private func handleError(_ error: AppError) {
        // For errors that should be displayed locally in this view
        Task { @MainActor in
            localErrorState = error
            isShowingLocalError = true
        }
    }
    
    private func timeString(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time - floor(time)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
    
    /// Returns a spoken version of the time for accessibility
    private func timeStringSpoken(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") and \(seconds) second\(seconds == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
    }
}

struct RecordView_Previews: PreviewProvider {
    static var previews: some View {
        RecordView(isRecording: .constant(false), onRecordingComplete: nil)
            .environmentObject(VoiceNoteCoordinator(loadImmediately: true))
    }
}
