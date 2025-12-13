# Plan: Testing @MainActor Services

Date: 2025-12-06
Research: `thoughts/shared/research/testing-mainactor-services-2025-12-06.md`

## Overview

Add comprehensive tests for `RecordingManager` and `TranscriptionManager` - two `@MainActor`-isolated services that currently have placeholder test files. The goal is to maximize test coverage without modifying production code, following Swift 6 strict concurrency patterns.

**Current State:**
- `RecordingManagerTests.swift` - Empty placeholder (19 lines of comments)
- `TranscriptionManagerTests.swift` - Empty placeholder (19 lines of comments)
- All 21 existing tests pass
- Working test patterns exist in `AnthropicServiceTests.swift` and `ObsidianServiceTests.swift`

**Strategy:** Use `@MainActor` struct/class test patterns with Swift Testing framework to test:
1. Initial state verification
2. Safe method calls (methods that don't require external dependencies)
3. Error conditions (guard failures, invalid inputs)

## Implementation Phases

### Phase 1: RecordingManagerTests

**File:** `VoiceToObsidianTests/RecordingManagerTests.swift`

**Changes:** Replace placeholder with comprehensive initial state and safe method tests.

```swift
import Testing
import Foundation
@testable import VoiceToObsidian

@MainActor
struct RecordingManagerTests {

    // MARK: - Initial State Tests

    @Test func initialStateIsNotRecording() async {
        let manager = RecordingManager()
        #expect(manager.isRecording == false)
    }

    @Test func initialDurationIsZero() async {
        let manager = RecordingManager()
        #expect(manager.recordingDuration == 0)
    }

    @Test func initialRecordingURLIsNil() async {
        let manager = RecordingManager()
        #expect(manager.getCurrentRecordingURL() == nil)
    }

    @Test func initialStartTimeIsNil() async {
        let manager = RecordingManager()
        #expect(manager.getRecordingStartTime() == nil)
    }

    // MARK: - Safe Method Tests

    @Test func resetDurationSetsToZero() async {
        let manager = RecordingManager()
        manager.resetRecordingDuration()
        #expect(manager.recordingDuration == 0)
    }

    // MARK: - Error Condition Tests

    @Test func stopRecordingWhenNotRecordingThrows() async {
        let manager = RecordingManager()

        do {
            _ = try await manager.stopRecordingAsync()
            Issue.record("Expected error but got success")
        } catch {
            // Expected - should throw when not recording
            #expect(true)
        }
    }
}
```

**Verification:**
- [ ] Automated: `make test` - all tests pass
- [ ] Manual: Verify 6+ new RecordingManager tests appear in test output

---

### Phase 2: TranscriptionManagerTests

**File:** `VoiceToObsidianTests/TranscriptionManagerTests.swift`

**Changes:** Replace placeholder with comprehensive initial state and safe method tests.

```swift
import Testing
import Foundation
@testable import VoiceToObsidian

@MainActor
struct TranscriptionManagerTests {

    // MARK: - Initial State Tests

    @Test func initialStateIsNotTranscribing() async {
        let manager = TranscriptionManager()
        #expect(manager.isTranscribing == false)
    }

    @Test func initialProgressIsZero() async {
        let manager = TranscriptionManager()
        #expect(manager.transcriptionProgress == 0)
    }

    // MARK: - Safe Method Tests

    @Test func cancelWhenNotTranscribingIsSafe() async {
        let manager = TranscriptionManager()
        // Should not crash when called without active transcription
        manager.cancelTranscription()
        #expect(manager.isTranscribing == false)
    }

    // MARK: - Error Condition Tests

    @Test func transcribeNonexistentFileThrows() async {
        let manager = TranscriptionManager()
        let fakeURL = URL(fileURLWithPath: "/nonexistent/path/audio.m4a")

        do {
            _ = try await manager.transcribeAudioFileAsync(at: fakeURL)
            Issue.record("Expected error for nonexistent file")
        } catch {
            // Expected - file doesn't exist or speech not authorized
            #expect(true)
        }
    }
}
```

**Verification:**
- [ ] Automated: `make test` - all tests pass
- [ ] Manual: Verify 4+ new TranscriptionManager tests appear in test output

---

### Phase 3: Verify Complete Test Suite

**Actions:**
1. Run full test suite to confirm all tests pass
2. Review test output for proper test discovery
3. Ensure no runtime crashes (the original issue)

**Verification:**
- [ ] Automated: `make test` shows 25+ total tests passing (21 existing + 10+ new)
- [ ] Automated: No runtime crashes or actor isolation warnings
- [ ] Manual: Review test output shows all test suites: RecordingManagerTests, TranscriptionManagerTests, IntegrationTests, ObsidianServiceTests, AnthropicServiceTests, DateFormatUtilTests

## Success Criteria

- [ ] `RecordingManagerTests.swift` has 6+ working tests
- [ ] `TranscriptionManagerTests.swift` has 4+ working tests
- [ ] All tests pass with `make test`
- [ ] No `nonisolated(unsafe)` usage anywhere
- [ ] No production code changes required
- [ ] Tests run without actor isolation crashes

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `stopRecordingAsync()` behavior may vary | Catch any error type, just verify it throws |
| `transcribeAudioFileAsync()` may require auth | Catch any error type, test expects failure |
| New test struct isolation issues | Use `@MainActor struct` pattern from research |
| Test discovery issues with Swift Testing | Verify tests appear in xcodebuild output |

## Implementation Notes

1. **Use `struct` not `class`**: Swift Testing works better with structs for test suites
2. **All tests are `async`**: Required for @MainActor-isolated test bodies
3. **No `setUp/tearDown`**: Each test creates its own fresh instance
4. **Error tests are lenient**: We just verify errors are thrown, not specific error types (since behavior may depend on simulator state)

## Files Changed

| File | Action |
|------|--------|
| `VoiceToObsidianTests/RecordingManagerTests.swift` | Replace placeholder |
| `VoiceToObsidianTests/TranscriptionManagerTests.swift` | Replace placeholder |

## Test Count Summary

| Suite | Before | After |
|-------|--------|-------|
| RecordingManagerTests | 0 | 6+ |
| TranscriptionManagerTests | 0 | 4+ |
| IntegrationTests | 2 | 2 |
| ObsidianServiceTests | 6 | 6 |
| AnthropicServiceTests | 7 | 7 |
| DateFormatUtilTests | 5 | 5 |
| **Total** | **21** | **31+** |
