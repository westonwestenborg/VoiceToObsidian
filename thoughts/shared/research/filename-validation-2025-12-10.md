# Research: Filename Character Validation for Obsidian
Date: 2025-12-10

## Summary

The app currently uses LLM-generated titles directly as filenames without any sanitization. This creates a risk where invalid characters in titles can break file creation. This research documents the invalid characters for Obsidian and macOS, and identifies where validation should be added.

## Invalid Characters

### Obsidian Invalid Characters (as of v1.8.10)

**All platforms:** `* " / \ < > : | ? [ ] # ^ |`
- Filenames must NOT start with a dot (`.`)

**Platform-specific:**
| Platform | Additional Invalid Characters |
|----------|------------------------------|
| macOS/iOS/iPadOS/Linux | `\ / :` |
| Windows | `* " \ / : | ? < >` |
| Android | `\ / : * ?` |

**Most common problematic character:** `:` (colon) - especially from time-based titles like "Meeting: 10:30 AM"

### macOS Filesystem Characters

- **Truly invalid:** `/` (slash) and `\0` (null)
- **Effectively invalid:** `:` (colon) - macOS uses colon as internal path delimiter in HFS+/APFS
- In Finder: colon appears as slash (visual swap)
- In Terminal: slash cannot be used in filenames

### Recommended Character Set to Block

For maximum compatibility (especially with Obsidian Sync):
```
* " / \ < > : | ? [ ] # ^
```

Plus:
- Filenames should not start with `.`
- Filenames should be <= 255 characters (APFS limit)

## Key Files in the App

### 1. Title Generation (AnthropicService)

**File:** `VoiceToObsidian/Services/AnthropicService.swift`

- **Lines 286-409:** `processTranscriptWithTitleAsync(transcript:)` - Main method that calls Claude API
- **Lines 93-108:** `parseResponse(_ response: String)` - Extracts title from response
- **Line 98:** Title is trimmed but NOT sanitized
- **Lines 317-334:** Prompt asks Claude for "concise title (max 5-7 words)"

```swift
// Line 98 - only trimming, no sanitization
let title = titleContent.trimmingCharacters(in: .whitespacesAndNewlines)
```

### 2. Filename Construction (ObsidianService)

**File:** `VoiceToObsidian/Services/ObsidianService.swift`

- **Line 129:** Critical line where title becomes filename
```swift
let notePath = "Voice Notes/\(voiceNote.title).md"
```

- **Line 130:** Path appended to vault URL
- **Line 137:** File written to disk

**NO SANITIZATION EXISTS** between title generation and file creation.

### 3. Default Title Generation (RecordingManager)

**File:** `VoiceToObsidian/Services/RecordingManager.swift`

- **Line 340:** Default title format: `"Voice Note {timestamp}"`
- Uses `DateFormatUtil.shared.formatTimestamp()` which produces `YYYY-MM-DD HH:mm:ss`
- This format is **safe** (no invalid characters)

### 4. Title Update Flow (VoiceNoteCoordinator)

**File:** `VoiceToObsidian/ViewModels/VoiceNoteCoordinator.swift`

- **Line 752:** Title assigned from LLM response
```swift
processedVoiceNote.title = result.title
```

- **Line 785:** Note saved to Obsidian
```swift
ObsidianService.createVoiceNoteFile(for: processedVoiceNote)
```

## Architecture Insights

### Data Flow (where validation could be added)

```
1. Recording stops → Default safe title created
   └─ RecordingManager.swift:340

2. Transcript processed by Claude → LLM generates title (UNSAFE)
   └─ AnthropicService.swift:286-409

3. Title extracted from response → Trimmed only (NO VALIDATION)
   └─ AnthropicService.swift:93-108

4. VoiceNote.title updated → No validation
   └─ VoiceNoteCoordinator.swift:752

5. File created with title as filename → BREAKS if invalid chars
   └─ ObsidianService.swift:129-137
```

### Recommended Validation Points

**Option A: Sanitize at generation (AnthropicService)**
- Pros: Single point of control, title is clean from the start
- Cons: Mixes concerns (API service shouldn't know about filesystem)
- Location: `parseResponse()` at line 98

**Option B: Sanitize at file creation (ObsidianService)** ← RECOMMENDED
- Pros: Clear separation of concerns, defensive programming
- Cons: Title displayed to user may differ from filename
- Location: Before line 129

**Option C: Both (defense in depth)** ← SAFEST
- Sanitize in AnthropicService for clean user-facing title
- Sanitize again in ObsidianService as safety net

### Suggested Sanitization Function

```swift
extension String {
    /// Sanitizes a string for use as an Obsidian-compatible filename
    func sanitizedForFilename() -> String {
        // Characters invalid in Obsidian across all platforms
        let invalidCharacters = CharacterSet(charactersIn: "*\"/\\<>:|?[]#^")

        var sanitized = self.components(separatedBy: invalidCharacters).joined(separator: "-")

        // Remove leading dots (hidden files)
        while sanitized.hasPrefix(".") {
            sanitized = String(sanitized.dropFirst())
        }

        // Truncate to safe length (leaving room for .md extension)
        if sanitized.count > 250 {
            sanitized = String(sanitized.prefix(250))
        }

        // Fallback for empty result
        if sanitized.trimmingCharacters(in: .whitespaces).isEmpty {
            sanitized = "Untitled Note"
        }

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

## Test Coverage Gap

**Current tests do NOT cover:**
- Titles with colons (e.g., "Meeting: Project Review")
- Titles with slashes (e.g., "Q1/Q2 Planning")
- Titles with special characters (e.g., "What's Next?")
- Very long titles (> 255 characters)
- Titles starting with dots
- Empty titles

**Files to update:**
- `VoiceToObsidianTests/AnthropicServiceTests.swift`
- `VoiceToObsidianTests/ObsidianServiceTests.swift`

## Constraints & Considerations

1. **User expectation:** Users may want colons in displayed titles (e.g., "Meeting: Team Sync")
2. **Obsidian Sync:** Cross-platform sync requires stricter character set
3. **Existing notes:** Any notes already created with invalid characters may need migration
4. **Performance:** Sanitization is O(n) and negligible
5. **Prompt engineering:** Could also instruct Claude to avoid invalid characters in titles

## Open Questions

1. Should the displayed title (in app) match the filename exactly, or should we allow different values?
2. Should we add a prompt instruction telling Claude to avoid special characters in titles?
3. Should existing notes with problematic filenames be migrated/renamed?
4. What should the replacement character be: `-`, `_`, or just removal?

## Sources

- [Obsidian Forum: List of all forbidden filename characters](https://forum.obsidian.md/t/list-of-all-forbidden-filename-characters/103977)
- [Obsidian Forum: Valid characters for file names](https://forum.obsidian.md/t/valid-characters-for-file-names/55307)
- [macOS filename restrictions](https://ss64.com/mac/syntax-filenames.html)
- [Apple Community: Forbidden characters in file names](https://discussions.apple.com/thread/7870801)
- [GitHub: obsidian-safe-filename-linter plugin](https://github.com/sneakyfoxes/obsidian-safe-filename-linter)
