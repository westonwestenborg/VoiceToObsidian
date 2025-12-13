# Plan: Multi-Provider LLM Integration

Date: 2025-12-12
Research: thoughts/shared/research/multi-provider-llm-integration-2025-12-12.md

## Progress

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1 | ✅ COMPLETE | AnyLanguageModel added (local copy with fix), iOS 26 target |
| Phase 2 | ✅ COMPLETE | LLMProvider.swift created with all provider types |
| Phase 3 | ✅ COMPLETE | LLMService.swift created with unified provider interface |
| Phase 4 | ✅ COMPLETE | LLMError already added in Phase 3, both error types coexist during transition |
| Phase 5 | ✅ COMPLETE | VoiceNoteCoordinator updated to use LLMService |
| Phase 6 | 🔲 PENDING | Update Settings UI |
| Phase 7 | 🔲 PENDING | Update tests |
| Phase 8 | 🔲 PENDING | Delete old files & cleanup |

## Overview

Replace the hardcoded Anthropic Claude integration with a flexible provider selection system supporting:
- **Apple Foundation Models** (default, free, on-device, iOS 26+)
- **Anthropic Claude** (API key required)
- **OpenAI** (API key required)
- **Google Gemini** (API key required)

### Key Decisions (from research)
1. **iOS Version**: Raise minimum deployment target to iOS 26
2. **Library**: Use **AnyLanguageModel** SPM package for unified API
3. **Default**: Foundation Models as default, user can select cloud providers
4. **Model Selection**: Simple provider picker, with optional model selection
5. **Migration**: Don't preserve existing user configuration

## Implementation Phases

---

### Phase 1: Add AnyLanguageModel Dependency & Update iOS Target ✅ COMPLETE

**Goal**: Add the SPM dependency and update deployment target to iOS 26.

**Files:**
- `VoiceToObsidian.xcodeproj/project.pbxproj` - Add SPM package reference, update iOS deployment target

**Changes:**

1. Add SPM dependency via Xcode:
   - Package URL: `https://github.com/mattt/AnyLanguageModel.git`
   - Version: `from: "0.4.0"`

2. Update deployment target:
   - Change `IPHONEOS_DEPLOYMENT_TARGET` from `18.2` to `26.0`

**Verification:**
- [x] Automated: `make build` succeeds
- [x] Manual: Verify package appears in Xcode's Package Dependencies

**Completion Notes (2025-12-12):**

Due to a bug in AnyLanguageModel v0.5.0 (missing iOS availability annotations), we use a **local patched copy**:

- **Location**: `LocalPackages/AnyLanguageModel/`
- **Fix applied**: Added `iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0` to 4 `@available` annotations in `Sources/AnyLanguageModel/Models/SystemLanguageModel.swift` (lines 320, 347, 354, 361)
- **PR submitted**: https://github.com/mattt/AnyLanguageModel/pull/63

Additional changes:
- `Makefile` updated to use `iPhone 17 Pro` simulator (iOS 26 simulators don't have iPhone 16)

---

### Phase 2: Create LLM Provider Types & Configuration

**Goal**: Create provider enum, model configuration, and storage for provider selection.

**Files:**
- `VoiceToObsidian/Models/LLMProvider.swift` - NEW: Provider enum and model configuration
- `VoiceToObsidian/PropertyWrappers/AppPreferences.swift` - Add `selectedLLMProvider` preference

**Changes:**

**New file: `LLMProvider.swift`**
```swift
import Foundation

/// Available LLM providers for transcript processing
enum LLMProvider: String, CaseIterable, Codable, Identifiable {
    case foundationModels = "foundation_models"
    case anthropic = "anthropic"
    case openai = "openai"
    case gemini = "gemini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .foundationModels: return "Apple Intelligence"
        case .anthropic: return "Claude (Anthropic)"
        case .openai: return "OpenAI"
        case .gemini: return "Gemini (Google)"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .foundationModels: return false
        case .anthropic, .openai, .gemini: return true
        }
    }

    /// Default model for each provider
    var defaultModel: String {
        switch self {
        case .foundationModels: return "default"
        case .anthropic: return "claude-sonnet-4-5-20250929"
        case .openai: return "gpt-4o"
        case .gemini: return "gemini-2.0-flash"
        }
    }

    /// Available models for each provider
    var availableModels: [String] {
        switch self {
        case .foundationModels: return ["default"]
        case .anthropic: return ["claude-sonnet-4-5-20250929", "claude-haiku-3-5-20240307"]
        case .openai: return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo"]
        case .gemini: return ["gemini-2.0-flash", "gemini-1.5-pro", "gemini-1.5-flash"]
        }
    }
}
```

**Verification:**
- [x] Automated: `make build` succeeds
- [x] Manual: Verify enum compiles with all cases

**Completion Notes (2025-12-12):**
- Created `VoiceToObsidian/Models/LLMProvider.swift` with all provider cases
- Added file to Xcode project (project.pbxproj)
- Build passes: `make build` ✅
- Tests pass: `make test` ✅ (44/44)

---

### Phase 3: Create LLMService Protocol & Implementations

**Goal**: Create unified service protocol and implement providers using AnyLanguageModel.

**Files:**
- `VoiceToObsidian/Services/LLMService.swift` - NEW: Main service using AnyLanguageModel
- `VoiceToObsidian/Services/AnthropicService.swift` - DELETE (replaced by LLMService)

**Changes:**

**New file: `LLMService.swift`**
```swift
import Foundation
import OSLog
import AnyLanguageModel // Uses unified API

/// Result from LLM processing
struct LLMProcessingResult {
    let transcript: String
    let title: String
}

/// Service for processing transcripts with multiple LLM providers
@MainActor
class LLMService {
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "LLMService")

    // API keys for cloud providers
    private var anthropicAPIKey: String = ""
    private var openAIAPIKey: String = ""
    private var geminiAPIKey: String = ""

    // Current provider and model
    private var currentProvider: LLMProvider = .foundationModels
    private var currentModel: String = ""

    init() {
        logger.debug("LLMService initialized")
    }

    // MARK: - Configuration

    func updateProvider(_ provider: LLMProvider) {
        currentProvider = provider
        currentModel = provider.defaultModel
        logger.debug("Provider updated to: \(provider.displayName)")
    }

    func updateModel(_ model: String) {
        currentModel = model
        logger.debug("Model updated to: \(model)")
    }

    func updateAnthropicAPIKey(_ key: String) {
        anthropicAPIKey = key
    }

    func updateOpenAIAPIKey(_ key: String) {
        openAIAPIKey = key
    }

    func updateGeminiAPIKey(_ key: String) {
        geminiAPIKey = key
    }

    // MARK: - Foundation Models Availability

    var isFoundationModelsAvailable: Bool {
        // Check if Foundation Models is available on this device
        // Uses AnyLanguageModel's SystemLanguageModel availability check
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        return false
    }

    // MARK: - Processing

    func processTranscriptWithTitle(
        transcript: String,
        customWords: [String]
    ) async throws -> LLMProcessingResult {
        logger.debug("Processing transcript with provider: \(currentProvider.displayName)")

        let prompt = buildPrompt(transcript: transcript, customWords: customWords)
        let response = try await sendRequest(prompt: prompt)
        return parseResponse(response)
    }

    // MARK: - Private Methods

    private func buildPrompt(transcript: String, customWords: [String]) -> String {
        let customWordsSection = !customWords.isEmpty ? """
        The voice-to-text model we use makes errors. This is a list of common words the speaker uses, please replace them when you are cleaning up the transcript if you think they are a better fit: \(customWords.joined(separator: ", "))

        """ : ""

        return """
        I have a voice memo transcript that needs to be cleaned up. Please:

        1. Remove filler words (um, uh, like, etc.)
        2. Fix any grammatical errors or repetitions
        3. Format the text in a clear, readable way
        4. Suggest a concise title for this note (max 5-7 words)
           - Avoid special characters: : / \\ ? * " < > | [ ] # ^
           - Use hyphens or spaces for separation instead of colons

        \(customWordsSection)Original transcript:
        \(transcript)

        Please respond in the following format:

        TITLE: [Your suggested title]

        CLEANED TRANSCRIPT:
        [The cleaned up transcript]
        """
    }

    private func sendRequest(prompt: String) async throws -> String {
        let model = try createLanguageModel()
        let session = LanguageModelSession(model: model)
        let response = try await session.respond(to: prompt)
        return response.content
    }

    private func createLanguageModel() throws -> any LanguageModel {
        switch currentProvider {
        case .foundationModels:
            guard isFoundationModelsAvailable else {
                throw AppError.llm(.providerUnavailable("Apple Intelligence is not available on this device"))
            }
            return SystemLanguageModel.default

        case .anthropic:
            guard !anthropicAPIKey.isEmpty else {
                throw AppError.llm(.apiKeyMissing)
            }
            return AnthropicLanguageModel(
                apiKey: anthropicAPIKey,
                model: currentModel
            )

        case .openai:
            guard !openAIAPIKey.isEmpty else {
                throw AppError.llm(.apiKeyMissing)
            }
            return OpenAILanguageModel(
                apiKey: openAIAPIKey,
                model: currentModel
            )

        case .gemini:
            guard !geminiAPIKey.isEmpty else {
                throw AppError.llm(.apiKeyMissing)
            }
            return GeminiLanguageModel(
                apiKey: geminiAPIKey,
                model: currentModel
            )
        }
    }

    private func parseResponse(_ response: String) -> LLMProcessingResult {
        var title: String? = nil
        var cleanedTranscript: String? = nil

        // Extract title
        if let titleRange = response.range(of: "TITLE: ", options: .caseInsensitive),
           let endOfTitleRange = response.range(of: "\n\n", options: [], range: titleRange.upperBound..<response.endIndex) {
            title = String(response[titleRange.upperBound..<endOfTitleRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract cleaned transcript
        if let transcriptRange = response.range(of: "CLEANED TRANSCRIPT:", options: .caseInsensitive) {
            cleanedTranscript = String(response[transcriptRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let defaultTitle = "Voice Note \(DateFormatUtil.shared.formatTimestamp(date: Date()))"
        return LLMProcessingResult(
            transcript: cleanedTranscript ?? response,
            title: title ?? defaultTitle
        )
    }
}
```

**Verification:**
- [x] Automated: `make build` succeeds
- [x] Manual: Verify AnyLanguageModel imports resolve

**Completion Notes (2025-12-12):**
- Created `VoiceToObsidian/Services/LLMService.swift` with:
  - `LLMProcessingResult` struct for transcript and title
  - `@MainActor class LLMService` with provider management
  - `isFoundationModelsAvailable` computed property using `SystemLanguageModel.default.availability`
  - `processTranscriptWithTitle(transcript:customWords:)` async method
  - Private methods: `buildPrompt()`, `sendRequest()`, `createLanguageModel()`, `parseResponse()`
- Added `LLMError` enum to `AppError.swift` (brought forward from Phase 4)
- Added file to Xcode project (project.pbxproj)
- Fixed MainActor isolation issue by capturing API keys before creating language models
- Build passes: `make build` ✅
- Tests pass: `make test` ✅ (44/44 tests)

---

### Phase 4: Update Error Handling

**Goal**: Replace Anthropic-specific errors with generic LLM errors.

**Files:**
- `VoiceToObsidian/Errors/AppError.swift` - Replace `AnthropicError` with `LLMError`

**Changes:**

Replace the existing `anthropic` case and `AnthropicError` enum:

```swift
// BEFORE:
case anthropic(AnthropicError)

enum AnthropicError: Error {
    case apiKeyMissing
    case requestCreationFailed
    case networkError(String)
    case responseParsingFailed(String)
    case invalidResponse
}

// AFTER:
case llm(LLMError)

enum LLMError: Error {
    case apiKeyMissing
    case providerUnavailable(String)
    case requestFailed(String)
    case responseParsingFailed(String)
    case invalidResponse
    case networkError(String)
}
```

Update error handling methods:
```swift
private func handleLLMError(_ error: LLMError) -> String {
    switch error {
    case .apiKeyMissing:
        return "API key is missing for the selected provider."
    case .providerUnavailable(let message):
        return "LLM provider unavailable: \(message)"
    case .requestFailed(let message):
        return "Failed to process with LLM: \(message)"
    case .responseParsingFailed(let message):
        return "Failed to parse LLM response: \(message)"
    case .invalidResponse:
        return "Received invalid response from LLM."
    case .networkError(let message):
        return "Network error: \(message)"
    }
}
```

Update `failureReason`:
```swift
case .llm: return "LLM processing issue"
```

Update `recoverySuggestion`:
```swift
case .llm(.apiKeyMissing):
    return "Please add an API key for your selected provider in Settings."
case .llm(.providerUnavailable):
    return "Try selecting a different LLM provider in Settings."
```

**Verification:**
- [x] Automated: `make build` succeeds
- [x] Automated: `make test` passes

**Completion Notes (2025-12-12):**
- Phase 4 was mostly completed during Phase 3 when `LLMError` was added to `AppError.swift`
- Both `AnthropicError` and `LLMError` coexist during the transition period
- `AnthropicError` will be removed in Phase 8 when `AnthropicService.swift` is deleted

---

### Phase 5: Update VoiceNoteCoordinator

**Goal**: Replace AnthropicService with LLMService, add multi-provider configuration.

**Files:**
- `VoiceToObsidian/ViewModels/VoiceNoteCoordinator.swift` - Replace AnthropicService, add provider management

**Changes:**

1. Replace `AnthropicService` with `LLMService`:
```swift
// BEFORE (line 117-121):
private var _anthropicService: AnthropicService?

private var anthropicService: AnthropicService {
    if _anthropicService == nil {
        logger.debug("Lazily creating AnthropicService")
        _anthropicService = AnthropicService(apiKey: anthropicAPIKey)
    }
    return _anthropicService!
}

// AFTER:
private var _llmService: LLMService?

private var llmService: LLMService {
    if _llmService == nil {
        logger.debug("Lazily creating LLMService")
        _llmService = LLMService()
        _llmService?.updateProvider(selectedLLMProvider)
        _llmService?.updateAnthropicAPIKey(anthropicAPIKey)
        _llmService?.updateOpenAIAPIKey(openAIAPIKey)
        _llmService?.updateGeminiAPIKey(geminiAPIKey)
    }
    return _llmService!
}
```

2. Add secure storage for new API keys:
```swift
// After existing anthropicAPIKey (line 211-217):

@SecureStorage(wrappedValue: "", key: "OpenAIAPIKey")
private var openAIAPIKey: String {
    didSet {
        logger.debug("OpenAI API key updated")
        llmService.updateOpenAIAPIKey(openAIAPIKey)
    }
}

@SecureStorage(wrappedValue: "", key: "GeminiAPIKey")
private var geminiAPIKey: String {
    didSet {
        logger.debug("Gemini API key updated")
        llmService.updateGeminiAPIKey(geminiAPIKey)
    }
}
```

3. Add provider preference:
```swift
@AppPreference(wrappedValue: LLMProvider.foundationModels.rawValue, "SelectedLLMProvider")
private var selectedLLMProviderRaw: String

var selectedLLMProvider: LLMProvider {
    get { LLMProvider(rawValue: selectedLLMProviderRaw) ?? .foundationModels }
    set {
        selectedLLMProviderRaw = newValue.rawValue
        llmService.updateProvider(newValue)
    }
}
```

4. Update `processRecordingAsync` to use new service:
```swift
// BEFORE (line 745-772):
if !anthropicAPIKey.isEmpty && !processedVoiceNote.originalTranscript.isEmpty {
    // ... uses anthropicService.processTranscriptWithTitleAsync

// AFTER:
if canProcessWithLLM && !processedVoiceNote.originalTranscript.isEmpty {
    let customWords = CustomWordsManager.shared.customWords
    let result = try await llmService.processTranscriptWithTitle(
        transcript: processedVoiceNote.originalTranscript,
        customWords: customWords
    )
    processedVoiceNote.cleanedTranscript = result.transcript
    processedVoiceNote.title = result.title
}
```

5. Add helper property:
```swift
var canProcessWithLLM: Bool {
    switch selectedLLMProvider {
    case .foundationModels:
        return llmService.isFoundationModelsAvailable
    case .anthropic:
        return !anthropicAPIKey.isEmpty
    case .openai:
        return !openAIAPIKey.isEmpty
    case .gemini:
        return !geminiAPIKey.isEmpty
    }
}
```

6. Add public methods for API key management:
```swift
func setOpenAIAPIKey(_ key: String) {
    openAIAPIKey = key
}

func clearOpenAIAPIKey() {
    openAIAPIKey = ""
    llmService.updateOpenAIAPIKey("")
}

func setGeminiAPIKey(_ key: String) {
    geminiAPIKey = key
}

func clearGeminiAPIKey() {
    geminiAPIKey = ""
    llmService.updateGeminiAPIKey("")
}

func setLLMProvider(_ provider: LLMProvider) {
    selectedLLMProvider = provider
}
```

7. Update cleanup:
```swift
// In cleanup() method:
_llmService = nil  // instead of _anthropicService = nil
```

**Verification:**
- [x] Automated: `make build` succeeds
- [x] Automated: `make test` passes (44/44 tests)
- [ ] Manual: Recording still works with default Foundation Models

**Completion Notes (2025-12-12):**
- Added `_llmService` backing variable and lazy `llmService` property
- Added `@SecureStorage` for `openAIAPIKey` and `geminiAPIKey`
- Added `@AppPreference` for `selectedLLMProviderRaw` and computed `selectedLLMProvider`
- Added `canProcessWithLLM` computed property checking provider availability
- Updated `processRecordingAsync()` to use `llmService.processTranscriptWithTitle()` instead of `anthropicService`
- Now uses `AppError.llm(.requestFailed(...))` instead of `AppError.anthropic(.networkError(...))`
- Added public methods: `setOpenAIAPIKey()`, `clearOpenAIAPIKey()`, `setGeminiAPIKey()`, `clearGeminiAPIKey()`, `setLLMProvider()`
- Added helper properties: `isFoundationModelsAvailable`, `selectedLLMProviderDisplayName`, `availableLLMProviders`, `isSelectedProviderConfigured`, `hasAPIKey(for:)`
- Updated `cleanup()` to include `_llmService = nil`
- Updated `clearAllSensitiveDataAsync()` to clear all API keys
- Both `AnthropicService` and `LLMService` coexist until Phase 8

---

### Phase 6: Update Settings UI

**Goal**: Add provider selection UI and conditional API key fields.

**Files:**
- `VoiceToObsidian/Views/SettingsView.swift` - Add provider picker, show/hide API key sections

**Changes:**

1. Add new state to `SettingsStateCoordinator`:
```swift
// Add to SettingsStateCoordinator class:
@Published var selectedProvider: LLMProvider = .foundationModels
@Published var openAIAPIKey = ""
@Published var geminiAPIKey = ""
@Published var showingOpenAIKeyAlert = false
@Published var showingGeminiKeyAlert = false

@SecureStorage(wrappedValue: "", key: "OpenAIAPIKey")
var secureOpenAIAPIKey: String

@SecureStorage(wrappedValue: "", key: "GeminiAPIKey")
var secureGeminiAPIKey: String

@AppPreference(wrappedValue: LLMProvider.foundationModels.rawValue, "SelectedLLMProvider")
var selectedProviderRaw: String
```

2. Update `loadSavedSettings()`:
```swift
// Load provider selection
selectedProvider = LLMProvider(rawValue: selectedProviderRaw) ?? .foundationModels

// Load additional API keys
openAIAPIKey = secureOpenAIAPIKey
geminiAPIKey = secureGeminiAPIKey
```

3. Create new `LLMProviderSection` component:
```swift
struct LLMProviderSection: View {
    @Binding var selectedProvider: LLMProvider
    let onProviderChange: (LLMProvider) -> Void

    var body: some View {
        FlexokiSectionView("AI Provider") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select your preferred AI provider for transcript processing.")
                    .font(.footnote)
                    .foregroundColor(.flexokiText2)

                Picker("Provider", selection: $selectedProvider) {
                    ForEach(LLMProvider.allCases) { provider in
                        HStack {
                            Text(provider.displayName)
                            if provider == .foundationModels {
                                Text("Free")
                                    .font(.caption)
                                    .foregroundColor(.flexokiAccentGreen)
                            }
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedProvider) { _, newValue in
                    onProviderChange(newValue)
                }

                // Foundation Models availability indicator
                if selectedProvider == .foundationModels {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.flexokiAccentGreen)
                        Text("On-device processing - free & private")
                            .font(.caption)
                            .foregroundColor(.flexokiText2)
                    }
                }
            }
        }
    }
}
```

4. Modify existing `APIKeySection` to be generic, create provider-specific sections:
```swift
// OpenAI API Key Section
struct OpenAIKeySection: View {
    @EnvironmentObject var coordinator: VoiceNoteCoordinator
    @Binding var openAIAPIKey: String
    @Binding var isLoading: Bool
    @Binding var showingSavedAlert: Bool
    @Binding var showingClearedAlert: Bool
    @Binding var secureOpenAIAPIKey: String

    var body: some View {
        FlexokiSectionView("OpenAI API") {
            // Similar structure to existing APIKeySection
            // ... (copy pattern from existing APIKeySection)
        }
    }
}

// Gemini API Key Section
struct GeminiKeySection: View {
    // Similar structure
}
```

5. Update main `SettingsView` to conditionally show sections:
```swift
var body: some View {
    VStack(spacing: 0) {
        ScrollView {
            VStack(spacing: 16) {
                // Provider selection (always visible)
                LLMProviderSection(
                    selectedProvider: $stateCoordinator.selectedProvider,
                    onProviderChange: { provider in
                        stateCoordinator.selectedProviderRaw = provider.rawValue
                        coordinator.setLLMProvider(provider)
                    }
                )

                // Show API key section only for selected provider
                switch stateCoordinator.selectedProvider {
                case .foundationModels:
                    // No API key needed - show info card
                    FoundationModelsInfoSection()

                case .anthropic:
                    APIKeySection(/* existing bindings */)

                case .openai:
                    OpenAIKeySection(/* bindings */)

                case .gemini:
                    GeminiKeySection(/* bindings */)
                }

                // Custom Words (always visible)
                FlexokiSectionView("Custom Words & Phrases") { /* existing */ }

                // Vault Path (always visible)
                VaultPathSection(/* existing bindings */)

                // Clear All Data (always visible)
                ClearAllDataSection(/* existing bindings */)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
    // ... existing modifiers
}
```

6. Add Foundation Models info section:
```swift
struct FoundationModelsInfoSection: View {
    var body: some View {
        FlexokiSectionView("Apple Intelligence") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "apple.logo")
                    Text("Powered by on-device AI")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.flexokiText)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Free to use", systemImage: "checkmark")
                    Label("Private - data stays on device", systemImage: "lock.shield")
                    Label("Works offline", systemImage: "wifi.slash")
                }
                .font(.caption)
                .foregroundColor(.flexokiText2)
            }
        }
    }
}
```

**Verification:**
- [ ] Automated: `make build` succeeds
- [ ] Manual: Provider picker displays all 4 options
- [ ] Manual: Selecting Foundation Models hides API key field
- [ ] Manual: Selecting Claude/OpenAI/Gemini shows appropriate API key field
- [ ] Manual: API keys save and load correctly

---

### Phase 7: Update Tests

**Goal**: Update tests to work with new LLMService architecture.

**Files:**
- `VoiceToObsidianTests/AnthropicServiceTests.swift` → Rename to `LLMServiceTests.swift`
- `VoiceToObsidianTests/VoiceToObsidianTests.swift` - Update integration tests

**Changes:**

1. Rename and update `AnthropicServiceTests.swift` to `LLMServiceTests.swift`:
```swift
import XCTest
@testable import VoiceToObsidian

final class LLMServiceTests: XCTestCase {
    var llmService: LLMService!

    override func setUp() {
        super.setUp()
        llmService = LLMService()
    }

    override func tearDown() {
        llmService = nil
        super.tearDown()
    }

    func testProviderUpdate() {
        llmService.updateProvider(.anthropic)
        // Verify provider changed (need to expose for testing or use other verification)
    }

    func testAPIKeyUpdate() {
        llmService.updateAnthropicAPIKey("test-key")
        llmService.updateOpenAIAPIKey("test-key")
        llmService.updateGeminiAPIKey("test-key")
        // Verify keys set
    }

    func testResponseParsing() async throws {
        // Test the response parsing logic with mock response
        let mockResponse = """
        TITLE: Test Note Title

        CLEANED TRANSCRIPT:
        This is the cleaned transcript content.
        """

        // Test parsing (may need to expose parsing method for testing)
    }

    func testFoundationModelsAvailability() {
        // Test availability check
        // Will return false in test environment
        XCTAssertFalse(llmService.isFoundationModelsAvailable)
    }
}
```

2. Update any integration tests that reference `AnthropicService` to use `LLMService`

**Verification:**
- [ ] Automated: `make test` passes all tests
- [ ] Manual: Verify test coverage is maintained

---

### Phase 8: Delete Old Files & Cleanup

**Goal**: Remove deprecated `AnthropicService.swift` and any unused code.

**Files:**
- `VoiceToObsidian/Services/AnthropicService.swift` - DELETE
- Remove from Xcode project

**Changes:**
1. Delete `AnthropicService.swift`
2. Remove file reference from `project.pbxproj`
3. Search codebase for any remaining `AnthropicService` references
4. Update any imports that referenced `AnthropicService`

**Verification:**
- [ ] Automated: `make build` succeeds with no warnings
- [ ] Automated: `make test` passes
- [ ] Manual: App launches and functions correctly

---

## Success Criteria

- [ ] App builds successfully targeting iOS 26+
- [ ] Provider picker in Settings shows all 4 providers
- [ ] Foundation Models works without API key (on supported devices)
- [ ] Claude/OpenAI/Gemini work with valid API keys
- [ ] API keys stored securely in Keychain
- [ ] Provider selection persists across app launches
- [ ] All existing tests pass (with updates)
- [ ] Voice note recording → transcription → LLM processing → Obsidian save flow works

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| AnyLanguageModel API changes (pre-1.0) | Pin to specific version, monitor releases |
| iOS 26 not yet released | Develop against beta, test thoroughly |
| Foundation Models unavailable on test devices | Test fallback to cloud providers |
| Breaking changes in cloud provider APIs | AnyLanguageModel abstracts these away |
| User confusion with multiple providers | Clear UI labels, info sections for each |

## File Summary

| Action | File |
|--------|------|
| MODIFY | `VoiceToObsidian.xcodeproj/project.pbxproj` |
| CREATE | `VoiceToObsidian/Models/LLMProvider.swift` |
| CREATE | `VoiceToObsidian/Services/LLMService.swift` |
| MODIFY | `VoiceToObsidian/Errors/AppError.swift` |
| MODIFY | `VoiceToObsidian/ViewModels/VoiceNoteCoordinator.swift` |
| MODIFY | `VoiceToObsidian/Views/SettingsView.swift` |
| RENAME | `AnthropicServiceTests.swift` → `LLMServiceTests.swift` |
| DELETE | `VoiceToObsidian/Services/AnthropicService.swift` |

## Post-Implementation

After completing all phases:
1. Run full test suite: `make test`
2. Build and run on simulator: `make run`
3. Manual testing checklist:
   - [ ] Create voice note with Foundation Models
   - [ ] Create voice note with Claude (if API key available)
   - [ ] Switch providers in settings
   - [ ] Verify API keys persist
   - [ ] Verify notes saved to Obsidian correctly
