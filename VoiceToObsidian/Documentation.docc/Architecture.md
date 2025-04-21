# Architecture

Learn about the architecture of Voice to Obsidian and how its components work together.

## Overview

Voice to Obsidian follows the MVVM (Model-View-ViewModel) architecture pattern with a Coordinator layer for navigation and service management. This architecture provides a clean separation of concerns and makes the codebase more maintainable and testable. The app also leverages modern Swift features like property wrappers, structured concurrency, and SwiftUI for a robust and efficient implementation.

## Core Components

### Models

The core data models in the app include:

- `VoiceNote`: Represents a recorded voice note with its metadata, content, and processing status
- `VoiceNoteStatus`: An enum tracking the processing state of voice notes (processing, complete, error)
- `AppError`: A comprehensive error handling system with nested error types for different components

### Views

The UI layer is built with SwiftUI and consists of:

- An integrated recording interface with a floating timer display
- Real-time processing status indicators showing the current state of voice notes
- Transcription views for displaying and editing transcripts
- Settings views for configuring the app
- Custom words management interface for adding, editing, and removing custom words
- Shared UI components using the Flexoki theme system for consistent styling

### ViewModels

ViewModels connect the UI to the underlying services and provide:

- Data binding for UI updates
- Business logic for user interactions
- Error handling through the `ErrorHandling` protocol
- State management and coordination between services

### Coordinators

The app uses a coordinator pattern to:

- Manage navigation between screens
- Coordinate between different services
- Handle app lifecycle events

The main coordinator is `AppCoordinator`, which manages the overall app flow.

## Services

The app's functionality is implemented through several service classes:

### RecordingManager

Handles audio recording with background support, managing the AVAudioSession and AVAudioRecorder. Uses CADisplayLink with optimized dispatch queues to ensure the recording timer updates reliably during all UI interactions, including scrolling.

### TranscriptionManager

Manages speech recognition and transcription using Apple's Speech framework.

### VoiceNoteStore

Handles persistence and retrieval of voice notes, including saving to and loading from disk with pagination support.

### AnthropicService

Communicates with the Anthropic Claude API to clean and format transcripts and generate titles. Integrates custom words from the CustomWordsManager to improve transcription accuracy for specialized terminology.

### ObsidianService

Manages interactions with the Obsidian vault, including creating markdown files and copying audio attachments.

### SecurityManager

Manages security-scoped bookmarks for accessing the Obsidian vault directory across app launches.

### CustomWordsManager

Manages user-defined custom words and phrases to improve transcription accuracy. Provides persistence and reactivity for the list of custom words, which are included in the context sent to Claude for transcript processing.

## Utilities and Extensions

The app includes several utility components:

### Property Wrappers

- `SecureStorage`: Provides secure storage of sensitive data in the Keychain
- `SecureBookmark`: Manages security-scoped bookmarks for file access
- `AppPreferences`: Manages user preferences with UserDefaults

### Utilities

- `DateFormatUtil`: Centralizes date and time formatting throughout the app
- `AccessibilityConstants`: Provides consistent accessibility values and modifiers

### UI Theming

- `FlexokiTheme`: Implements a consistent visual design system with text, button, and input styles

## Concurrency Model

The app uses Swift's modern concurrency features:

- `async/await` for asynchronous operations
- `@MainActor` for UI updates
- `Task` for background processing
- Structured concurrency with task groups

## Error Handling

Errors are handled through:

- The `AppError` enum for typed errors with nested error types for different components
- The `ErrorHandling` protocol for consistent error management across view models
- Centralized error presentation in the UI with appropriate recovery actions
- Structured logging with OSLog for debugging and diagnostics
