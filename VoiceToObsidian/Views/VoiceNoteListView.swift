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
            ZStack {
                // Background color
                Color.flexokiBackground
                    .edgesIgnoringSafeArea(.all)
            List {
                if filteredNotes.isEmpty {
                    Text("No voice notes yet")
                        .foregroundColor(Color.flexokiText2)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(16)
                        .dynamicTypeSize(.small...(.accessibility5))
                        .listRowBackground(Color.flexokiBackground)
                } else {
                    ForEach(filteredNotes) { voiceNote in
                        NavigationLink(destination: VoiceNoteDetailView(voiceNote: voiceNote)) {
                            VoiceNoteRow(voiceNote: voiceNote)
                        }
                        .listRowBackground(Color.flexokiBackground)
                    }
                    .onDelete(perform: deleteNotes)
                }
            }
            .navigationTitle("Voice Notes")
            .searchable(text: $searchText, prompt: "Search notes")
            .toolbar {
                EditButton()
            }
            .listStyle(PlainListStyle())
            .background(Color.flexokiBackground)
            .onAppear {
                UITableView.appearance().backgroundColor = UIColor(Color.flexokiBackground)
            }
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
        // Use a clean layout without additional backgrounds
        VStack(alignment: .leading, spacing: 8) {
            Text(voiceNote.title)
                .font(.headline)
                .dynamicTypeSize(.small...(.accessibility5))
            
            Text(voiceNote.cleanedTranscript.prefix(100) + (voiceNote.cleanedTranscript.count > 100 ? "..." : ""))
                .font(.subheadline)
                .foregroundColor(Color.flexokiText2)
                .lineLimit(2)
                .dynamicTypeSize(.small...(.accessibility5))
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(Color.flexokiText2)
                Text(formattedDate(voiceNote.creationDate))
                    .font(.caption)
                    .foregroundColor(Color.flexokiText2)
                    .dynamicTypeSize(.small...(.accessibility5))
                
                Spacer()
                
                Image(systemName: "clock")
                    .foregroundColor(Color.flexokiText2)
                Text(formattedDuration(voiceNote.duration))
                    .font(.caption)
                    .foregroundColor(Color.flexokiText2)
                    .dynamicTypeSize(.small...(.accessibility5))
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 8)
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
            .background(Color.flexokiBackground)
    }
}
