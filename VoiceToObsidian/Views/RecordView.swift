import SwiftUI
import AVFoundation

struct RecordView: View {
    @EnvironmentObject var voiceNoteStore: VoiceNoteStore
    @Binding var isRecording: Bool
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
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
            Text(timeString(time: recordingTime))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(isRecording ? Color.flexokiAccentRed : Color.flexokiText)
                .padding(.top, 16)
                .dynamicTypeSize(.small...(.accessibility5))
            
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
                    .font(.headline)
                    .foregroundColor(Color.flexokiPaper)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(isRecording ? Color.flexokiAccentRed : Color.flexokiAccentBlue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .alert("Processing Voice Note", isPresented: $showingProcessingAlert) {
            ProgressView()
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your voice note is being transcribed and processed...")
            }
            .navigationTitle("Record")
            }
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordingTime = 0
        
        // Start the timer for recording duration
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
        }
        
        // Call the audio recording service
        voiceNoteStore.startRecording { success in
            if !success {
                isRecording = false
                timer?.invalidate()
                // TODO: Show error alert
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        timer?.invalidate()
        showingProcessingAlert = true
        
        // Stop recording and process the audio
        voiceNoteStore.stopRecording { success, voiceNote in
            showingProcessingAlert = false
            
            if success, let _ = voiceNote {
                // Successfully processed voice note
                // Reset the timer to 0 after successful processing
                DispatchQueue.main.async {
                    self.recordingTime = 0
                }
            } else {
                // TODO: Show error alert
            }
        }
    }
    
    private func timeString(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time - floor(time)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
}

struct RecordView_Previews: PreviewProvider {
    static var previews: some View {
        RecordView(isRecording: .constant(false))
            .environmentObject(VoiceNoteStore())
    }
}
