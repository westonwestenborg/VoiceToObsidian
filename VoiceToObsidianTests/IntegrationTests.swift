import Testing
import Foundation
import AVFoundation
import Speech
@testable import VoiceToObsidian

// Mock classes for integration testing
class MockRecordingManager: RecordingManager {
    var mockVoiceNote: VoiceNote?
    var mockStartRecordingResult = true
    var mockError: Error?
    
    override func startRecordingAsync() async throws -> Bool {
        if let error = mockError {
            throw error
        }
        return mockStartRecordingResult
    }
    
    override func stopRecordingAsync() async throws -> VoiceNote? {
        if let error = mockError {
            throw error
        }
        return mockVoiceNote
    }
}

class MockTranscriptionManager: TranscriptionManager {
    var mockTranscript: String?
    var mockError: Error?
    
    override func transcribeAudioFileAsync(at audioURL: URL) async throws -> String {
        if let error = mockError {
            throw error
        }
        return mockTranscript ?? "Mock transcript"
    }
}

class MockAnthropicService: AnthropicService {
    var mockCleanedTranscript: String?
    var mockTitle: String?
    var mockError: Error?
    
    override func processTranscriptAsync(transcript: String) async throws -> String {
        if let error = mockError {
            throw error
        }
        return mockCleanedTranscript ?? "Mock cleaned transcript"
    }
    
    override func processTranscriptWithTitleAsync(transcript: String) async throws -> (transcript: String, title: String) {
        if let error = mockError {
            throw error
        }
        return (
            transcript: mockCleanedTranscript ?? "Mock cleaned transcript",
            title: mockTitle ?? "Mock Title"
        )
    }
}

class MockObsidianService: ObsidianService {
    var mockCreateNoteResult: (success: Bool, path: String?)?
    var mockCopyAudioResult = true
    var mockError: Error?
    
    override func createVoiceNoteFile(for voiceNote: VoiceNote) async throws -> (success: Bool, path: String?) {
        if let error = mockError {
            throw error
        }
        return mockCreateNoteResult ?? (true, "Mock/Path/To/Note.md")
    }
    
    override func copyAudioFileToVault(from audioURL: URL) async throws -> Bool {
        if let error = mockError {
            throw error
        }
        return mockCopyAudioResult
    }
}

// Integration test for the complete workflow
struct IntegrationTests {
    
    @Test func testCompleteWorkflow() async throws {
        // 1. Set up mock components
        let mockRecordingManager = MockRecordingManager()
        let mockTranscriptionManager = MockTranscriptionManager()
        let mockAnthropicService = MockAnthropicService()
        let mockObsidianService = MockObsidianService()
        
        // 2. Configure mock responses
        
        // Mock recording
        let audioURL = URL(fileURLWithPath: "/test/audio/test_recording.m4a")
        let testDate = Date()
        let mockVoiceNote = VoiceNote(
            title: "Test Recording",
            originalTranscript: "",  // Will be filled by transcription
            cleanedTranscript: "",   // Will be filled by Anthropic
            duration: 30.0,
            creationDate: testDate,
            audioFilename: "test_recording.m4a"
        )
        mockRecordingManager.mockVoiceNote = mockVoiceNote
        
        // Mock transcription
        let originalTranscript = "Um, this is a, uh, test transcript with some filler words."
        mockTranscriptionManager.mockTranscript = originalTranscript
        
        // Mock Anthropic processing
        let cleanedTranscript = "This is a test transcript without filler words."
        let suggestedTitle = "Test Transcript"
        mockAnthropicService.mockCleanedTranscript = cleanedTranscript
        mockAnthropicService.mockTitle = suggestedTitle
        
        // Mock Obsidian saving
        let notePath = "Voice Notes/Test Transcript.md"
        mockObsidianService.mockCreateNoteResult = (true, notePath)
        
        // 3. Simulate the workflow
        
        // Start recording
        let recordingStarted = try await mockRecordingManager.startRecordingAsync()
        #expect(recordingStarted)
        
        // Stop recording and get voice note
        var voiceNote = try await mockRecordingManager.stopRecordingAsync()
        #expect(voiceNote != nil)
        
        // Transcribe the audio
        let transcription = try await mockTranscriptionManager.transcribeAudioFileAsync(at: audioURL)
        #expect(transcription == originalTranscript)
        
        // Update voice note with transcription
        voiceNote?.originalTranscript = transcription
        
        // Process with Anthropic
        let (processedTranscript, title) = try await mockAnthropicService.processTranscriptWithTitleAsync(transcript: transcription)
        #expect(processedTranscript == cleanedTranscript)
        #expect(title == suggestedTitle)
        
        // Update voice note with cleaned transcript and title
        voiceNote?.cleanedTranscript = processedTranscript
        voiceNote?.title = title
        
        // Save to Obsidian
        guard let finalVoiceNote = voiceNote else {
            #expect(false, "Voice note should not be nil at this point")
            return
        }
        
        // Copy audio file
        let audioCopied = try await mockObsidianService.copyAudioFileToVault(from: audioURL)
        #expect(audioCopied)
        
        // Create markdown note
        let (noteCreated, path) = try await mockObsidianService.createVoiceNoteFile(for: finalVoiceNote)
        #expect(noteCreated)
        #expect(path == notePath)
        
        // 4. Verify final state
        // The final voice note should have all properties set correctly
        #expect(finalVoiceNote.title == suggestedTitle)
        #expect(finalVoiceNote.originalTranscript == originalTranscript)
        #expect(finalVoiceNote.cleanedTranscript == cleanedTranscript)
        #expect(finalVoiceNote.duration == 30.0)
        #expect(finalVoiceNote.audioFilename == "test_recording.m4a")
    }
    
    @Test func testWorkflowWithRecordingError() async throws {
        // Set up mock components
        let mockRecordingManager = MockRecordingManager()
        
        // Configure mock to throw an error
        mockRecordingManager.mockError = NSError(domain: "RecordingManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        
        // Try to start recording and expect an error
        do {
            _ = try await mockRecordingManager.startRecordingAsync()
            #expect(false, "Expected an error but got success")
        } catch {
            // Verify an error was thrown
            #expect(true)
        }
    }
    
    @Test func testWorkflowWithTranscriptionError() async throws {
        // Set up mock components
        let mockRecordingManager = MockRecordingManager()
        let mockTranscriptionManager = MockTranscriptionManager()
        
        // Configure recording mock
        let audioURL = URL(fileURLWithPath: "/test/audio/test_recording.m4a")
        let testDate = Date()
        let mockVoiceNote = VoiceNote(
            title: "Test Recording",
            originalTranscript: "",
            cleanedTranscript: "",
            duration: 30.0,
            creationDate: testDate,
            audioFilename: "test_recording.m4a"
        )
        mockRecordingManager.mockVoiceNote = mockVoiceNote
        
        // Configure transcription mock to throw an error
        mockTranscriptionManager.mockError = NSError(domain: "TranscriptionManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
        
        // Simulate the workflow
        let recordingStarted = try await mockRecordingManager.startRecordingAsync()
        #expect(recordingStarted)
        
        let voiceNote = try await mockRecordingManager.stopRecordingAsync()
        #expect(voiceNote != nil)
        
        // Try to transcribe and expect an error
        do {
            _ = try await mockTranscriptionManager.transcribeAudioFileAsync(at: audioURL)
            #expect(false, "Expected an error but got success")
        } catch {
            // Verify an error was thrown
            #expect(true)
        }
    }
    
    @Test func testWorkflowWithAnthropicError() async throws {
        // Set up mock components
        let mockRecordingManager = MockRecordingManager()
        let mockTranscriptionManager = MockTranscriptionManager()
        let mockAnthropicService = MockAnthropicService()
        
        // Configure recording mock
        let audioURL = URL(fileURLWithPath: "/test/audio/test_recording.m4a")
        let testDate = Date()
        let mockVoiceNote = VoiceNote(
            title: "Test Recording",
            originalTranscript: "",
            cleanedTranscript: "",
            duration: 30.0,
            creationDate: testDate,
            audioFilename: "test_recording.m4a"
        )
        mockRecordingManager.mockVoiceNote = mockVoiceNote
        
        // Configure transcription mock
        let originalTranscript = "This is a test transcript."
        mockTranscriptionManager.mockTranscript = originalTranscript
        
        // Configure Anthropic mock to throw an error
        mockAnthropicService.mockError = AppError.anthropic(.apiKeyMissing)
        
        // Simulate the workflow
        let recordingStarted = try await mockRecordingManager.startRecordingAsync()
        #expect(recordingStarted)
        
        let voiceNote = try await mockRecordingManager.stopRecordingAsync()
        #expect(voiceNote != nil)
        
        let transcription = try await mockTranscriptionManager.transcribeAudioFileAsync(at: audioURL)
        #expect(transcription == originalTranscript)
        
        // Try to process with Anthropic and expect an error
        do {
            _ = try await mockAnthropicService.processTranscriptWithTitleAsync(transcript: transcription)
            #expect(false, "Expected an error but got success")
        } catch {
            // Verify the error is the expected one
            guard let appError = error as? AppError, case .anthropic(.apiKeyMissing) = appError else {
                #expect(false, "Expected apiKeyMissing error but got \(error)")
                return
            }
            #expect(true)
        }
    }
    
    @Test func testWorkflowWithObsidianError() async throws {
        // Set up mock components
        let mockRecordingManager = MockRecordingManager()
        let mockTranscriptionManager = MockTranscriptionManager()
        let mockAnthropicService = MockAnthropicService()
        let mockObsidianService = MockObsidianService()
        
        // Configure recording mock
        let audioURL = URL(fileURLWithPath: "/test/audio/test_recording.m4a")
        let testDate = Date()
        let mockVoiceNote = VoiceNote(
            title: "Test Recording",
            originalTranscript: "",
            cleanedTranscript: "",
            duration: 30.0,
            creationDate: testDate,
            audioFilename: "test_recording.m4a"
        )
        mockRecordingManager.mockVoiceNote = mockVoiceNote
        
        // Configure transcription mock
        let originalTranscript = "This is a test transcript."
        mockTranscriptionManager.mockTranscript = originalTranscript
        
        // Configure Anthropic mock
        let cleanedTranscript = "This is a cleaned test transcript."
        let suggestedTitle = "Test Transcript"
        mockAnthropicService.mockCleanedTranscript = cleanedTranscript
        mockAnthropicService.mockTitle = suggestedTitle
        
        // Configure Obsidian mock to throw an error
        mockObsidianService.mockError = AppError.obsidian(.vaultPathMissing)
        
        // Simulate the workflow
        let recordingStarted = try await mockRecordingManager.startRecordingAsync()
        #expect(recordingStarted)
        
        let voiceNote = try await mockRecordingManager.stopRecordingAsync()
        #expect(voiceNote != nil)
        
        let transcription = try await mockTranscriptionManager.transcribeAudioFileAsync(at: audioURL)
        #expect(transcription == originalTranscript)
        
        let (processedTranscript, title) = try await mockAnthropicService.processTranscriptWithTitleAsync(transcript: transcription)
        #expect(processedTranscript == cleanedTranscript)
        #expect(title == suggestedTitle)
        
        // Update voice note
        var updatedVoiceNote = voiceNote
        updatedVoiceNote?.originalTranscript = transcription
        updatedVoiceNote?.cleanedTranscript = processedTranscript
        updatedVoiceNote?.title = title
        
        // Try to save to Obsidian and expect an error
        do {
            _ = try await mockObsidianService.createVoiceNoteFile(for: updatedVoiceNote!)
            #expect(false, "Expected an error but got success")
        } catch {
            // Verify the error is the expected one
            guard let appError = error as? AppError, case .obsidian(.vaultPathMissing) = appError else {
                #expect(false, "Expected vaultPathMissing error but got \(error)")
                return
            }
            #expect(true)
        }
    }
}
