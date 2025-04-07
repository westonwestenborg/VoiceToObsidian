import SwiftUI
import Combine

struct VoiceNoteListView: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @State private var searchText = ""
    @State private var isRefreshing = false
    
    var filteredNotes: [VoiceNote] {
        if searchText.isEmpty {
            return coordinator.voiceNotes
        } else {
            return coordinator.voiceNotes.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.cleanedTranscript.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color.flexokiBackground
                    .edgesIgnoringSafeArea(.all)
                
                List {
                    if filteredNotes.isEmpty && !coordinator.isLoadingNotes && coordinator.loadedAllNotes {
                        Text("No voice notes yet")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.flexokiText2)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(16)
                            .dynamicTypeSize(.small...(.accessibility5))
                            .accessibilityLabel("No voice notes available")
                            .listRowBackground(Color.flexokiBackground)
                    } else {
                        ForEach(filteredNotes) { voiceNote in
                            NavigationLink(destination: VoiceNoteDetailView(voiceNote: voiceNote)) {
                                VoiceNoteRow(voiceNote: voiceNote)
                            }
                            .listRowBackground(Color.flexokiBackground)
                            .onAppear {
                                // If this is one of the last items, load more
                                if voiceNote.id == filteredNotes.last?.id && !coordinator.isLoadingNotes && !coordinator.loadedAllNotes {
                                    coordinator.loadMoreVoiceNotes()
                                }
                            }
                        }
                        .onDelete(perform: deleteNotes)
                        
                        // Loading indicator at the bottom
                        if coordinator.isLoadingNotes {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.flexokiAccentBlue))
                                    .scaleEffect(1.0)
                                    .padding()
                                Spacer()
                            }
                            .listRowBackground(Color.flexokiBackground)
                        }
                        
                        // End of list indicator
                        if coordinator.loadedAllNotes && !filteredNotes.isEmpty {
                            Text("End of notes")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color.flexokiText2)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(8)
                                .dynamicTypeSize(.small...(.accessibility5))
                                .accessibilityLabel("You have reached the end of the notes list")
                                .listRowBackground(Color.flexokiBackground)
                        }
                    }
                }
                .refreshable {
                    await refreshNotes()
                }
                .navigationTitle("Voice Notes")
                .searchable(text: $searchText, prompt: "Search notes")
                .toolbar {
                    EditButton()
                }
                .listStyle(PlainListStyle())
                .background(Color.flexokiBackground)
                
                // Initial loading state
                if filteredNotes.isEmpty && coordinator.isLoadingNotes && !isRefreshing {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.flexokiAccentBlue))
                            .scaleEffect(1.5)
                        Text("Loading notes...")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color.flexokiText)
                            .dynamicTypeSize(.small...(.accessibility5))
                            .padding(.top, 16)
                            .accessibilityLabel("Loading your voice notes")
                    }
                }
            }
        }
        .onAppear {
            // Only load notes if we haven't loaded any yet
            if coordinator.voiceNotes.isEmpty && !coordinator.isLoadingNotes && !coordinator.loadedAllNotes {
                coordinator.loadMoreVoiceNotes()
            }
        }
    }
    
    private func refreshNotes() async {
        isRefreshing = true
        
        // Simulate a network delay for better UX
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Reset and reload notes
        coordinator.refreshVoiceNotes()
        
        // Wait a bit to ensure the refresh control has time to animate
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        isRefreshing = false
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        // Get the actual voice notes to delete based on filtered list
        let notesToDelete = offsets.map { filteredNotes[$0] }
        
        // Delete each note
        for note in notesToDelete {
            coordinator.deleteVoiceNote(note)
        }
    }
}

struct VoiceNoteRow: View {
    let voiceNote: VoiceNote
    
    var body: some View {
        // Use a clean layout without additional backgrounds
        VStack(alignment: .leading, spacing: Spacing.tight) {
            Text(voiceNote.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.flexokiText)
                .dynamicTypeSize(.small...(.accessibility5))
            
            Text(voiceNote.cleanedTranscript.prefix(100) + (voiceNote.cleanedTranscript.count > 100 ? "..." : ""))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.flexokiText2)
                .dynamicTypeSize(.small...(.accessibility5))
                .lineLimit(2)
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(Color.flexokiText2)
                Text(formattedDate(voiceNote.creationDate))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.flexokiText2)
                    .dynamicTypeSize(.small...(.accessibility5))
                
                Spacer()
                
                Image(systemName: "clock")
                    .foregroundColor(Color.flexokiText2)
                Text(formattedDuration(voiceNote.duration))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.flexokiText2)
                    .dynamicTypeSize(.small...(.accessibility5))
            }
            .padding(.top, Spacing.tight)
        }
        .padding(.vertical, Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Voice note: \(voiceNote.title), recorded on \(formattedDateSpoken(voiceNote.creationDate)), duration: \(formattedDurationSpoken(voiceNote.duration))")
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedDateSpoken(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formattedDurationSpoken(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") and \(seconds) second\(seconds == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
    }
}

struct VoiceNoteListView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceNoteListView()
            .environmentObject(VoiceNoteCoordinator(loadImmediately: true))
            .background(Color.flexokiBackground)
    }
}
