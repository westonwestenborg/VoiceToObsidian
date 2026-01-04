import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Result from LLM transcript cleanup using Apple's native Guided Generation.
/// Used for Apple Intelligence (on-device processing).
///
/// This struct is in a separate file to avoid type ambiguity between
/// AnyLanguageModel and FoundationModels frameworks.
@available(iOS 26.0, *)
@Generable
struct NativeTranscriptCleanupResult {
    @Guide(description: "A concise title for this voice note, 5-7 words maximum. Avoid special characters: : / \\ ? * \" < > | [ ] # ^")
    let title: String

    @Guide(description: "The cleaned transcript with filler words (um, uh, like, you know) removed, grammar fixed, and formatting improved for readability")
    let cleanedTranscript: String
}
#endif
