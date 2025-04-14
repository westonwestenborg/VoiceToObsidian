# Voice to Obsidian

An iOS app that records voice memos, transcribes them, processes them with Claude AI, and saves them to your Obsidian vault. Features the Flexoki color palette for a warm, readable interface that matches the Obsidian aesthetic.

## Features

- Record voice memos directly in the app
- Automatic transcription using Apple's Speech framework
- Clean up and format transcripts using Anthropic's Claude API
- Save voice notes as Markdown files in your Obsidian vault
- Link voice notes in your daily note
- Browse and play back past voice notes

## Project Structure

- **Models**
  - `VoiceNote.swift`: Data model for voice notes

- **Views**
  - `ContentView.swift`: Main tab-based interface with integrated recording functionality
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

### Obsidian Setup

1. **Backlinks**: The app creates proper backlinks between your voice notes and daily notes. To view these connections:
   - Enable the Backlinks core plugin in Obsidian (Settings → Core plugins → Backlinks)
   - Enable the Daily Notes plugin (or be okay with the app creating one for you)
   - Open the right sidebar and click the Backlinks icon to see all notes linking to the current note

2. **Dataview Support** (Optional): For advanced users who want to query their voice notes:
   - Install the [Dataview plugin](https://github.com/blacksmithgu/obsidian-dataview) from the Community plugins
   - Voice notes include YAML frontmatter with properties like `date`, `duration`, and `daily` that can be queried
   - Example query to list all voice notes: ```dataview
table duration, daily from "Voice Notes"
```

## Technical Notes

- The app uses security-scoped bookmarks to maintain access to the Obsidian vault between app launches
- Voice recordings are saved in the app's Documents directory
- Transcription is done using file-based processing rather than live recognition for better stability
- The app creates "Voice Notes" and "Attachments" directories in your Obsidian vault
- Voice notes include both YAML frontmatter properties and proper Obsidian backlinks to daily notes
- Backlinks ensure your voice notes appear in the graph view and backlinks panel
- Memory-optimized initialization with staged loading to improve startup performance
- Optimized recording start process for minimal latency and immediate user feedback
- Enhanced transcription reliability with smart retry mechanisms for challenging audio
- Uses the Flexoki color palette for a consistent, warm visual identity

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Credits

- [Flexoki](https://stephango.com/flexoki) color palette by Steph Ango, used under MIT license
- [Anthropic Claude API](https://www.anthropic.com/) for AI processing
- [Obsidian](https://obsidian.md/) for note storage and organization
