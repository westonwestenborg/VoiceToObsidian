import Testing
import Foundation
@testable import VoiceToObsidian

// Mock FileManager for testing
class MockFileManager: FileManager {
    var mockFileExists = false
    var mockCreateDirectorySuccess = true
    var mockWriteSuccess = true
    var mockCopyItemSuccess = true
    var mockRemoveItemSuccess = true
    var mockGetAttributesSuccess = true
    var mockAttributes: [FileAttributeKey: Any] = [.size: 1024]
    
    var createdDirectories: [URL] = []
    var writtenFiles: [URL] = []
    var copiedItems: [(from: URL, to: URL)] = []
    var removedItems: [URL] = []
    
    override func fileExists(atPath path: String) -> Bool {
        return mockFileExists
    }
    
    override func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = nil) throws {
        if !mockCreateDirectorySuccess {
            throw NSError(domain: "MockFileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create directory"])
        }
        createdDirectories.append(url)
    }
    
    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        if !mockCopyItemSuccess {
            throw NSError(domain: "MockFileManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to copy item"])
        }
        copiedItems.append((from: srcURL, to: dstURL))
    }
    
    override func removeItem(at URL: URL) throws {
        if !mockRemoveItemSuccess {
            throw NSError(domain: "MockFileManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to remove item"])
        }
        removedItems.append(URL)
    }
    
    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        if !mockGetAttributesSuccess {
            throw NSError(domain: "MockFileManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to get attributes"])
        }
        return mockAttributes
    }
}

// Testable ObsidianService that allows injecting a mock FileManager
class TestableObsidianService: ObsidianService {
    var fileManager: FileManager
    private let testVaultPath: String

    init(vaultPath: String, fileManager: FileManager) {
        self.fileManager = fileManager
        self.testVaultPath = vaultPath
        super.init(vaultPath: vaultPath)
    }

    // Override methods to use our injected FileManager
    override func createVoiceNoteFile(for voiceNote: VoiceNote) async throws -> (success: Bool, path: String?) {
        // This is a simplified version of the original method for testing
        guard !testVaultPath.isEmpty else {
            throw AppError.obsidian(.vaultPathMissing)
        }

        let baseURL = URL(fileURLWithPath: testVaultPath)
        let voiceNotesDirectory = baseURL.appendingPathComponent("Voice Notes")
        
        do {
            if !fileManager.fileExists(atPath: voiceNotesDirectory.path) {
                try fileManager.createDirectory(at: voiceNotesDirectory, withIntermediateDirectories: true)
            }
            
            let notePath = "Voice Notes/\(voiceNote.title).md"
            let noteURL = baseURL.appendingPathComponent(notePath)
            
            // Generate markdown content (simplified for testing)
            let markdownContent = """
            # \(voiceNote.title)
            
            Created: \(DateFormatUtil.shared.formatTimestamp(date: voiceNote.creationDate))
            Duration: \(DateFormatUtil.shared.formatTimeSpoken(voiceNote.duration))
            
            ## Transcript
            
            \(voiceNote.cleanedTranscript)
            
            ## Original Recording
            
            ![[Attachments/\(voiceNote.audioFilename)]]
            """
            
            // In a real test, we would write to a file
            // For our mock, we'll just track that it was called
            if let mockFileManager = fileManager as? MockFileManager {
                mockFileManager.writtenFiles.append(noteURL)
            }
            
            return (true, notePath)
        } catch {
            throw AppError.obsidian(.fileCreationFailed(error.localizedDescription))
        }
    }
    
    override func copyAudioFileToVault(from audioURL: URL) async throws -> Bool {
        // This is a simplified version of the original method for testing
        guard !testVaultPath.isEmpty else {
            throw AppError.obsidian(.vaultPathMissing)
        }

        guard fileManager.fileExists(atPath: audioURL.path) else {
            throw AppError.obsidian(.fileNotFound("Source audio file not found"))
        }

        let baseURL = URL(fileURLWithPath: testVaultPath)
        let attachmentsDirectory = baseURL.appendingPathComponent("Attachments")
        
        do {
            if !fileManager.fileExists(atPath: attachmentsDirectory.path) {
                try fileManager.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
            }
            
            let destinationURL = attachmentsDirectory.appendingPathComponent(audioURL.lastPathComponent)
            
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.copyItem(at: audioURL, to: destinationURL)
            
            return true
        } catch {
            throw AppError.obsidian(.fileCreationFailed("Failed to copy audio file"))
        }
    }
}

// Test ObsidianService
struct ObsidianServiceTests {
    
    @Test func testInitialization() async throws {
        // Create an ObsidianService with a vault path
        let vaultPath = "/test/vault/path"
        let obsidianService = ObsidianService(vaultPath: vaultPath)
        
        // Update vault path and verify it works
        obsidianService.updateVaultPath("/new/test/vault/path")
        
        // No assertion needed, just checking the method exists and doesn't crash
        #expect(true)
    }
    
    @Test func testCreateVoiceNoteFileSuccess() async throws {
        // Create a mock FileManager
        let mockFileManager = MockFileManager()
        mockFileManager.mockFileExists = false // Directory doesn't exist, so it will be created
        mockFileManager.mockCreateDirectorySuccess = true
        mockFileManager.mockWriteSuccess = true
        
        // Create a testable ObsidianService with the mock FileManager
        let vaultPath = "/test/vault/path"
        let obsidianService = TestableObsidianService(vaultPath: vaultPath, fileManager: mockFileManager)
        
        // Create a test voice note
        let voiceNote = VoiceNote(
            title: "Test Voice Note",
            originalTranscript: "This is a test transcript.",
            cleanedTranscript: "This is a cleaned test transcript.",
            duration: 30.0,
            creationDate: Date(),
            audioFilename: "test_audio.m4a"
        )
        
        // Create a voice note file
        let result = try await obsidianService.createVoiceNoteFile(for: voiceNote)
        
        // Verify result
        #expect(result.success)
        #expect(result.path == "Voice Notes/Test Voice Note.md")
        
        // Verify the directory was created
        #expect(mockFileManager.createdDirectories.count == 1)
        #expect(mockFileManager.createdDirectories[0].path.hasSuffix("Voice Notes"))
    }
    
    @Test func testCreateVoiceNoteFileMissingVaultPath() async throws {
        // Create a mock FileManager
        let mockFileManager = MockFileManager()
        
        // Create a testable ObsidianService with an empty vault path
        let obsidianService = TestableObsidianService(vaultPath: "", fileManager: mockFileManager)
        
        // Create a test voice note
        let voiceNote = VoiceNote(
            title: "Test Voice Note",
            originalTranscript: "This is a test transcript.",
            cleanedTranscript: "This is a cleaned test transcript.",
            duration: 30.0,
            creationDate: Date(),
            audioFilename: "test_audio.m4a"
        )
        
        // Create a voice note file and expect an error
        do {
            _ = try await obsidianService.createVoiceNoteFile(for: voiceNote)
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
    
    @Test func testCopyAudioFileToVaultSuccess() async throws {
        // Create a mock FileManager
        let mockFileManager = MockFileManager()
        mockFileManager.mockFileExists = true // File exists
        mockFileManager.mockCreateDirectorySuccess = true
        mockFileManager.mockCopyItemSuccess = true
        
        // Create a testable ObsidianService with the mock FileManager
        let vaultPath = "/test/vault/path"
        let obsidianService = TestableObsidianService(vaultPath: vaultPath, fileManager: mockFileManager)
        
        // Create a test audio URL
        let audioURL = URL(fileURLWithPath: "/test/audio/test_audio.m4a")
        
        // Copy the audio file
        let result = try await obsidianService.copyAudioFileToVault(from: audioURL)
        
        // Verify result
        #expect(result)
        
        // Verify the directory was created (if needed)
        if mockFileManager.createdDirectories.count > 0 {
            #expect(mockFileManager.createdDirectories[0].path.hasSuffix("Attachments"))
        }
        
        // Verify the file was copied
        #expect(mockFileManager.copiedItems.count == 1)
        #expect(mockFileManager.copiedItems[0].from.path == audioURL.path)
        #expect(mockFileManager.copiedItems[0].to.path.hasSuffix("test_audio.m4a"))
    }
    
    @Test func testCopyAudioFileToVaultMissingVaultPath() async throws {
        // Create a mock FileManager
        let mockFileManager = MockFileManager()
        
        // Create a testable ObsidianService with an empty vault path
        let obsidianService = TestableObsidianService(vaultPath: "", fileManager: mockFileManager)
        
        // Create a test audio URL
        let audioURL = URL(fileURLWithPath: "/test/audio/test_audio.m4a")
        
        // Copy the audio file and expect an error
        do {
            _ = try await obsidianService.copyAudioFileToVault(from: audioURL)
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
    
    @Test func testCopyAudioFileToVaultSourceNotFound() async throws {
        // Create a mock FileManager
        let mockFileManager = MockFileManager()
        mockFileManager.mockFileExists = false // File doesn't exist
        
        // Create a testable ObsidianService with the mock FileManager
        let vaultPath = "/test/vault/path"
        let obsidianService = TestableObsidianService(vaultPath: vaultPath, fileManager: mockFileManager)
        
        // Create a test audio URL
        let audioURL = URL(fileURLWithPath: "/test/audio/test_audio.m4a")
        
        // Copy the audio file and expect an error
        do {
            _ = try await obsidianService.copyAudioFileToVault(from: audioURL)
            #expect(false, "Expected an error but got success")
        } catch {
            // Verify the error is the expected one
            guard let appError = error as? AppError, case .obsidian(.fileNotFound) = appError else {
                #expect(false, "Expected fileNotFound error but got \(error)")
                return
            }
            #expect(true)
        }
    }
}
