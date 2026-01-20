# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

This project supports CLI-first development via Makefile:

| Command | Description |
|---------|-------------|
| `make build` | Compile the project |
| `make test` | Run all unit tests |
| `make run` | Build, install, and launch on simulator |
| `make clean` | Remove build artifacts |
| `make log` | Stream app logs from simulator |

**Alternative**: Open `VoiceToObsidian.xcodeproj` in Xcode for GUI-based development.

**Note**: New files must still be added to the Xcode project manually.

## Architecture Overview

The app follows **MVVM with Coordinators** pattern:

### Coordinator Layer (App Flow)
- `AppCoordinator` - Root coordinator managing app lifecycle, lazy service initialization, and app state (`initializing` → `uiReady` → `ready`)
- `VoiceNoteCoordinator` - Manages voice note feature domain, coordinates between services

### Services (Business Logic)
- `RecordingManager` - Audio recording with AVAudioSession/AVAudioRecorder, uses CADisplayLink for reliable timer updates
- `TranscriptionManager` - Speech recognition using Apple's Speech framework
- `LLMService` - Multi-provider LLM integration (Apple Intelligence, Claude, OpenAI, Gemini) for transcript cleanup and title generation
- `ObsidianService` - Creates markdown files and copies audio to Obsidian vault
- `SecurityManager` - Security-scoped bookmarks for vault directory access
- `CustomWordsManager` - User-defined words sent to LLM for better transcription accuracy

### Property Wrappers
- `@SecureStorage` - Keychain storage for sensitive data (API keys)
- `@SecureBookmark` - Security-scoped bookmark management
- `@AppPreferences` - UserDefaults wrapper

### Error Handling
- `AppError` - Typed error enum with nested types for different components
- `ErrorHandling` protocol - Consistent error management across ViewModels

## Key Patterns

- **Deferred initialization**: Services created on-demand via lazy properties to optimize startup
- **Staged app startup**: UI renders first, then services initialize asynchronously
- **Structured concurrency**: Uses async/await, @MainActor, Task groups
- **OSLog**: Structured logging throughout (subsystem: "com.voicetoobsidian.app")
- **Memory management**: Weak references in closures, block-based notification APIs, proper cleanup in deinit

## Development Guidelines

1. Use modern Swift practices (async/await, property wrappers, structured concurrency)
2. After editing services, verify corresponding tests in `VoiceToObsidianTests/` still pass
3. When refactoring, remove all deprecated code, comments, and dead logic
4. Update DocC documentation when making code changes (`Documentation.docc/`)
5. Use Flexoki theme colors from `FlexokiTheme.swift` for UI consistency

## Obsidian Integration

The app creates:
- `Voice Notes/` directory for markdown files
- `Attachments/` directory for audio files
- Links to daily notes with YAML frontmatter (date, duration, daily properties)

## Claude Code Workflow

Follow the **Research → Plan → Implement → Validate** workflow for non-trivial changes.

### Custom Commands

Located in `.claude/commands/`:

| Command | Purpose |
|---------|---------|
| `/research [topic]` | Investigate codebase, spawn parallel sub-agents, output to `thoughts/shared/research/` |
| `/plan [feature]` | Create detailed implementation plan with phases, output to `thoughts/shared/plans/` |
| `/implement [plan]` | Execute plan ONE PHASE at a time, pause for manual verification |
| `/validate [feature]` | Verify implementation against plan, generate validation report |

### Workflow Steps

1. **Research Phase** (no code)
   - Use `/research` to investigate the codebase
   - Spawn parallel sub-agents for thorough analysis
   - Document findings with file paths and line numbers
   - Use `/clear` when done

2. **Planning Phase** (no code)
   - Use `/plan` to create detailed implementation plan
   - Include exact file paths, code snippets, success criteria
   - Distinguish automated vs manual verification steps
   - Iterate ~5 times to refine the plan
   - Use `/clear` when plan is approved

3. **Implementation Phase**
   - Use `/implement` to execute the plan
   - Complete ONE PHASE at a time
   - Run automated checks after each phase
   - Wait for manual verification before proceeding
   - Update plan if discoveries emerge

4. **Validation Phase**
   - Use `/validate` to verify the implementation
   - Check all success criteria from the plan
   - Document any deviations
   - Generate comprehensive validation report

### Context Management

- **Never exceed 60% context** - split work into phases
- **Use `/clear` between phases** to reset context
- **Reference `thoughts/` files** instead of re-explaining context
- **Use "think hard" or "ultrathink"** for complex planning decisions

### thoughts/ Directory

Persistent knowledge repository:
```
thoughts/
├── personal/           # Session scratchpads
├── shared/
│   ├── research/       # Research documents
│   └── plans/          # Plans and validation reports
└── searchable/         # Symlinked for AI search
```

## Recommended Plugins

Install these plugins when working in this repo:
```
/plugin install swift-lsp
```

## Vault Context

This project is linked to the Obsidian vault at `$OBSIDIAN_VAULT_ROOT` (/Users/ww/vaults/notes).

- **Vault project:** [[01_Projects/Coati]]
- **Tasks:** [[02_Areas/Tasks/Open Tasks.md]]

Use `/quick-capture` to send notes to the vault's daily note from this project.
