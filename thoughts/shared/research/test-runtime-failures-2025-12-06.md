# Research: Test Runtime Failures

Date: 2025-12-06

## Summary

All unit tests are failing at runtime with crashes, not assertion failures. The root cause is a **Swift actor isolation conflict** between the `@MainActor`-isolated service classes and the mock subclasses using `nonisolated(unsafe)` properties. The tests compile but crash during execution when accessing mock properties from the wrong isolation context.

## Root Cause Analysis

### The Crash Pattern

All test suites crash with the same error:
```
Crash: VoiceToObsidian (6343) MockRecordingManager.mockError.getter
```

### Why It Crashes

1. **Base Class**: `RecordingManager` is marked `@MainActor` (line 46 of `RecordingManager.swift`)
   ```swift
   @MainActor
   class RecordingManager: ObservableObject { ... }
   ```

2. **Mock Class**: `MockRecordingManager` inherits from `RecordingManager` and uses `nonisolated(unsafe)`:
   ```swift
   class MockRecordingManager: RecordingManager {
       nonisolated(unsafe) var mockVoiceNote: VoiceNote?
       nonisolated(unsafe) var mockStartRecordingResult = true
       nonisolated(unsafe) var mockError: Error?  // <-- Crashes here
   ```

3. **The Conflict**: When test code accesses `mockError` from the overridden methods (which run in MainActor context), Swift's runtime detects a data race:
   - The property is declared `nonisolated(unsafe)` (opt-out of isolation)
   - But the methods access it from `@MainActor` context
   - Runtime concurrency checking catches this violation and crashes

### Same Issue Affects Multiple Mocks

| Mock Class | Base Class | Same Issue? |
|------------|------------|-------------|
| `MockRecordingManager` | `RecordingManager` (`@MainActor`) | YES |
| `MockTranscriptionManager` | `TranscriptionManager` (`@MainActor`) | YES |
| `MockAnthropicService` | `AnthropicService` (non-isolated) | NO |
| `MockObsidianService` | `ObsidianService` (non-isolated) | NO |

## Key Files

### Test Files
- `VoiceToObsidianTests/IntegrationTests.swift:8-26` - MockRecordingManager definition
- `VoiceToObsidianTests/IntegrationTests.swift:28-38` - MockTranscriptionManager definition
- `VoiceToObsidianTests/TranscriptionManagerTests.swift` - Additional mock classes
- `VoiceToObsidianTests/RecordingManagerTests.swift` - More mock classes
- `VoiceToObsidianTests/VoiceToObsidianTests.swift` - Aggregator that calls all test suites

### Service Implementations
- `VoiceToObsidian/Services/RecordingManager.swift:46` - `@MainActor class RecordingManager`
- `VoiceToObsidian/Services/TranscriptionManager.swift` - `@MainActor class TranscriptionManager`
- `VoiceToObsidian/Services/AnthropicService.swift` - Non-isolated class
- `VoiceToObsidian/Services/ObsidianService.swift` - Non-isolated class

## Architecture Insights

### Service Isolation Model
```
@MainActor isolated:
├── RecordingManager (UI-bound, publishes state)
├── TranscriptionManager (UI-bound, publishes progress)
└── CustomWordsManager (singleton, publishes words)

Non-isolated:
├── AnthropicService (network calls)
└── ObsidianService (file operations)
```

### Test Framework
- Uses Swift Testing (`import Testing`) not XCTest
- Tests use `@Test` attribute and `#expect()` assertions
- Mock classes attempt to subclass real services

## Constraints & Considerations

1. **Swift 6 Strict Concurrency**: The project likely has strict concurrency checking enabled, which validates actor isolation at runtime.

2. **Subclassing @MainActor Classes**: When subclassing a `@MainActor` class:
   - All stored properties are automatically MainActor-isolated
   - Using `nonisolated(unsafe)` on properties creates runtime crashes
   - The subclass inherits the actor isolation

3. **Mock Patterns That Don't Work**:
   ```swift
   // BAD: Will crash at runtime
   class MockRecordingManager: RecordingManager {
       nonisolated(unsafe) var mockError: Error?  // Data race!
   }
   ```

4. **Mock Patterns That Work**:
   ```swift
   // OPTION 1: Keep properties MainActor-isolated
   @MainActor
   class MockRecordingManager: RecordingManager {
       var mockError: Error?  // Naturally isolated
   }

   // OPTION 2: Use protocol-based mocking
   protocol RecordingManagerProtocol {
       func startRecordingAsync() async throws -> Bool
       func stopRecordingAsync() async throws -> VoiceNote?
   }

   class MockRecordingManager: RecordingManagerProtocol {
       var mockError: Error?  // No actor isolation needed
   }
   ```

## Git History Context

- **Tests Added**: April 12, 2025 (commit `e9a354e`)
  - All 7 test files added with 1,605 lines
  - Commit message: "Add comprehensive unit tests for core functionality"

- **Concurrency Fix**: April 13, 2025 (commit `e161fbf`)
  - TranscriptionManagerTests modified
  - Commit message: "Fix Swift concurrency issues in TranscriptionManager and related components"
  - This fix addressed some issues but the `nonisolated(unsafe)` pattern remained

- **No Test Changes Since**: Tests haven't been modified since April 2025

## Open Questions

1. **Were tests ever passing?** The `nonisolated(unsafe)` pattern suggests tests were written when concurrency checking was less strict, or they never passed runtime execution.

2. **Is protocol-based mocking preferred?** Refactoring to use protocols would be a larger change but more robust.

3. **Scope of fix**: Should we fix just the crashing tests or rewrite the entire test suite?

## Recommendations

### Option A: Quick Fix (Remove `nonisolated(unsafe)`)
- Remove `nonisolated(unsafe)` from mock properties
- Let properties inherit MainActor isolation
- Ensure tests access properties from MainActor context

**Pros**: Minimal code change
**Cons**: Tests must use `await` for property access

### Option B: Protocol-Based Mocks (Recommended)
- Extract protocols from service classes
- Create mock implementations of protocols
- Inject dependencies in production code

**Pros**: Clean separation, no actor conflicts, more testable
**Cons**: Requires refactoring production code

### Option C: Delete and Rewrite Tests
- Remove current failing tests
- Write new tests using protocol-based approach
- Focus on testable, non-actor-isolated logic first

**Pros**: Fresh start, modern patterns
**Cons**: Time-consuming, risk of reduced coverage

## Immediate Next Steps

1. **Quick Win**: Remove `nonisolated(unsafe)` from IntegrationTests.swift mocks
2. **Verify**: Run single test to confirm fix works
3. **Iterate**: Apply same fix to other test files
4. **Long-term**: Consider protocol-based mocking for better architecture
