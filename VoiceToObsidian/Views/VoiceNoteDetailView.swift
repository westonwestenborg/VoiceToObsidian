import SwiftUI
import AVFoundation

struct VoiceNoteDetailView: View {
    let voiceNote: VoiceNote
    @EnvironmentObject var voiceNoteStore: VoiceNoteStore
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showingOriginalTranscript = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text(voiceNote.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Date and duration info
                HStack {
                    Label(formattedDate(voiceNote.creationDate), systemImage: "calendar")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Label(formattedDuration(voiceNote.duration), systemImage: "clock")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                
                // Audio player controls
                VStack {
                    // Progress bar
                    ProgressView(value: currentTime, total: voiceNote.duration)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.vertical)
                    
                    // Time display
                    HStack {
                        Text(formatTimeString(currentTime))
                            .font(.caption)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Text(formatTimeString(voiceNote.duration))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    
                    // Playback controls
                    HStack {
                        Button(action: {
                            if isPlaying {
                                pauseAudio()
                            } else {
                                playAudio()
                            }
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .resizable()
                                .frame(width: 44, height: 44)
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            stopAudio()
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .resizable()
                                .frame(width: 44, height: 44)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Transcript section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Transcript")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            showingOriginalTranscript.toggle()
                        }) {
                            Text(showingOriginalTranscript ? "Show Cleaned" : "Show Original")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if showingOriginalTranscript {
                        Text(voiceNote.originalTranscript)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    } else {
                        Text(voiceNote.cleanedTranscript)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                // Obsidian link
                if let obsidianPath = voiceNote.obsidianPath {
                    VStack(alignment: .leading) {
                        Text("Obsidian Note")
                            .font(.headline)
                        
                        Button(action: {
                            // TODO: Open Obsidian note if possible
                            // This would require a URL scheme or other method
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text(obsidianPath)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationBarTitle("", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // TODO: Share options for the voice note
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            stopAudio()
        }
    }
    
    private func setupAudioPlayer() {
        guard let audioURL = voiceNote.audioURL else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Error setting up audio player: \(error.localizedDescription)")
        }
    }
    
    private func playAudio() {
        guard let player = audioPlayer else { return }
        
        player.play()
        isPlaying = true
        
        // Start timer to update current time
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = audioPlayer {
                currentTime = player.currentTime
                
                // Check if playback has finished
                if !player.isPlaying {
                    stopAudio()
                }
            }
        }
    }
    
    private func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }
    
    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        isPlaying = false
        timer?.invalidate()
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatTimeString(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VoiceNoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VoiceNoteDetailView(voiceNote: VoiceNote.sampleNote)
                .environmentObject(VoiceNoteStore())
        }
    }
}
