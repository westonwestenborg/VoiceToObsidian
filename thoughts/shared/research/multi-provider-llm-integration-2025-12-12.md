# Research: Multi-Provider LLM Integration (iOS Foundation Models, Claude, OpenAI, Gemini)
Date: 2025-12-12

## Summary

This research investigates adding support for multiple LLM providers to VoiceToObsidian, with iOS Foundation Models as the default. The goal is to replace the current hardcoded Anthropic Claude integration with a flexible provider selection system.

**Key Finding**: Apple's Foundation Models framework (iOS/macOS 26+) provides free, private, on-device AI. A unified Swift library called **AnyLanguageModel** provides a drop-in API that supports Foundation Models, Claude, OpenAI, Gemini, and other providers with minimal code changes.

## Key Files

### Current Implementation
- `VoiceToObsidian/Services/AnthropicService.swift` - Current LLM service (412 lines)
  - Line 39-412: Main class with `processTranscriptAsync()` and `processTranscriptWithTitleAsync()`
  - Line 48: Hardcoded Anthropic API URL
  - Line 191, 339: Hardcoded model `"claude-sonnet-4-5"`
  - Line 159, 308: Custom words integration
  - Line 168-188, 317-336: Prompt template for transcript cleanup

- `VoiceToObsidian/ViewModels/VoiceNoteCoordinator.swift` - Orchestrates flow
  - Line 175-181: Lazy initialization of AnthropicService
  - Line 211-217: `@SecureStorage` for API key
  - Line 544-565: `setAnthropicAPIKey()` and `clearAnthropicAPIKey()` methods
  - Line 745-775: Processing pipeline with retry logic

- `VoiceToObsidian/Views/SettingsView.swift` - Settings UI
  - Line 52-138: `APIKeySection` for Anthropic key input
  - Line 277-386: `SettingsStateCoordinator` for state management
  - NO model/provider selection UI currently exists

- `VoiceToObsidian/Errors/AppError.swift` - Error handling
  - Line 44: `case anthropic(AnthropicError)`
  - Line 108-125: `AnthropicError` enum with specific error cases
  - Line 265-277: `handleAnthropicError()` for localized descriptions

### Property Wrappers
- `VoiceToObsidian/PropertyWrappers/SecureStorage.swift` - Keychain storage
- `VoiceToObsidian/PropertyWrappers/AppPreferences.swift` - UserDefaults storage

## Architecture Insights

### Current Service Architecture
```
VoiceNoteCoordinator
    ├── RecordingManager (audio capture)
    ├── TranscriptionManager (Apple Speech → raw transcript)
    ├── AnthropicService (cleanup + title generation) ← REPLACE THIS
    └── ObsidianService (save to vault)
```

### Proposed Architecture
```
VoiceNoteCoordinator
    ├── RecordingManager
    ├── TranscriptionManager
    ├── LLMService (protocol-based, multi-provider) ← NEW
    │       ├── FoundationModelsProvider (default, free, on-device)
    │       ├── AnthropicProvider (Claude API)
    │       ├── OpenAIProvider (OpenAI API)
    │       └── GeminiProvider (Google Gemini API)
    └── ObsidianService
```

### Provider Comparison

| Provider | Requires | Cost | Privacy | Offline | iOS Version |
|----------|----------|------|---------|---------|-------------|
| **Foundation Models** | Apple Intelligence | Free | On-device | Yes | iOS 26+ |
| **Anthropic Claude** | API Key | Per-token | Cloud | No | iOS 15+ |
| **OpenAI** | API Key | Per-token | Cloud | No | iOS 15+ |
| **Google Gemini** | API Key | Free tier / Per-token | Cloud | No | iOS 15+ |

## iOS Foundation Models Framework

### Overview
- Announced at WWDC 2025
- On-device ~3B parameter model optimized for summarization, extraction, classification
- Free, private, offline - no API keys needed
- Available on devices supporting Apple Intelligence (iOS 26+, macOS 26+)

### Basic Usage
```swift
import FoundationModels

let session = LanguageModelSession()
let response = try await session.respond(to: "Clean up this transcript...")
print(response.content)
```

### Availability Check
```swift
switch SystemLanguageModel.default.availability {
case .available:
    // Use Foundation Models
case .unavailable(let reason):
    // Fall back to cloud provider
}
```

### Limitations
- Requires iOS 26+ (current project targets iOS 18.2)
- Not suitable for "world knowledge" or "advanced reasoning"
- Device must support Apple Intelligence and have it enabled
- Battery/power considerations

## AnyLanguageModel Library

**Repository**: `https://github.com/mattt/AnyLanguageModel`

### Why Use It
- **Unified API**: Same interface for all providers
- **Drop-in replacement**: Change import, keep same code
- **Provider flexibility**: Swap backends with one line change
- **Actively maintained**: Pre-1.0, stable core API

### SPM Installation
```swift
dependencies: [
    .package(url: "https://github.com/mattt/AnyLanguageModel.git", from: "0.4.0")
]
```

### Usage Examples

**Apple Foundation Models**:
```swift
import AnyLanguageModel

let model = SystemLanguageModel.default
let session = LanguageModelSession(model: model)
let response = try await session.respond(to: prompt)
```

**Anthropic Claude**:
```swift
let model = AnthropicLanguageModel(
    apiKey: apiKey,
    model: "claude-sonnet-4-5-20250929"
)
let session = LanguageModelSession(model: model)
let response = try await session.respond(to: prompt)
```

**OpenAI**:
```swift
let model = OpenAILanguageModel(
    apiKey: apiKey,
    model: "gpt-4"
)
let session = LanguageModelSession(model: model)
let response = try await session.respond(to: prompt)
```

**Google Gemini** (via AnyLanguageModel):
```swift
let model = GeminiLanguageModel(
    apiKey: apiKey,
    model: "gemini-2.0-flash"
)
let session = LanguageModelSession(model: model)
let response = try await session.respond(to: prompt)
```

### Supported Providers
- Apple Foundation Models (macOS 26+, iOS 26+)
- Core ML (local models)
- MLX (Apple Silicon optimized)
- llama.cpp (GGUF models)
- Ollama (HTTP API)
- Anthropic Claude
- OpenAI
- Google Gemini
- Hugging Face Inference

## Alternative: Direct Implementation

If we prefer not to add a dependency, we can implement provider abstraction ourselves:

### Protocol-Based Approach
```swift
protocol LLMProvider {
    var name: String { get }
    var requiresAPIKey: Bool { get }
    func processTranscript(_ transcript: String, customWords: [String]) async throws -> (transcript: String, title: String)
}
```

### Provider Implementations
1. `FoundationModelsProvider` - Uses `import FoundationModels`
2. `AnthropicProvider` - Current code refactored
3. `OpenAIProvider` - New implementation using `MacPaw/OpenAI` or direct API
4. `GeminiProvider` - New implementation using Firebase AI Logic SDK or direct API

### OpenAI Swift Libraries
- **MacPaw/OpenAI** (most popular): `https://github.com/MacPaw/OpenAI`
- **SwiftOpenAI** (most complete): `https://github.com/jamesrochabrun/SwiftOpenAI`

### Gemini Swift Libraries
- **Firebase AI Logic SDK** (recommended by Google): Part of `firebase-ios-sdk` v12.5.0+
  - `FirebaseAILogic` library via SPM
  - Supports Gemini and Imagen models
  - Note: Original standalone `generative-ai-swift` is deprecated
- **Direct API**: Use OpenAI-compatible endpoint `https://generativelanguage.googleapis.com/v1beta/openai`

## Constraints & Considerations

### iOS Version Requirements
- **Current**: iOS 18.2 deployment target
- **Foundation Models**: Requires iOS 26+
- **Decision needed**: Raise minimum to iOS 26, or use availability checks with fallback

### Device Compatibility
- Foundation Models only works on Apple Intelligence-capable devices
- Need graceful fallback for older devices/versions
- Consider: Default to Foundation Models where available, Claude elsewhere

### API Key Storage
- Current: `@SecureStorage` in Keychain (line 211-217 VoiceNoteCoordinator)
- New: Need storage for multiple API keys (Anthropic + OpenAI + Gemini)
- Keys: `AnthropicAPIKey`, `OpenAIAPIKey`, `GeminiAPIKey`, `SelectedLLMProvider`

### Settings UI Changes
- Add provider picker (Foundation Models / Claude / OpenAI / Gemini)
- Show/hide API key fields based on selection
- Model selection within provider (e.g., claude-sonnet-4-5, gpt-4, gemini-2.0-flash)
- Availability indicator for Foundation Models

### Error Handling
- Rename `AppError.anthropic` to `AppError.llm` or keep provider-specific
- Add new error cases for Foundation Models, OpenAI, and Gemini
- Update error messages and recovery suggestions

### Testing Considerations
- Need mock implementations for each provider
- Test availability check fallback logic
- Test provider switching
- Update existing `AnthropicServiceTests.swift`

## Open Questions

1. **iOS Version Strategy**: Should we raise minimum to iOS 26 for Foundation Models, or use availability checks and keep iOS 18.2 support?

We should just raise the minimum to iOS 26

2. **Library Choice**: Use AnyLanguageModel for unified API, or implement protocol ourselves for more control?

3. **Default Behavior**: Should Foundation Models truly be default even if user has API keys configured? Or prefer cloud if API key exists?

The app should default to Foundatio Models, but allow the user to select an API provider if they want to

4. **Model Selection Granularity**: Let users pick specific models (claude-sonnet-4-5, gpt-4o-mini, etc.) or just providers?

If there is a way we can keep this really simple we should let the user pick.

5. **Fallback Strategy**: If Foundation Models unavailable at runtime, automatically use cloud, or show error and ask user to configure?

6. **Migration Path**: How to handle existing users who have Anthropic API key configured?

Don't worry about existing users.

## Recommended Approach

### Option A: AnyLanguageModel (Recommended)
- Add AnyLanguageModel SPM dependency
- Minimal code changes, unified API
- Future-proof for additional providers
- **Risk**: External dependency, pre-1.0 software

### Option B: Custom Protocol Implementation
- More control over implementation
- No external dependencies
- More initial work
- **Risk**: More maintenance burden

### Option C: Hybrid
- Use AnyLanguageModel for Foundation Models integration
- Keep current Anthropic code refactored into protocol
- Add OpenAI directly with MacPaw/OpenAI library

## Files to Modify

| File | Changes |
|------|---------|
| `Package.swift` or Xcode project | Add AnyLanguageModel or OpenAI SPM |
| `AnthropicService.swift` | Refactor to generic `LLMService` or provider protocol |
| `VoiceNoteCoordinator.swift` | Add provider selection, multiple API keys |
| `SettingsView.swift` | Add provider picker, conditional API key fields |
| `AppError.swift` | Add/rename error types for LLM providers |
| `AppPreferences.swift` | Add `SelectedLLMProvider` preference |
| Tests | Update for new architecture |

## Google Gemini Details

### SDK Options

**Option 1: Firebase AI Logic SDK (Recommended by Google)**
- Part of `firebase-ios-sdk` v12.5.0+
- Requires Firebase project setup
- Supports both Gemini and Imagen models
- API key stored server-side for security

**Option 2: Direct REST API**
- No Firebase dependency required
- OpenAI-compatible endpoint: `https://generativelanguage.googleapis.com/v1beta/openai`
- Can use with MacPaw/OpenAI library by changing base URL
- Simpler integration but API key in client

**Option 3: AnyLanguageModel (Recommended for this project)**
- Already supports Gemini out of the box
- Unified API with other providers
- No additional dependencies needed

### Gemini Models
- `gemini-2.0-flash` - Fast, cost-effective (recommended for transcript cleanup)
- `gemini-2.0-flash-thinking` - Extended thinking for complex tasks
- `gemini-1.5-pro` - Larger context window
- `gemini-1.5-flash` - Previous generation, still available

### Gemini API Key
- Free tier available via Google AI Studio
- Get key at: https://aistudio.google.com/app/apikey
- Same security considerations as other API keys (store in Keychain)

## Next Steps

1. Decide on iOS version strategy
2. Decide on library approach (AnyLanguageModel vs custom)
3. Create detailed implementation plan with phases
4. Implement provider abstraction layer
5. Add Settings UI for provider selection
6. Test with all four providers (Foundation Models, Claude, OpenAI, Gemini)
7. Update error handling and user messaging
