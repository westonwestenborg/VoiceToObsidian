import Foundation
import SwiftUI

struct VoiceNote: Identifiable, Codable {
    var id: UUID
    var title: String
    var originalTranscript: String
    var cleanedTranscript: String
    var duration: TimeInterval
    var creationDate: Date
    var audioFilename: String
    var obsidianPath: String?
    
    // Computed property for audio URL
    var audioURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(audioFilename)
    }
    
    // Create a new voice note
    init(id: UUID = UUID(), 
         title: String, 
         originalTranscript: String, 
         cleanedTranscript: String, 
         duration: TimeInterval, 
         creationDate: Date = Date(), 
         audioFilename: String, 
         obsidianPath: String? = nil) {
        self.id = id
        self.title = title
        self.originalTranscript = originalTranscript
        self.cleanedTranscript = cleanedTranscript
        self.duration = duration
        self.creationDate = creationDate
        self.audioFilename = audioFilename
        self.obsidianPath = obsidianPath
    }
}

// MARK: - Sample Data for Preview
extension VoiceNote {
    static var sampleNote: VoiceNote {
        VoiceNote(
            title: "Meeting Notes for Project X",
            originalTranscript: "Um, so for project X we need to, uh, finish the UI design by next week and then start implementing the, the backend services. John will handle the API integration and Sarah will work on the database schema.",
            cleanedTranscript: "For Project X, we need to finish the UI design by next week and then start implementing the backend services. John will handle the API integration and Sarah will work on the database schema.",
            duration: 35.7,
            creationDate: Date().addingTimeInterval(-86400), // Yesterday
            audioFilename: "sample_recording.m4a",
            obsidianPath: "Voice Notes/Meeting Notes for Project X.md"
        )
    }
    
    static var sampleNotes: [VoiceNote] {
        [
            sampleNote,
            VoiceNote(
                title: "Ideas for New Feature",
                originalTranscript: "I think we should add a, um, notification system that alerts users when, when new content is available. Maybe use push notifications or email?",
                cleanedTranscript: "I think we should add a notification system that alerts users when new content is available. Maybe use push notifications or email?",
                duration: 18.2,
                creationDate: Date().addingTimeInterval(-172800), // 2 days ago
                audioFilename: "ideas_recording.m4a",
                obsidianPath: "Voice Notes/Ideas for New Feature.md"
            ),
            VoiceNote(
                title: "Shopping List",
                originalTranscript: "Need to get milk, eggs, bread, um, some vegetables like carrots and, and broccoli. Oh and don't forget toilet paper.",
                cleanedTranscript: "Need to get:\n- Milk\n- Eggs\n- Bread\n- Vegetables:\n  - Carrots\n  - Broccoli\n- Toilet paper",
                duration: 12.5,
                creationDate: Date().addingTimeInterval(-43200), // 12 hours ago
                audioFilename: "shopping_list.m4a",
                obsidianPath: "Voice Notes/Shopping List.md"
            )
        ]
    }
}
