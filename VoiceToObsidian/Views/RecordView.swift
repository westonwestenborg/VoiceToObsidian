import SwiftUI
import AVFoundation
import Combine

struct RecordView: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @Binding var isRecording: Bool
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingProcessingAlert = false
    
    var body: some View {
        NavigationView {
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
            
            // Record button
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.flexokiPaper)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 16)
                    .background(isRecording ? Color.flexokiAccentRed : Color.flexokiAccentBlue)
                    .cornerRadius(8)
                    .dynamicTypeSize(.small...(.accessibility5))
            }
            .accessibilityHint(isRecording ? "Stops the current recording" : "Starts a new voice recording")
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .alert("Processing Voice Note", isPresented: $showingProcessingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your voice note is being transcribed and processed...")
        }
        .alert("Recording Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onReceive(coordinator.$isProcessing) { isProcessing in
            // Update the processing alert based on the coordinator's state
            showingProcessingAlert = isProcessing
        }
            .navigationTitle("Record")
            }
        }
    }
    
    private func startRecording() {
        // Call the coordinator to start recording
        coordinator.startRecording()
        isRecording = true
    }
    
    private func stopRecording() {
        isRecording = false
        showingProcessingAlert = true
        
        // Stop recording and process the audio
        coordinator.stopRecording()
        
        // The coordinator will handle the processing and update its isProcessing state
        // We'll observe this in the .onReceive modifier
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
        RecordView(isRecording: .constant(false))
            .environmentObject(VoiceNoteCoordinator(loadImmediately: true))
    }
}
