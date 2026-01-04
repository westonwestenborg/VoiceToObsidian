import Foundation
import AnyLanguageModel

/// Result from LLM transcript cleanup using AnyLanguageModel's Guided Generation.
/// Used for cloud providers (Claude, OpenAI, Gemini).
@Generable
struct TranscriptCleanupResult {
    @Guide(description: "A concise title for this voice note, 5-7 words maximum. Avoid special characters: : / \\ ? * \" < > | [ ] # ^")
    var title: String

    @Guide(description: "The cleaned transcript with filler words (um, uh, like, you know) removed, grammar fixed, and formatting improved for readability")
    var cleanedTranscript: String
}
