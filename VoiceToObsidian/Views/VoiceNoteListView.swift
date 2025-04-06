import SwiftUI

struct VoiceNoteListView: View {
    @EnvironmentObject var voiceNoteStore: VoiceNoteStore
    @State private var searchText = ""
    
    var filteredNotes: [VoiceNote] {
        if searchText.isEmpty {
            return voiceNoteStore.voiceNotes
        } else {
            return voiceNoteStore.voiceNotes.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.cleanedTranscript.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if filteredNotes.isEmpty {
                    Text("No voice notes yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(filteredNotes) { voiceNote in
                        NavigationLink(destination: VoiceNoteDetailView(voiceNote: voiceNote)) {
                            VoiceNoteRow(voiceNote: voiceNote)
                        }
                    }
                    .onDelete(perform: deleteNotes)
                }
            }
            .navigationTitle("Voice Notes")
            .searchable(text: $searchText, prompt: "Search notes")
            .toolbar {
                EditButton()
            }
        }
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        // Get the actual voice notes to delete based on filtered list
        let notesToDelete = offsets.map { filteredNotes[$0] }
        
        // Delete each note
        for note in notesToDelete {
            voiceNoteStore.deleteVoiceNote(note)
        }
    }
}

struct VoiceNoteRow: View {
    let voiceNote: VoiceNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(voiceNote.title)
                .font(.headline)
            
            Text(voiceNote.cleanedTranscript.prefix(100) + (voiceNote.cleanedTranscript.count > 100 ? "..." : ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text(formattedDate(voiceNote.creationDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text(formattedDuration(voiceNote.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
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
}

struct VoiceNoteListView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceNoteListView()
            .environmentObject(VoiceNoteStore(previewData: true))
    }
}
