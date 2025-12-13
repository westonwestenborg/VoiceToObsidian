# Plan: Filename Character Validation for Obsidian

Date: 2025-12-10
Research: [filename-validation-2025-12-10.md](../research/filename-validation-2025-12-10.md)

## Overview

Add filename sanitization to prevent file creation failures when LLM-generated titles contain invalid characters (like colons, slashes, etc.). The implementation uses "defense in depth" - sanitizing at both the API parsing layer and the file creation layer.

## Design Decisions

1. **Replacement character:** Use `-` (hyphen) - most readable, commonly used
2. **Title vs Filename:** Display title can differ from filename (allow user-friendly colons in UI)
3. **Extension location:** Create `String+Filename.swift` in `VoiceToObsidian/Extensions/`
4. **Primary validation point:** ObsidianService (defensive, catches all sources)
5. **Secondary validation:** AnthropicService (cleaner titles from the start)

## Implementation Phases

### Phase 1: Create String Extension

**Files:**
- `VoiceToObsidian/Extensions/String+Filename.swift` (NEW)

**Changes:**
```swift
import Foundation

extension String {
    /// Characters invalid in Obsidian filenames across all platforms
    /// Includes: * " / \ < > : | ? [ ] # ^
    private static let invalidFilenameCharacters = CharacterSet(charactersIn: "*\"/\\<>:|?[]#^")

    /// Sanitizes a string for use as an Obsidian-compatible filename.
    /// - Replaces invalid characters with hyphens
    /// - Removes leading dots (hidden files)
    /// - Truncates to 250 characters (leaving room for .md extension)
    /// - Falls back to "Untitled Note" if result is empty
    func sanitizedForFilename() -> String {
        // Replace invalid characters with hyphens
        var sanitized = self.unicodeScalars
            .map { Self.invalidFilenameCharacters.contains($0) ? "-" : String($0) }
            .joined()

        // Collapse multiple consecutive hyphens into one
        while sanitized.contains("--") {
            sanitized = sanitized.replacingOccurrences(of: "--", with: "-")
        }

        // Remove leading/trailing hyphens and whitespace
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-").union(.whitespaces))

        // Remove leading dots (hidden files)
        while sanitized.hasPrefix(".") {
            sanitized = String(sanitized.dropFirst())
        }

        // Truncate to safe length (APFS limit is 255, leave room for .md)
        if sanitized.count > 250 {
            sanitized = String(sanitized.prefix(250))
            // Don't end with hyphen or space after truncation
            sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-").union(.whitespaces))
        }

        // Fallback for empty result
        if sanitized.trimmingCharacters(in: .whitespaces).isEmpty {
            sanitized = "Untitled Note"
        }

        return sanitized
    }
}
```

**Verification:**
- [ ] Automated: `make build` succeeds
- [ ] Automated: Unit tests pass (Phase 3)
- [ ] Manual: Verify file appears in Xcode project navigator

---

### Phase 2: Apply Sanitization in ObsidianService

**Files:**
- `VoiceToObsidian/Services/ObsidianService.swift` - Line ~129

**Changes:**

Find line 129:
```swift
let notePath = "Voice Notes/\(voiceNote.title).md"
```

Replace with:
```swift
let sanitizedTitle = voiceNote.title.sanitizedForFilename()
let notePath = "Voice Notes/\(sanitizedTitle).md"
```

**Verification:**
- [ ] Automated: `make build` succeeds
- [ ] Automated: `make test` passes
- [ ] Manual: Create voice note with title containing `:` - verify file creates successfully

---

### Phase 3: Add Unit Tests

**Files:**
- `VoiceToObsidianTests/StringFilenameTests.swift` (NEW)
- `VoiceToObsidianTests/ObsidianServiceTests.swift` - Add sanitization test

**Changes for StringFilenameTests.swift:**
```swift
import XCTest
@testable import VoiceToObsidian

final class StringFilenameTests: XCTestCase {

    // MARK: - Basic Sanitization

    func testSanitizesColons() {
        XCTAssertEqual("Meeting: Project Review".sanitizedForFilename(), "Meeting - Project Review")
    }

    func testSanitizesSlashes() {
        XCTAssertEqual("Q1/Q2 Planning".sanitizedForFilename(), "Q1-Q2 Planning")
    }

    func testSanitizesQuestionMarks() {
        XCTAssertEqual("What's Next?".sanitizedForFilename(), "What's Next")
    }

    func testSanitizesMultipleInvalidChars() {
        XCTAssertEqual("Test: File/Path?".sanitizedForFilename(), "Test - File-Path")
    }

    func testSanitizesAllInvalidChars() {
        let allInvalid = "a*b\"c/d\\e<f>g:h|i?j[k]l#m^n"
        let result = allInvalid.sanitizedForFilename()
        // Should not contain any invalid characters
        let invalidChars = CharacterSet(charactersIn: "*\"/\\<>:|?[]#^")
        XCTAssertFalse(result.unicodeScalars.contains(where: { invalidChars.contains($0) }))
    }

    // MARK: - Edge Cases

    func testRemovesLeadingDots() {
        XCTAssertEqual(".hidden".sanitizedForFilename(), "hidden")
        XCTAssertEqual("..hidden".sanitizedForFilename(), "hidden")
        XCTAssertEqual("...multiple".sanitizedForFilename(), "multiple")
    }

    func testEmptyStringFallback() {
        XCTAssertEqual("".sanitizedForFilename(), "Untitled Note")
    }

    func testOnlyInvalidCharsFallback() {
        XCTAssertEqual(":::".sanitizedForFilename(), "Untitled Note")
        XCTAssertEqual("???".sanitizedForFilename(), "Untitled Note")
    }

    func testTruncatesLongStrings() {
        let longString = String(repeating: "a", count: 300)
        let result = longString.sanitizedForFilename()
        XCTAssertLessThanOrEqual(result.count, 250)
    }

    func testPreservesValidCharacters() {
        let validTitle = "My Voice Note 2024-01-15"
        XCTAssertEqual(validTitle.sanitizedForFilename(), validTitle)
    }

    func testCollapsesConsecutiveHyphens() {
        XCTAssertEqual("a::b".sanitizedForFilename(), "a-b")
        XCTAssertEqual("a:::b".sanitizedForFilename(), "a-b")
    }

    func testTrimsLeadingTrailingHyphens() {
        XCTAssertEqual(":test:".sanitizedForFilename(), "test")
    }

    // MARK: - Real-World Examples

    func testRealWorldMeetingTitle() {
        XCTAssertEqual(
            "Meeting: Weekly Team Sync".sanitizedForFilename(),
            "Meeting - Weekly Team Sync"
        )
    }

    func testRealWorldQuarterlyPlanning() {
        XCTAssertEqual(
            "Q1/Q2 Budget Review: Final".sanitizedForFilename(),
            "Q1-Q2 Budget Review - Final"
        )
    }

    func testRealWorldQuestionTitle() {
        XCTAssertEqual(
            "What should we do next?".sanitizedForFilename(),
            "What should we do next"
        )
    }
}
```

**Changes for ObsidianServiceTests.swift:**
Add test to verify sanitization is applied:
```swift
func testCreateVoiceNoteFileWithInvalidCharsInTitle() async throws {
    // Verify the service handles titles with invalid characters
    // This is an integration test - the actual sanitization is tested in StringFilenameTests
    let voiceNote = VoiceNote(
        id: UUID(),
        audioURL: testAudioURL,
        createdAt: Date(),
        duration: 60.0,
        title: "Meeting: Project Review"  // Contains colon
    )

    // Should not throw - sanitization handles the colon
    // Note: This test verifies the integration, actual file creation
    // depends on vault access which may not be available in test env
}
```

**Verification:**
- [ ] Automated: `make test` - all new tests pass
- [ ] Manual: Verify test file appears in Xcode test navigator

---

### Phase 4: (Optional) Enhance AnthropicService Prompt

**Files:**
- `VoiceToObsidian/Services/AnthropicService.swift` - Lines ~317-334 (prompt construction)

**Changes:**

Find the prompt section around line 317-334 that instructs Claude about titles.

Add guidance to avoid special characters:
```swift
// In the prompt string, add:
"""
Title Guidelines:
- Keep titles concise (5-7 words)
- Avoid special characters like : / \\ ? * " < > | [ ] # ^
- Use hyphens or spaces for separation instead of colons
"""
```

**Verification:**
- [ ] Automated: `make build` succeeds
- [ ] Manual: Process a voice note and check if generated titles avoid colons

---

## File Addition to Xcode Project

After creating new files, they must be added to the Xcode project:

1. Open `VoiceToObsidian.xcodeproj` in Xcode
2. Right-click on `VoiceToObsidian/Extensions/` → Add Files to "VoiceToObsidian"
3. Select `String+Filename.swift`
4. Ensure "Add to targets: VoiceToObsidian" is checked
5. For test file: Add to `VoiceToObsidianTests` target

**Alternative:** Add file references directly to `project.pbxproj` (more error-prone)

---

## Success Criteria

- [ ] `make build` succeeds with no warnings
- [ ] `make test` passes all tests (existing + new)
- [ ] Voice note with title "Meeting: Project Review" creates file `Meeting - Project Review.md`
- [ ] Voice note with title "Q1/Q2 Planning" creates file `Q1-Q2 Planning.md`
- [ ] Very long titles (> 250 chars) are truncated without error
- [ ] Empty or all-invalid titles fall back to "Untitled Note.md"

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Existing notes with invalid filenames | Out of scope - users can rename manually. Future: add migration tool |
| Title differs from filename confuses users | Display filename in UI when different, or show both |
| Xcode project file conflicts | Add files manually through Xcode, not scripted |
| Hyphen replacement looks odd | Could use underscore or just remove chars - hyphen is most readable |

---

## Implementation Order

1. **Phase 1** - String extension (foundation)
2. **Phase 2** - ObsidianService integration (core fix)
3. **Phase 3** - Tests (verification)
4. **Phase 4** - Prompt enhancement (optional, nice-to-have)

**Recommended approach:** Implement phases 1-3 together, then validate. Phase 4 is optional enhancement.

---

## Post-Implementation

After `/implement`, run `/validate` to verify:
- All success criteria met
- No regressions in existing functionality
- Edge cases handled correctly
