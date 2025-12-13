# Plan: Fix Test Runtime Failures

Date: 2025-12-06
Research: [test-runtime-failures-2025-12-06.md](../research/test-runtime-failures-2025-12-06.md)

## Overview

All 35 unit tests are failing at runtime with crashes (not assertion failures). Tests execute in 0.000 seconds and crash immediately. The root cause is **Swift actor isolation conflict** between `@MainActor`-isolated service classes and mock subclasses using `nonisolated(unsafe)` properties.

### Root Cause

```swift
// RecordingManager.swift:46
@MainActor
class RecordingManager: ObservableObject { ... }

// IntegrationTests.swift:8-11
class MockRecordingManager: RecordingManager {
    nonisolated(unsafe) var mockVoiceNote: VoiceNote?     // CRASH!
    nonisolated(unsafe) var mockStartRecordingResult = true // CRASH!
    nonisolated(unsafe) var mockError: Error?             // CRASH!
}
```

When `mockError` is accessed from `startRecordingAsync()` (which runs on `@MainActor`), Swift's runtime detects a data race and crashes.

### Affected Files

| File | Issue |
|------|-------|
| `IntegrationTests.swift` | `MockRecordingManager`, `MockTranscriptionManager` have `nonisolated(unsafe)` |
| `RecordingManagerTests.swift` | No mock subclasses of `@MainActor` services (OK) |
| `TranscriptionManagerTests.swift` | No problematic mocks (OK) |
| `AnthropicServiceTests.swift` | `AnthropicService` not `@MainActor` (OK) |
| `ObsidianServiceTests.swift` | `ObsidianService` not `@MainActor` (OK) |
| `DateFormatUtilTests.swift` | No mocks (OK) |
| `VoiceToObsidianTests.swift` | Aggregator that calls other tests |

## Implementation Phases

### Phase 1: Fix IntegrationTests Mock Classes

**Files:**
- `VoiceToObsidianTests/IntegrationTests.swift` - Lines 8-38

**Changes:**

Remove `nonisolated(unsafe)` from mock properties. Since these classes inherit from `@MainActor` classes, their properties should also be `@MainActor`-isolated:

```swift
// BEFORE (crashes)
class MockRecordingManager: RecordingManager {
    nonisolated(unsafe) var mockVoiceNote: VoiceNote?
    nonisolated(unsafe) var mockStartRecordingResult = true
    nonisolated(unsafe) var mockError: Error?
    ...
}

// AFTER (fixed)
class MockRecordingManager: RecordingManager {
    var mockVoiceNote: VoiceNote?
    var mockStartRecordingResult = true
    var mockError: Error?
    ...
}
```

Same fix for `MockTranscriptionManager`:

```swift
// BEFORE (crashes)
class MockTranscriptionManager: TranscriptionManager {
    nonisolated(unsafe) var mockTranscript: String?
    nonisolated(unsafe) var mockError: Error?
    ...
}

// AFTER (fixed)
class MockTranscriptionManager: TranscriptionManager {
    var mockTranscript: String?
    var mockError: Error?
    ...
}
```

**Verification:**
- [ ] Automated: `make test 2>&1 | grep -E "(PASS|FAIL|Failing tests)" | head -20`
- [ ] Manual: Verify IntegrationTests no longer crash at 0.000 seconds

### Phase 2: Verify Other Test Files

**Files:**
- `VoiceToObsidianTests/RecordingManagerTests.swift`
- `VoiceToObsidianTests/TranscriptionManagerTests.swift`
- `VoiceToObsidianTests/AnthropicServiceTests.swift`
- `VoiceToObsidianTests/ObsidianServiceTests.swift`
- `VoiceToObsidianTests/DateFormatUtilTests.swift`

**Changes:**

Based on research, these files do NOT subclass `@MainActor` services with `nonisolated(unsafe)` properties:

- `RecordingManagerTests.swift` - Uses `MockAVAudioRecorder` (subclasses AVAudioRecorder, not MainActor)
- `TranscriptionManagerTests.swift` - Uses `MockSFSpeechRecognizer` (subclasses SFSpeechRecognizer, not MainActor)
- `AnthropicServiceTests.swift` - Uses `TestableAnthropicService` (AnthropicService is not @MainActor)
- `ObsidianServiceTests.swift` - Uses `TestableObsidianService` (ObsidianService is not @MainActor)
- `DateFormatUtilTests.swift` - No mocks at all

**Verification:**
- [ ] Automated: Run `make test` and check all test suites pass
- [ ] Manual: Verify tests execute for > 0.000 seconds (actual execution)

### Phase 3: Run Full Test Suite and Fix Any Remaining Issues

**Files:**
- Potentially any test file if failures remain

**Changes:**

After Phase 1-2, run the full test suite. If any tests still fail:
1. Check for assertion failures (actual test logic issues)
2. Check for additional actor isolation issues
3. Fix as needed

**Verification:**
- [ ] Automated: `make test` passes with 0 failures
- [ ] Manual: Review test output for any warnings or issues

## Success Criteria

- [ ] All 35 tests pass (currently 35 failing)
- [ ] Tests execute in > 0.000 seconds (indicates actual execution)
- [ ] No runtime crashes in test execution
- [ ] No actor isolation warnings during compilation

## Risks & Mitigations

- **Risk**: Removing `nonisolated(unsafe)` might cause compilation errors if properties are accessed from non-MainActor context
  - **Mitigation**: Properties are only accessed from overridden async methods that run on MainActor anyway

- **Risk**: Some tests might fail with actual assertion failures once they can execute
  - **Mitigation**: These are logic bugs, not structural issues - fix in Phase 3

- **Risk**: Tests might have been written incorrectly and never actually worked
  - **Mitigation**: Research shows tests were added in April 2025 with `nonisolated(unsafe)` from the start - they may have never passed

## Estimated Effort

- **Phase 1**: 5 minutes (simple find-replace)
- **Phase 2**: 5 minutes (verification only)
- **Phase 3**: Variable (depends on remaining failures)

## Implementation Notes

The fix is minimal - just remove `nonisolated(unsafe)` from 5 property declarations in `IntegrationTests.swift`. The properties will inherit the `@MainActor` isolation from their parent class, which matches how they're actually used.
