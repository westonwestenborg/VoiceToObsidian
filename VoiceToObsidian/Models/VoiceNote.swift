import Foundation
import SwiftUI

/// A model representing a voice note with its transcription and metadata.
///
/// `VoiceNote` encapsulates all the data related to a recorded voice note, including:
/// - Basic metadata (title, creation date, duration)
/// - Transcription content (both original and cleaned versions)
/// - File references (audio file path and optional Obsidian note path)
///
/// This model conforms to `Identifiable` for use in SwiftUI lists and `Codable` for
/// serialization to and from JSON for persistence.
///
/// ## Example Usage
/// ```swift
/// // Create a new voice note
/// let voiceNote = VoiceNote(
///     title: "Meeting Notes",
///     originalTranscript: "Raw transcript from speech recognition...",
///     cleanedTranscript: "Cleaned transcript from AI processing...",
///     duration: 45.3,
///     audioFilename: "recording_123.m4a"
/// )
///
/// // Access properties
/// print("Title: \(voiceNote.title)")
/// print("Duration: \(voiceNote.duration) seconds")
///
/// // Get the URL to the audio file
/// if let audioURL = voiceNote.audioURL {
///     // Use the audio URL
/// }
/// ```
struct VoiceNote: Identifiable, Codable {
    /// Unique identifier for the voice note.
    ///
    /// This UUID is used to uniquely identify each voice note and is automatically
    /// generated when creating a new note if not provided explicitly.
    var id: UUID
    
    /// The title of the voice note.
    ///
    /// This is typically generated from the content of the transcript by the AI service,
    /// but can be manually edited by the user.
    var title: String
    
    /// The original, unprocessed transcript from speech recognition.
    ///
    /// This contains the raw text as returned by the speech recognition service,
    /// including any filler words, repetitions, or grammatical errors.
    var originalTranscript: String
    
    /// The cleaned and formatted transcript after AI processing.
    ///
    /// This version has been processed to remove filler words, fix grammatical errors,
    /// and improve formatting for better readability.
    var cleanedTranscript: String
    
    /// The duration of the audio recording in seconds.
    ///
    /// This represents the length of the associated audio file.
    var duration: TimeInterval
    
    /// The date and time when the voice note was created.
    ///
    /// This is set to the current date and time by default when creating a new note.
    var creationDate: Date
    
    /// The filename of the associated audio recording.
    ///
    /// This is used to locate the audio file in the app's documents directory.
    var audioFilename: String
    
    /// The path to the note in the Obsidian vault, if it has been exported.
    ///
    /// This property is nil until the note has been successfully exported to Obsidian.
    var obsidianPath: String?
    
    /// The full URL to the audio recording file.
    ///
    /// This computed property constructs the URL to the audio file in the app's
    /// documents directory using the `audioFilename`. Returns nil if the documents
    /// directory cannot be accessed.
    ///
    /// - Returns: The URL to the audio file, or nil if unavailable
    var audioURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(audioFilename)
    }
    
    /// Creates a new voice note with the specified properties.
    ///
    /// This initializer creates a new voice note with the provided information.
    /// It provides default values for the `id` (a new UUID) and `creationDate` (current date/time),
    /// making those parameters optional.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the note. Defaults to a new UUID if not provided.
    ///   - title: The title of the voice note.
    ///   - originalTranscript: The raw transcript from speech recognition.
    ///   - cleanedTranscript: The processed transcript after AI cleaning.
    ///   - duration: The length of the audio recording in seconds.
    ///   - creationDate: The date and time when the note was created. Defaults to the current date/time.
    ///   - audioFilename: The filename of the associated audio recording.
    ///   - obsidianPath: The path to the note in Obsidian, if exported. Defaults to nil.
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

/// Extension providing sample data for SwiftUI previews and testing.
extension VoiceNote {
    /// A single sample voice note for use in previews and testing.
    ///
    /// This property provides a realistic example voice note with predefined content
    /// that can be used in SwiftUI previews or for testing purposes.
    ///
    /// - Returns: A sample voice note with meeting notes content
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
    
    /// An array of sample voice notes for use in previews and testing.
    ///
    /// This property provides a collection of different voice notes with varied content
    /// and creation dates, useful for previewing lists of notes or testing filtering and
    /// sorting functionality.
    ///
    /// - Returns: An array containing several sample voice notes with different content types
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
