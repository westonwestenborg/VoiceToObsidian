import SwiftUI
import OSLog

/// A styled section view for the CustomWordsView to ensure consistent Flexoki styling
private struct CustomWordsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .flexokiHeading2()
                .padding(.bottom, 4)
            
            content
                .padding(.horizontal, 4)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.flexokiBackground)
        .cornerRadius(8)
    }
}

/// A view for managing custom words and phrases used to improve transcription accuracy.
///
/// This view provides a dedicated interface for users to add, edit, and remove custom words
/// or phrases that they commonly use. These words are used by Claude to improve transcription
/// accuracy when processing voice notes.
struct CustomWordsView: View {
    /// The manager that handles the persistence of custom words.
    @ObservedObject var customWordsManager: CustomWordsManager
    
    /// Text for the new word being added.
    @State private var newWord = ""
    
    /// Index of the word currently being edited, if any.
    @State private var editingIndex: Int? = nil
    
    /// Text for the word being edited.
    @State private var editingText = ""
    
    /// Environment to dismiss the view.
    @Environment(\.dismiss) private var dismiss
    
    /// Logger for structured logging.
    private let logger = Logger(subsystem: "com.voicetoobsidian.app", category: "CustomWordsView")
    
    /// Animation duration for transitions
    private let animationDuration: Double = 0.3
    
    var body: some View {
        ZStack {
            // Background color
            Color.flexokiBackground
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Add New Word Section
                    CustomWordsSection("Add New Word or Phrase") {
                        HStack(spacing: 12) {
                            TextField("New word or phrase", text: $newWord)
                                .modifier(FlexokiTheme.textInput())
                                .submitLabel(.done)
                                .onSubmit {
                                    addWord()
                                }
                            
                            Button(action: addWord) {
                                Label("Add", systemImage: "plus.circle.fill")
                                    .labelStyle(.iconOnly)
                                    .font(.system(size: 24))
                            }
                            .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .flexokiPrimaryButton()
                            .frame(width: 44, height: 44)
                        }
                    }
                    
                    // Custom Words List Section
                    if !customWordsManager.customWords.isEmpty {
                        CustomWordsSection("Your Custom Words") {
                            VStack(spacing: 0) {
                                ForEach(Array(customWordsManager.customWords.enumerated()), id: \.0) { pair in
                                    let (index, word) = pair
                                    if editingIndex == index {
                                        // Editing mode
                                        VStack(spacing: 8) {
                                            TextField("Edit word", text: $editingText)
                                                .modifier(FlexokiTheme.textInput())
                                            
                                            HStack(spacing: 12) {
                                                Button("Save") {
                                                    saveEdit(at: index)
                                                }
                                                .flexokiPrimaryButton()
                                                .disabled(editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                                
                                                Button("Cancel") {
                                                    cancelEdit()
                                                }
                                                .flexokiDestructiveSecondaryButton()
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                        .animation(.easeInOut(duration: animationDuration), value: editingIndex)
                                    } else {
                                        // Display mode
                                        HStack {
                                            Text(word)
                                                .flexokiBodyText()
                                                .padding(.vertical, 8)
                                            Spacer()
                                            
                                            HStack(spacing: 16) {
                                                Button(action: {
                                                    startEditing(word: word, at: index)
                                                }) {
                                                    Label("Edit", systemImage: "pencil")
                                                        .labelStyle(.iconOnly)
                                                }
                                                .foregroundColor(.flexokiAccentBlue)
                                                
                                                Button(action: {
                                                    deleteWord(at: index)
                                                }) {
                                                    Label("Delete", systemImage: "trash")
                                                        .labelStyle(.iconOnly)
                                                }
                                                .foregroundColor(.flexokiRed)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .transition(.opacity)
                                        .animation(.easeInOut(duration: animationDuration), value: editingIndex)
                                    }
                                    
                                    if index < customWordsManager.customWords.count - 1 {
                                        Divider()
                                            .background(Color.flexokiUI)
                                            .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                    } else {
                        // Empty state
                        CustomWordsSection("Your Custom Words") {
                            VStack(alignment: .center, spacing: 12) {
                                Image(systemName: "text.badge.plus")
                                    .font(.system(size: 36))
                                    .foregroundColor(.flexokiText2)
                                    .padding(.top, 8)
                                
                                Text("No custom words added yet")
                                    .flexokiHeading2()
                                
                                Text("Add words or phrases you commonly use to improve transcription accuracy.")
                                    .flexokiCaptionText()
                                    .multilineTextAlignment(.center)
                                    .padding(.bottom, 8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // About Section
                    CustomWordsSection("About Custom Words") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Custom words help improve transcription accuracy. When you add words or phrases you commonly use, they'll be included as context when cleaning up your voice notes.")
                                .flexokiCaptionText()
                            
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.flexokiYellow)
                                    .font(.system(size: 16))
                                
                                Text("Tip: Add names, technical terms, or any words that are frequently misheard in your recordings.")
                                    .flexokiCaptionText()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Custom Words")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Log view appearance
            logger.debug("CustomWordsView appeared with \(customWordsManager.customWords.count) custom words")
        }
    }
    
    /// Adds a new word to the custom words list.
    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        withAnimation(.easeInOut(duration: animationDuration)) {
            customWordsManager.addWord(trimmed)
            newWord = ""
        }
        logger.debug("Added new custom word: \(trimmed)")
    }
    
    /// Starts editing a word.
    /// - Parameters:
    ///   - word: The word to edit
    ///   - index: The index of the word in the list
    private func startEditing(word: String, at index: Int) {
        editingIndex = index
        editingText = word
    }
    
    /// Saves the edited word.
    /// - Parameter index: The index of the word being edited
    private func saveEdit(at index: Int) {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        withAnimation(.easeInOut(duration: animationDuration)) {
            customWordsManager.updateWord(at: index, with: trimmed)
            cancelEdit()
        }
        logger.debug("Updated custom word at index \(index) to: \(trimmed)")
    }
    
    /// Cancels the current edit operation.
    private func cancelEdit() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            editingIndex = nil
            editingText = ""
        }
    }
    
    /// Deletes a word from the custom words list.
    /// - Parameter index: The index of the word to delete
    private func deleteWord(at index: Int) {
        withAnimation(.easeInOut(duration: animationDuration)) {
            customWordsManager.removeWord(at: IndexSet(integer: index))
        }
        logger.debug("Deleted custom word at index \(index)")
    }
}

struct CustomWordsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CustomWordsView(customWordsManager: CustomWordsManager.shared)
        }
    }
}
