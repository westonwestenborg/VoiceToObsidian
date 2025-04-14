# Voice to Obsidian

Voice to Obsidian is an app that transforms voice recordings into well-formatted Obsidian notes.

## Overview

Voice to Obsidian allows users to record voice memos, transcribe them using Apple's Speech Recognition, clean and format the transcripts using AI, and save them to an Obsidian vault.

The app follows the MVVM architecture pattern with a Coordinator layer for navigation and service management. It leverages modern Swift features like property wrappers, structured concurrency, and SwiftUI for a robust and efficient implementation.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Architecture>

### Core Services

- ``RecordingManager``
- ``TranscriptionManager``
- ``VoiceNoteStore``
- ``AnthropicService``
- ``ObsidianService``
- ``SecurityManager``

### App Coordination

- ``AppCoordinator``
- ``VoiceNoteCoordinator``

### Error Handling

- ``AppError``
- ``ErrorHandling``

### Property Wrappers

- ``SecureStorage``
- ``SecureBookmark``
- ``AppPreferences``

### Utilities

- ``DateFormatUtil``
- ``AccessibilityConstants``

### UI Theming

- ``FlexokiTheme``
