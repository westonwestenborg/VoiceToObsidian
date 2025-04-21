import Foundation
import OSLog
import Combine

/// A manager for handling the user's custom words/phrases for transcription improvement.
///
/// This class is a singleton ObservableObject, providing persistence and reactivity for a list of custom words.
/// Words are persisted using the `@AppPreference` property wrapper, ensuring consistency with other app settings.
///
/// - Note: All changes are logged using OSLog for auditing and debugging.
@MainActor
final class CustomWordsManager: ObservableObject {
    /// The shared singleton instance for use throughout the app.
    static let shared = CustomWordsManager()

    /// The logger for custom word actions.
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "CustomWordsManager")

    /// The user's custom words/phrases.
    ///
    /// This array is persisted using AppPreference and published for SwiftUI reactivity.
    @AppPreference(wrappedValue: [], "CustomWordsList")
    private var storedWords: [String]

    /// The current list of custom words, updated as the user changes them.
    @Published private(set) var customWords: [String] = []

    /// Private initializer for singleton pattern. Loads words from storage.
    private init() {
        load()
    }

    /// Adds a new custom word or phrase to the list.
    /// - Parameter word: The word or phrase to add. Leading/trailing whitespace is trimmed.
    /// - Note: Duplicate or empty entries are ignored.
    func addWord(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !self.customWords.contains(trimmed) else { return }
        self.customWords.append(trimmed)
        save()
        logger.info("Added custom word: \(trimmed, privacy: .public)")
    }

    /// Updates an existing word at the specified index.
    /// - Parameters:
    ///   - index: The index of the word to update.
    ///   - newWord: The new word or phrase to replace the old one.
    /// - Note: Ignores invalid indices or empty replacements.
    func updateWord(at index: Int, with newWord: String) {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard self.customWords.indices.contains(index), !trimmed.isEmpty else { return }
        logger.info("Updated word at index \(index, privacy: .public) from \(self.customWords[index], privacy: .public) to \(trimmed, privacy: .public)")
        self.customWords[index] = trimmed
        save()
    }

    /// Removes words at the specified offsets.
    /// - Parameter offsets: The IndexSet of words to remove.
    func removeWord(at offsets: IndexSet) {
        for idx in offsets {
            if self.customWords.indices.contains(idx) {
                logger.info("Removed custom word: \(self.customWords[idx], privacy: .public)")
            }
        }
        self.customWords.remove(atOffsets: offsets)
        save()
    }

    /// Saves the current list of custom words to persistent storage.
    private func save() {
        self.storedWords = self.customWords
    }

    /// Loads the custom words from persistent storage.
    private func load() {
        self.customWords = self.storedWords
    }
}
