# Research: CLI-First Development Workflow

Date: 2025-12-06

## Summary

This research examines how to incorporate CLI-first development practices from ChatGPT's iOS development guide into the VoiceToObsidian project. The project has a solid foundation with existing tests, good service separation, and a documented workflow. The main gaps are: no build automation scripts, manual Xcode dependency in docs, and incomplete test coverage.

## Current State

### Build Infrastructure
- **xcodebuild**: Now working (xcode-select fixed)
- **Scheme**: `VoiceToObsidian`
- **Targets**: `VoiceToObsidian`, `VoiceToObsidianTests`
- **Simulators**: iPhone 16 Pro, iPhone 16, iPhone SE (3rd gen) available
- **Build scripts**: None (no Makefile, no shell scripts)

### Test Infrastructure
- **Framework**: Swift Testing (`@Test` macro, `#expect()` assertions)
- **Test files**: 7 files, ~1,441 lines of test code
- **Test count**: 29 test methods across 6 test suites
- **Pattern**: Aggregator in `VoiceToObsidianTests.swift` calls sub-test structs

### Test Coverage Matrix

| Component | Has Tests | CLI Testable | Notes |
|-----------|-----------|--------------|-------|
| AnthropicService | Yes (7 tests) | Yes | Mock URLSession, response parsing |
| ObsidianService | Yes (6 tests) | Yes | Mock FileManager |
| RecordingManager | Yes (4 tests) | Partial | Hardware mocking incomplete |
| TranscriptionManager | Yes (2 tests) | Partial | Speech framework hard to mock |
| DateFormatUtil | Yes (5 tests) | Yes | Pure functions |
| Integration | Yes (5 tests) | Yes | Full mocks |
| SecurityManager | No | Partial | Bookmark APIs |
| KeychainManager | No | Simulator only | Real Keychain needed |
| VoiceNoteDataStore | No | Yes | File I/O mockable |
| CustomWordsManager | No | Yes | UserDefaults mockable |
| AppCoordinator | No | Partial | Lifecycle management |
| VoiceNoteCoordinator | No | Partial | UI coordination |

### Documentation State
- **CLAUDE.md**: Well-structured, but says "Builds must be triggered manually in Xcode"
- **Custom commands**: `/research`, `/plan`, `/implement`, `/validate` all exist
- **thoughts/**: Directory structure ready, but empty (no research/plans saved yet)
- **.windsurfrules**: IDE-centric, no CLI equivalents

## Key Files

### Build Configuration
- `VoiceToObsidian.xcodeproj` - Main project
- `VoiceToObsidian.xctestplan` - Test plan with parallelization enabled

### Documentation to Update
- `CLAUDE.md:1-120` - Main workflow guide
- `.claude/commands/implement.md` - Implementation command
- `.claude/commands/validate.md` - Validation command

### Test Files
- `VoiceToObsidianTests/VoiceToObsidianTests.swift:1-61` - Test aggregator
- `VoiceToObsidianTests/AnthropicServiceTests.swift:1-313` - Best mock example
- `VoiceToObsidianTests/IntegrationTests.swift:1-344` - Integration patterns

## Architecture Insights

### What Works Well
1. **Service separation**: Services in dedicated folder with clear responsibilities
2. **Mock infrastructure**: Good patterns in AnthropicServiceTests (URLSessionProtocol, TestableAnthropicService)
3. **Error handling**: Typed `AppError` enum with nested types
4. **Async patterns**: Consistent async/await usage throughout

### What Needs Improvement
1. **No DI framework**: Services created directly, mocking requires subclassing
2. **Hardware coupling**: RecordingManager/TranscriptionManager tightly coupled to AVFoundation/Speech
3. **Singleton usage**: BookmarkManager uses `static let shared`
4. **Reflection in tests**: Using Mirror to set private @Published properties (fragile)

## CLI Commands Reference

### Build
```bash
xcodebuild -scheme VoiceToObsidian \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  build
```

### Test
```bash
xcodebuild -scheme VoiceToObsidian \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  test
```

### Test with Coverage
```bash
xcodebuild -scheme VoiceToObsidian \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -enableCodeCoverage YES \
  test
```

### Run on Simulator
```bash
# Build
xcodebuild -scheme VoiceToObsidian \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -derivedDataPath build \
  build

# Boot simulator
xcrun simctl boot "iPhone 16" 2>/dev/null || true

# Install and launch
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/VoiceToObsidian.app
xcrun simctl launch booted com.example.VoiceToObsidian
```

### Log Streaming
```bash
xcrun simctl spawn booted log stream \
  --predicate 'subsystem == "com.voicetoobsidian.app"'
```

## Constraints & Considerations

### What We CAN Do
1. Create Makefile with build/test/run targets
2. Update CLAUDE.md with CLI commands
3. Update `/implement` and `/validate` commands to use CLI verification
4. Add test coverage for VoiceNoteDataStore, CustomWordsManager
5. Document log streaming for debugging

### What We SHOULD NOT Do
1. Extract Core/ as Swift Package (overkill for this project size)
2. Add XcodeGen/Tuist (team-scale solution, not needed)
3. Refactor all services for full DI (too much churn)
4. Add UI tests (unit tests sufficient for this app)

### Trade-offs
- **Makefile vs shell scripts**: Makefile is more standard, but shell scripts are simpler
- **Full test coverage vs pragmatic coverage**: Focus on high-value tests (AnthropicService, ObsidianService, VoiceNoteDataStore)
- **Strict CLI-only vs hybrid**: Keep manual Xcode as fallback, but prefer CLI

## Open Questions

1. **Bundle identifier**: Need to verify `com.example.VoiceToObsidian` vs actual bundle ID for simctl commands
2. **Derived data path**: Should we standardize to `build/` or use default `~/Library/Developer/Xcode/DerivedData/`?
3. **CI/CD**: Is GitHub Actions desired for automated testing?
4. **Pre-commit hooks**: Should we add git hooks for build verification?

## Recommendations

### Phase 1: Build Automation (Immediate)
1. Create `Makefile` with `build`, `test`, `run`, `log` targets
2. Update CLAUDE.md "Build and Test Commands" section
3. Test that all commands work

### Phase 2: Workflow Integration
1. Update `/implement` command to run `make build` after each phase
2. Update `/validate` command to run `make test` as verification
3. Add CLI examples to relevant sections

### Phase 3: Optional Enhancements
1. Add tests for untested but CLI-testable components
2. Consider pre-commit hook for `make build`
3. Document log streaming workflow
