import SwiftUI
import AVFoundation
import Combine
import UIKit
import Foundation

struct VoiceNoteDetailView: View {
    let voiceNote: VoiceNote
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showingOriginalTranscript = false
    
    var body: some View {
        // Extract the content into a separate view to reduce complexity
        DetailContentView(voiceNote: voiceNote, isPlaying: $isPlaying, currentTime: $currentTime, audioPlayer: $audioPlayer, showingOriginalTranscript: $showingOriginalTranscript)
    }
}

// Separate view to break up complex expressions
struct DetailContentView: View {
    let voiceNote: VoiceNote
    @Binding var isPlaying: Bool
    @Binding var currentTime: TimeInterval
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var showingOriginalTranscript: Bool
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    
    // Add timer as a state property so it can be modified
    @State private var timer: Timer? = nil
    
    // Audio playback functions
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
    
    var body: some View {
        ScrollView {
            ZStack {
                // Background color
                Color.flexokiBackground
                    .edgesIgnoringSafeArea(.all)
                
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text(voiceNote.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.flexokiText)
                        .dynamicTypeSize(.small...(.accessibility5))
                
                    // Date and duration info
                    HStack {
                        Label(DateFormatUtil.shared.formattedDate(voiceNote.creationDate), systemImage: "calendar")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.flexokiText2)
                            .dynamicTypeSize(.small...(.accessibility5))
                            .accessibilityLabel("Recorded on \(DateFormatUtil.shared.formattedDateSpoken(voiceNote.creationDate))")
                    
                        Spacer()
                    
                        Label(DateFormatUtil.shared.formatTimeShort(voiceNote.duration), systemImage: "clock")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.flexokiText2)
                            .dynamicTypeSize(.small...(.accessibility5))
                            .accessibilityLabel("Duration: \(DateFormatUtil.shared.formatTimeSpoken(voiceNote.duration))")
                    }
                
                    // Audio player controls
                    VStack {
                        // Progress bar
                        ProgressView(value: currentTime, total: voiceNote.duration)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.vertical, 16)
                    
                        // Time display
                        HStack {
                            Text(DateFormatUtil.shared.formatTimeShort(currentTime))
                                .font(.caption)
                                .monospacedDigit()
                                .dynamicTypeSize(.small...(.accessibility5))
                                .accessibilityLabel("Current position: \(DateFormatUtil.shared.formatTimeSpoken(currentTime))")
                        
                            Spacer()
                        
                            Text(DateFormatUtil.shared.formatTimeShort(voiceNote.duration))
                                .font(.caption)
                                .monospacedDigit()
                                .dynamicTypeSize(.small...(.accessibility5))
                                .accessibilityLabel("Total duration: \(DateFormatUtil.shared.formatTimeSpoken(voiceNote.duration))")
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
                                    .foregroundColor(Color.flexokiAccentBlue)
                            }
                            .accessibilityLabel(isPlaying ? "Pause audio" : "Play audio")
                        
                            Button(action: {
                                stopAudio()
                            }) {
                                Image(systemName: "stop.circle.fill")
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(Color.flexokiAccentRed)
                            }
                            .accessibilityLabel("Stop audio")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .padding(16)
                    .background(Color.flexokiBackground2)
                    .cornerRadius(10)
                
                    // Transcript section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Transcript")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.flexokiText)
                                .dynamicTypeSize(.small...(.accessibility5))
                        
                            Spacer()
                            
                            // Copy button
                            Button(action: {
                                // Copy the currently displayed transcript to clipboard
                                let textToCopy = showingOriginalTranscript ? voiceNote.originalTranscript : voiceNote.cleanedTranscript
                                UIPasteboard.general.string = textToCopy
                                
                                // Provide haptic feedback for successful copy
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.flexokiAccentBlue)
                            }
                            .frame(width: 44, height: 44)
                            .accessibilityLabel("Copy transcript")
                            .accessibilityHint("Copy the transcript to clipboard")
                            
                            Button(action: {
                                showingOriginalTranscript.toggle()
                            }) {
                                Text(showingOriginalTranscript ? "Show Cleaned" : "Show Original")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(Color.flexokiAccentBlue)
                                    .dynamicTypeSize(.small...(.accessibility5))
                            }
                            .frame(minHeight: 44)
                            .accessibilityLabel(showingOriginalTranscript ? "Show cleaned transcript" : "Show original transcript")
                            .accessibilityHint(showingOriginalTranscript ? "Switch to the AI-cleaned version of the transcript" : "Switch to the original unedited transcript")
                        }
                    
                        if showingOriginalTranscript {
                            Text(voiceNote.originalTranscript)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color.flexokiText)
                                .dynamicTypeSize(.small...(.accessibility5))
                                .padding(16)
                                .background(Color.flexokiBackground2)
                                .cornerRadius(8)
                                .accessibilityLabel("Original transcript: \(voiceNote.originalTranscript)")
                        } else {
                            Text(voiceNote.cleanedTranscript)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color.flexokiText)
                                .dynamicTypeSize(.small...(.accessibility5))
                                .padding(16)
                                .background(Color.flexokiBackground2)
                                .cornerRadius(8)
                                .accessibilityLabel("Cleaned transcript: \(voiceNote.cleanedTranscript)")
                        }
                    }
                
                    // Obsidian link
                    if let obsidianPath = voiceNote.obsidianPath {
                        VStack(alignment: .leading) {
                            Text("Obsidian Note")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.flexokiText)
                                .dynamicTypeSize(.small...(.accessibility5))
                        
                            Button(action: {
                                // TODO: Open Obsidian note if possible
                                // This would require a URL scheme or other method
                            }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                    Text(obsidianPath)
                                        .lineLimit(1)
                                        .dynamicTypeSize(.small...(.accessibility5))
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(Color.flexokiBackground2)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.flexokiBackground)
        .navigationBarTitle("", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Share the voice note using UIActivityViewController
                    if let audioURL = voiceNote.audioURL {
                        let activityVC = UIActivityViewController(activityItems: [audioURL], applicationActivities: nil)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            rootViewController.present(activityVC, animated: true)
                        }
                    }
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
}

struct VoiceNoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample voice note for preview
        let sampleVoiceNote = VoiceNote(
            title: "Sample Voice Note",
            originalTranscript: "This is the original transcript of the voice note.",
            cleanedTranscript: "This is the cleaned transcript of the voice note.",
            duration: 120, // 2 minutes
            audioFilename: "sample.m4a"
        )
        
        return NavigationView {
            VoiceNoteDetailView(voiceNote: sampleVoiceNote)
                .environmentObject(VoiceNoteCoordinator())
        }
    }
}
