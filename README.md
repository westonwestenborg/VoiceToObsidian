# Voice to Obsidian

An iOS app that records voice memos, transcribes them, processes them with Claude AI, and saves them to your Obsidian vault.

## Features

- Record voice memos directly in the app
- Automatic transcription using Apple's Speech framework
- Clean up and format transcripts using Anthropic's Claude API
- Save voice notes as Markdown files in your Obsidian vault
- Link voice notes in your daily note
- Browse and play back past voice notes

## Development History

### Key Issues Fixed

1. **API Key Persistence**
   - Implemented UserDefaults to store the Anthropic API key
   - Ensured the key persists between app launches

2. **Obsidian Vault Selection**
   - Added a DocumentPicker to allow users to select their Obsidian vault directory
   - Implemented security-scoped bookmarks to maintain access to the selected directory

3. **Speech Recognition**
   - Implemented file-based transcription instead of live recognition for better stability
   - Added proper error handling and fallback mechanisms

4. **Anthropic API Integration**
   - Fixed API headers and response parsing to match the current Claude API format
   - Added detailed logging and error handling

5. **iOS Sandbox Permissions**
   - Implemented security-scoped bookmarks for file access outside the app sandbox
   - Properly managed resource access with startAccessingSecurityScopedResource and stopAccessingSecurityScopedResource

## Project Structure

- **Models**
  - `VoiceNote.swift`: Data model for voice notes

- **Views**
  - `ContentView.swift`: Main tab-based interface
  - `RecordView.swift`: UI for recording voice memos
  - `VoiceNoteListView.swift`: List of recorded voice notes
  - `VoiceNoteDetailView.swift`: Detailed view of a voice note
  - `SettingsView.swift`: Settings UI for API key and vault path
  - `DocumentPicker.swift`: Picker for selecting the Obsidian vault

- **ViewModels**
  - `VoiceNoteStore.swift`: Handles recording, transcription, and saving voice notes

- **Services**
  - `ObsidianService.swift`: Manages file creation in the Obsidian vault
  - `AnthropicService.swift`: Processes transcripts with Claude API

## Setup Instructions

1. Open the project in Xcode
2. Build and run the app on your iOS device
3. In the Settings tab:
   - Enter your Anthropic API key
   - Select your Obsidian vault directory
4. Start recording voice memos!

## Technical Notes

- The app uses security-scoped bookmarks to maintain access to the Obsidian vault between app launches
- Voice recordings are saved in the app's Documents directory
- Transcription is done using file-based processing rather than live recognition for better stability
- The app creates "Voice Notes" and "Attachments" directories in your Obsidian vault
- Daily notes are updated with links to new voice notes

## License

This project is for personal use only.
