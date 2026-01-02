import SwiftUI
import Combine
import Foundation
import OSLog

struct VoiceNoteListView: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var showingSettingsView = false
    @State private var forceRefresh = false // Added to force view refresh
    
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "VoiceNoteListView")
    
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
                }
            }
            .refreshable {
                await refreshNotes()
            }
            .navigationTitle("Voice Notes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search notes")
            .onChange(of: searchText) { _, newValue in
                let searching = !newValue.isEmpty
                if coordinator.isSearching != searching {
                    coordinator.isSearching = searching
                }
            }
            .toolbar {
                Button(action: {
                    logger.debug("Settings button tapped")
                    showingSettingsView = true
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(Color.flexokiAccentBlue)
                }
                .accessibilityLabel("Settings")
            }
            .fullScreenCover(isPresented: $showingSettingsView) {
                NavigationView {
                    SettingsView()
                        .navigationTitle("Settings")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: {
                                    showingSettingsView = false
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 16, weight: .medium))
                                        Text("Back")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    .foregroundColor(Color.flexokiAccentBlue)
                                }
                            }
                        }
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .background(Color.flexokiBackground)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Space for record button (64pt button + 20pt padding + 16pt breathing room)
                Color.clear.frame(height: 100)
            }
            .overlay {
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
            // Always load notes when the view appears
            logger.debug("VoiceNoteListView appeared - loading notes")
            coordinator.loadMoreVoiceNotes()
            
            // Set up a timer to force refresh the view if notes aren't showing
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                if !coordinator.voiceNotes.isEmpty && filteredNotes.isEmpty {
                    logger.debug("Forcing view refresh - notes loaded but not displayed")
                    forceRefresh.toggle() // Toggle to force view update
                }
            }
        }
        .id(forceRefresh) // Force view to recreate when forceRefresh changes
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
        logger.debug("Deleting notes at offsets: \(offsets)")
        
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
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch voiceNote.status {
        case .processing:
            HStack(spacing: 6) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.flexokiAccentBlue))
                    .scaleEffect(0.7)
                Text("Processing...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.flexokiAccentBlue)
            }
        case .error:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Error")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.red)
            }
        case .complete:
            EmptyView()
        }
    }
    
    var body: some View {
        // Use a clean layout without additional backgrounds
        VStack(alignment: .leading, spacing: Spacing.tight) {
            statusIndicator
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
                Text(DateFormatUtil.shared.formattedDate(voiceNote.creationDate))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.flexokiText2)
                    .dynamicTypeSize(.small...(.accessibility5))
                
                Spacer()
                
                Image(systemName: "clock")
                    .foregroundColor(Color.flexokiText2)
                Text(DateFormatUtil.shared.formatTimeShort(voiceNote.duration))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.flexokiText2)
                    .dynamicTypeSize(.small...(.accessibility5))
            }
            .padding(.top, Spacing.tight)
        }
        .padding(.vertical, Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Voice note: \(voiceNote.title), recorded on \(DateFormatUtil.shared.formattedDateSpoken(voiceNote.creationDate)), duration: \(DateFormatUtil.shared.formatTimeSpoken(voiceNote.duration))")
    }
    

}

struct VoiceNoteListView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceNoteListView()
            .environmentObject(VoiceNoteCoordinator(loadImmediately: true))
            .background(Color.flexokiBackground)
    }
}
