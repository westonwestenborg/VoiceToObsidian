# Research: Testing @MainActor Services in Swift 6

Date: 2025-12-06

## Summary

This research investigates testing patterns for `@MainActor`-isolated services (`RecordingManager`, `TranscriptionManager`) in Swift 6 strict concurrency mode. The analysis covers:
- Why current tests fail (runtime crashes from `nonisolated(unsafe)` mock properties)
- Patterns from passing tests (`AnthropicServiceTests`, `ObsidianServiceTests`)
- Swift 6 best practices for testing actor-isolated code
- Recommended testing strategies without refactoring production code

## Key Findings

### 1. Root Cause of Test Failures

The existing tests crash at runtime due to **actor isolation conflicts**:

```swift
// CURRENT FAILING PATTERN (IntegrationTests.swift)
class MockRecordingManager: RecordingManager {
    nonisolated(unsafe) var mockError: Error?  // CRASHES at runtime
}
```

**Why it crashes:**
1. `RecordingManager` is `@MainActor`-isolated
2. Mock properties use `nonisolated(unsafe)` to bypass compile-time checks
3. At runtime, Swift detects data races when accessing these properties from `@MainActor` context
4. The deinit of mocks also crashes due to isolation conflicts

### 2. Passing Test Patterns (What Works)

**AnthropicServiceTests** and **ObsidianServiceTests** pass because:

| Aspect | Passing Tests | Failing Tests |
|--------|---------------|---------------|
| Service Isolation | NOT `@MainActor` | `@MainActor` |
| Dependencies | Protocol-abstracted | Direct framework deps |
| Mocking Strategy | Inject via constructor | Subclass with `nonisolated(unsafe)` |
| Test Structure | Simple setup-execute-assert | Complex actor interactions |

#### Working Pattern: Protocol + Testable Subclass

```swift
// Step 1: Protocol for dependency
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// Step 2: Mock implementation (no @MainActor)
class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockError: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError { throw error }
        return (mockData!, HTTPURLResponse(...))
    }
}

// Step 3: Testable subclass with injection
class TestableAnthropicService: AnthropicService {
    var urlSession: URLSessionProtocol

    init(apiKey: String, urlSession: URLSessionProtocol) {
        self.urlSession = urlSession
        super.init(apiKey: apiKey)
    }
}

// Step 4: Test uses mock
@Test func testProcessTranscript() async throws {
    let mockSession = MockURLSession()
    mockSession.mockData = validResponseData
    let service = TestableAnthropicService(apiKey: "test", urlSession: mockSession)

    let result = try await service.processTranscriptAsync(transcript: "test")
    #expect(result == "expected")
}
```

### 3. Swift 6 @MainActor Testing Best Practices

#### Option A: Annotate Test Class as @MainActor (Xcode 16+)

```swift
@MainActor
final class RecordingManagerTests: XCTestCase {
    var sut: RecordingManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = RecordingManager()  // Works - test is on MainActor
    }

    func testRecordingState() async {
        #expect(sut.isRecording == false)
    }
}
```

#### Option B: Use Swift Testing with @MainActor Methods

```swift
struct RecordingManagerTests {
    @Test @MainActor
    func testInitialState() async {
        let manager = RecordingManager()
        #expect(manager.isRecording == false)
        #expect(manager.recordingDuration == 0)
    }
}
```

#### Option C: Protocol-Based Testing (No Production Changes)

For testing without modifying production code, test only the observable behavior:

```swift
@MainActor
struct RecordingManagerBehaviorTests {
    @Test
    func testInitialState() async {
        let manager = RecordingManager()
        #expect(manager.isRecording == false)
        #expect(manager.recordingDuration == 0)
    }

    @Test
    func testGetCurrentRecordingURLReturnsNilInitially() async {
        let manager = RecordingManager()
        #expect(manager.getCurrentRecordingURL() == nil)
    }

    @Test
    func testGetRecordingStartTimeReturnsNilInitially() async {
        let manager = RecordingManager()
        #expect(manager.getRecordingStartTime() == nil)
    }
}
```

### 4. RecordingManager Analysis

**File:** `VoiceToObsidian/Services/RecordingManager.swift`

#### Public API (Testable)

| Method/Property | Type | Testable Without Mocks |
|-----------------|------|------------------------|
| `isRecording` | `@Published Bool` | Yes (initial state) |
| `recordingDuration` | `@Published TimeInterval` | Yes (initial state) |
| `getCurrentRecordingURL()` | `URL?` | Yes (returns nil initially) |
| `getRecordingStartTime()` | `Date?` | Yes (returns nil initially) |
| `resetRecordingDuration()` | `Void` | Yes |
| `startRecordingAsync()` | `async throws -> Bool` | No (requires AVAudioSession) |
| `stopRecordingAsync()` | `async throws -> VoiceNote?` | No (requires active recording) |

#### Hard-to-Test Dependencies

- `AVAudioSession.sharedInstance()` - Singleton, requires device/simulator
- `AVAudioRecorder` - Requires actual audio session
- `CADisplayLink` - UI framework dependency
- `UIApplication.shared.beginBackgroundTask()` - UIKit dependency

#### State Machine Flow

```
IDLE (isRecording=false)
  │ startRecordingAsync()
  ↓
PERMISSION_CHECK
  │ Permission granted?
  ↓
SETUP_AUDIO_SESSION
  │ Session configured?
  ↓
RECORDING (isRecording=true)
  │ stopRecordingAsync()
  ↓
VERIFY_FILE
  │ File exists & size > 0?
  ↓
RETURN VoiceNote → IDLE
```

### 5. TranscriptionManager Analysis

**File:** `VoiceToObsidian/Services/TranscriptionManager.swift`

#### Public API (Testable)

| Method/Property | Type | Testable Without Mocks |
|-----------------|------|------------------------|
| `isTranscribing` | `@Published Bool` | Yes (initial state) |
| `transcriptionProgress` | `@Published Float` | Yes (initial state) |
| `transcribeAudioFileAsync(at:)` | `async throws -> String` | No (requires SFSpeechRecognizer) |
| `cancelTranscription()` | `Void` | Yes (safe to call anytime) |

#### Hard-to-Test Dependencies

- `SFSpeechRecognizer` - Requires device, authorization
- `SFSpeechRecognitionTask` - Callback-based API
- `SFSpeechURLRecognitionRequest` - Requires audio file

#### Pure Logic (Extractable for Testing)

```swift
// ContinuationState actor (lines 285-307) - testable in isolation
actor ContinuationState {
    var resumed = false
    func resume(with result: Result<String, Error>) async { ... }
    func hasResumed() -> Bool { ... }
}

// Error code classification (lines 357-375) - pure logic
switch nsError.code {
case 1: // Recognition failed
case 2: // Recognition canceled
case 1101: // No speech detected
}

// Timeout logic (lines 407-447) - testable with mocked clock
```

### 6. VoiceNoteCoordinator Workflows

**File:** `VoiceToObsidian/ViewModels/VoiceNoteCoordinator.swift`

#### Recording Workflow

```
startRecordingAsync()
  ├─ Guard: !isRecording && !isProcessing
  ├─ Reset recordingDuration = 0
  ├─ RecordingManager.startRecordingAsync()
  └─ Set isRecording = true

stopRecordingAsync()
  ├─ Guard: isRecording && !isProcessing
  ├─ Set isProcessing = true, isRecording = false
  ├─ RecordingManager.stopRecordingAsync() → VoiceNote
  └─ Queue processRecordingAsync()

processRecordingAsync()
  ├─ TranscriptionManager.transcribeAudioFileAsync() (2 retries)
  ├─ AnthropicService.processTranscriptWithTitleAsync() (optional)
  ├─ ObsidianService.createVoiceNoteFile() (optional)
  └─ VoiceNoteStore.updateVoiceNote()
```

#### Error Cases to Test

| Scenario | Expected Behavior |
|----------|-------------------|
| Microphone permission denied | Throw error, isRecording=false |
| File not created after stop | Throw error code 5 |
| Recording file empty | Throw error code 6 |
| Speech auth denied | Throw error code 1 |
| Transcription timeout (30s) | Use partial or return error |
| Already recording | Throw guard error |
| Already processing | Throw guard error |

### 7. Recommended Testing Strategy

#### Phase 1: Initial State Tests (No Mocking Required)

Test that services initialize with correct default state:

```swift
@MainActor
struct RecordingManagerInitialStateTests {
    @Test func isRecordingStartsFalse() async {
        let manager = RecordingManager()
        #expect(manager.isRecording == false)
    }

    @Test func recordingDurationStartsAtZero() async {
        let manager = RecordingManager()
        #expect(manager.recordingDuration == 0)
    }

    @Test func noCurrentRecordingURLInitially() async {
        let manager = RecordingManager()
        #expect(manager.getCurrentRecordingURL() == nil)
    }

    @Test func noRecordingStartTimeInitially() async {
        let manager = RecordingManager()
        #expect(manager.getRecordingStartTime() == nil)
    }

    @Test func resetRecordingDurationSetsToZero() async {
        let manager = RecordingManager()
        // Even if it's already 0, calling reset should be safe
        manager.resetRecordingDuration()
        #expect(manager.recordingDuration == 0)
    }
}

@MainActor
struct TranscriptionManagerInitialStateTests {
    @Test func isTranscribingStartsFalse() async {
        let manager = TranscriptionManager()
        #expect(manager.isTranscribing == false)
    }

    @Test func transcriptionProgressStartsAtZero() async {
        let manager = TranscriptionManager()
        #expect(manager.transcriptionProgress == 0)
    }

    @Test func cancelTranscriptionIsSafeWhenNotTranscribing() async {
        let manager = TranscriptionManager()
        // Should not crash when called without active transcription
        manager.cancelTranscription()
        #expect(manager.isTranscribing == false)
    }
}
```

#### Phase 2: Integration Tests (Simulator Required)

Test actual recording/transcription on simulator with real audio:

```swift
@MainActor
struct RecordingManagerIntegrationTests {
    @Test(.disabled("Requires simulator with microphone"))
    func recordingLifecycle() async throws {
        let manager = RecordingManager()

        // Start recording
        let started = try await manager.startRecordingAsync()
        #expect(started == true)
        #expect(manager.isRecording == true)

        // Wait for some recording time
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Stop recording
        let voiceNote = try await manager.stopRecordingAsync()
        #expect(voiceNote != nil)
        #expect(manager.isRecording == false)
        #expect(voiceNote!.duration > 0)
    }
}
```

#### Phase 3: Pure Logic Unit Tests (Extract and Test)

Extract pure logic into testable functions:

```swift
// Could extract from TranscriptionManager
enum TranscriptionErrorClassifier {
    static func isTemporaryError(_ error: NSError) -> Bool {
        guard error.domain == "kAFAssistantErrorDomain" else { return false }
        return error.code == 1101 || error.code == 1110
    }

    static func shouldUsePartialTranscript(
        error: Error?,
        partialTranscript: String,
        progress: Float
    ) -> Bool {
        guard error != nil else { return false }
        return !partialTranscript.isEmpty || progress > 0.1
    }
}

struct TranscriptionErrorClassifierTests {
    @Test func temporaryErrorCodes() {
        let error1101 = NSError(domain: "kAFAssistantErrorDomain", code: 1101)
        let error1110 = NSError(domain: "kAFAssistantErrorDomain", code: 1110)
        let errorOther = NSError(domain: "kAFAssistantErrorDomain", code: 999)

        #expect(TranscriptionErrorClassifier.isTemporaryError(error1101) == true)
        #expect(TranscriptionErrorClassifier.isTemporaryError(error1110) == true)
        #expect(TranscriptionErrorClassifier.isTemporaryError(errorOther) == false)
    }

    @Test func shouldUsePartialWithContent() {
        let error = NSError(domain: "test", code: 1)
        #expect(TranscriptionErrorClassifier.shouldUsePartialTranscript(
            error: error,
            partialTranscript: "Some text",
            progress: 0.0
        ) == true)
    }
}
```

### 8. Test File Structure Recommendation

```
VoiceToObsidianTests/
├── RecordingManagerTests.swift      # Initial state + integration tests
├── TranscriptionManagerTests.swift  # Initial state + integration tests
├── AnthropicServiceTests.swift      # ✓ Already working
├── ObsidianServiceTests.swift       # ✓ Already working
├── IntegrationTests.swift           # Full workflow tests (needs refactoring)
├── Helpers/
│   └── TestHelpers.swift            # @MainActor test utilities
└── PureLogic/
    ├── TranscriptionErrorTests.swift
    └── VoiceNoteCreationTests.swift
```

## Constraints & Considerations

1. **No Production Code Changes**: This strategy focuses on testing without modifying `RecordingManager` or `TranscriptionManager`
2. **Simulator Limitations**: Full recording/transcription tests require simulator with microphone permissions
3. **Swift 6 Strict Concurrency**: All tests must respect actor isolation boundaries
4. **Test Parallelism**: @MainActor tests run serially on main thread, may be slower

## Open Questions

1. **Protocol Injection**: Should we eventually refactor services to accept injected dependencies for better testability?
2. **UI Testing**: Should recording/transcription flows be tested via UI tests instead of unit tests?
3. **Test Coverage Goals**: What level of coverage is acceptable given framework dependencies?

## Recommendations

### Immediate Actions (No Code Changes)

1. **Replace failing mocks**: Remove `nonisolated(unsafe)` mock properties
2. **Add @MainActor to test classes**: Use `@MainActor final class` pattern
3. **Write initial state tests**: Test observable properties and safe methods
4. **Mark integration tests as disabled**: Use `@Test(.disabled())` for tests requiring simulator

### Future Improvements (Requires Planning)

1. **Extract pure logic**: Move error classification, progress calculation to testable functions
2. **Protocol abstraction**: Consider `AudioSessionProtocol`, `SpeechRecognizerProtocol` for better mocking
3. **Integration test suite**: Create dedicated suite for simulator-based testing

## Code Examples

### Working Test Pattern for @MainActor Services

```swift
import Testing
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

    // MARK: - Error Case Tests

    @Test func stopRecordingWhenNotRecordingThrows() async {
        let manager = RecordingManager()

        do {
            _ = try await manager.stopRecordingAsync()
            Issue.record("Expected error but got success")
        } catch {
            // Expected - no active recording
            #expect(error.localizedDescription.contains("No active recording") ||
                   error.localizedDescription.contains("recording"))
        }
    }
}

@MainActor
struct TranscriptionManagerTests {

    @Test func initialStateIsNotTranscribing() async {
        let manager = TranscriptionManager()
        #expect(manager.isTranscribing == false)
    }

    @Test func initialProgressIsZero() async {
        let manager = TranscriptionManager()
        #expect(manager.transcriptionProgress == 0)
    }

    @Test func cancelWhenNotTranscribingIsSafe() async {
        let manager = TranscriptionManager()
        manager.cancelTranscription()
        #expect(manager.isTranscribing == false)
    }

    @Test func transcribeNonexistentFileThrows() async {
        let manager = TranscriptionManager()
        let fakeURL = URL(fileURLWithPath: "/nonexistent/audio.m4a")

        do {
            _ = try await manager.transcribeAudioFileAsync(at: fakeURL)
            Issue.record("Expected error for nonexistent file")
        } catch {
            // Expected - file doesn't exist
            #expect(true)
        }
    }
}
```

## References

- Previous research: `thoughts/shared/research/test-runtime-failures-2025-12-06.md`
- Previous research: `thoughts/shared/research/test-compilation-errors-2025-12-06.md`
- Apple Documentation: [Adopting Swift 6](https://developer.apple.com/documentation/swift/adoptingswift6)
- Swift Testing: [Testing with Actors](https://developer.apple.com/documentation/testing)
