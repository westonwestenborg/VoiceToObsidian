# Research: Test Target Compilation Errors
Date: 2025-12-06

## Summary
The test target fails to compile due to three distinct issues:
1. TranscriptionManagerTests: Missing `await` for @MainActor property access
2. CustomWordsView.swift in test target: Missing FlexokiTheme dependencies
3. CustomWordsManager.swift: Cannot resolve `@AppPreference` property wrapper

The root cause is that **CustomWordsView.swift and CustomWordsManager.swift were incorrectly added to the test target** instead of only being in the main app target. This causes the test target to try to compile these files independently, without access to the main module's internal types.

## Key Files

### Issue 1: TranscriptionManagerTests async errors
- **Test file**: `VoiceToObsidianTests/TranscriptionManagerTests.swift`
- **Service file**: `VoiceToObsidian/Services/TranscriptionManager.swift:33-34` - `@MainActor class TranscriptionManager`

**Error locations**:
- Line 96: `let transcriptionManager = TranscriptionManager()` - initializer is @MainActor
- Line 99: `transcriptionManager.isTranscribing` - @MainActor property access
- Line 100: `transcriptionManager.transcriptionProgress` - @MainActor property access
- Line 105: `let transcriptionManager = TranscriptionManager()` - initializer is @MainActor
- Line 118: `transcriptionManager.cancelTranscription()` - @MainActor method call

**Fix**: Add `await` before each of these expressions since they cross @MainActor isolation boundaries in async test functions.

### Issue 2: FlexokiTheme access errors
- **FlexokiTheme**: `VoiceToObsidian/Extensions/FlexokiTheme.swift` - internal access (default)
- **SimpleFlexokiColors**: `VoiceToObsidian/Extensions/SimpleFlexokiColors.swift` - internal access (default)
- **CustomWordsView**: `VoiceToObsidian/Views/CustomWordsView.swift`

**Root cause**: CustomWordsView.swift is listed in the test target's Sources build phase (`project.pbxproj` line ~436). When compiling for the test target, FlexokiTheme and SimpleFlexokiColors are not included, causing "inaccessible" and "not found" errors.

**Fix options**:
1. **Recommended**: Remove CustomWordsView.swift from the test target Sources build phase
2. Alternative: Add FlexokiTheme.swift and SimpleFlexokiColors.swift to test target (not recommended - duplicates compilation)

### Issue 3: AppPreference property wrapper
- **Property wrapper**: `VoiceToObsidian/PropertyWrappers/AppPreferences.swift:64` - `struct AppPreference<T>`
- **Usage**: `VoiceToObsidian/Managers/CustomWordsManager.swift:22` - `@AppPreference(wrappedValue: [], "CustomWordsList")`

**Root cause**: CustomWordsManager.swift is listed in the test target's Sources build phase. When compiling independently for the test target, it cannot find `@AppPreference` because that property wrapper is only in the main module.

**Fix**: Remove CustomWordsManager.swift from the test target Sources build phase (same as Issue 2).

## Architecture Insights

The test target should NOT compile application source files directly. Instead it should:
1. Use `@testable import VoiceToObsidian` to access internal types from the main module
2. Only contain test files (files that test functionality)

Currently in `project.pbxproj`, the test target Sources phase (around line 431-440) includes:
- `CustomWordsView.swift` - Should be removed
- `CustomWordsManager.swift` - Should be removed
- `Documentation.docc` - Can remain for documentation tests

## Constraints & Considerations

1. **Xcode project changes**: Removing files from test target requires editing the `.xcodeproj/project.pbxproj` file
2. **Module boundaries**: The main app target compiles as `VoiceToObsidian` module, tests import it via `@testable import`
3. **@MainActor isolation**: Accessing @MainActor types from async contexts requires explicit `await`

## Recommended Fixes

### Fix 1: Remove incorrectly added files from test target (Xcode)
1. Open `VoiceToObsidian.xcodeproj` in Xcode
2. Select `VoiceToObsidianTests` target
3. Go to Build Phases > Compile Sources
4. Remove `CustomWordsView.swift` and `CustomWordsManager.swift`

### Fix 2: Add await keywords to TranscriptionManagerTests
```swift
// Line 96: Change
let transcriptionManager = TranscriptionManager()
// To
let transcriptionManager = await TranscriptionManager()

// Line 99-100: Change
#expect(transcriptionManager.isTranscribing == false)
#expect(transcriptionManager.transcriptionProgress == 0)
// To
#expect(await transcriptionManager.isTranscribing == false)
#expect(await transcriptionManager.transcriptionProgress == 0)

// Line 105: Change
let transcriptionManager = TranscriptionManager()
// To
let transcriptionManager = await TranscriptionManager()

// Line 118: Change
transcriptionManager.cancelTranscription()
// To
await transcriptionManager.cancelTranscription()
```

## Open Questions
1. Why were CustomWordsView.swift and CustomWordsManager.swift added to the test target? Was this intentional for some specific testing purpose, or an accidental drag-drop in Xcode?
2. Are there any CustomWords-specific tests that need to be written that would require these files?
