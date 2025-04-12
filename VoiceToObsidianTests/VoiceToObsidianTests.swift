//
//  VoiceToObsidianTests.swift
//  VoiceToObsidianTests
//
//  Created by Weston Westenborg on 4/8/25.
//

import Testing
@testable import VoiceToObsidian

struct VoiceToObsidianTests {
    // Main test suite that includes all other test suites
    
    @Test func testDateFormatUtil() async throws {
        try await DateFormatUtilTests().testFormattedDate()
        try await DateFormatUtilTests().testFormattedDateSpoken()
        try await DateFormatUtilTests().testFormatTimestamp()
        try await DateFormatUtilTests().testFormatTimeShort()
        try await DateFormatUtilTests().testFormatTimeSpoken()
    }
    
    @Test func testRecordingManager() async throws {
        try await RecordingManagerTests().testInitialization()
        try await RecordingManagerTests().testGetCurrentRecordingURL()
        try await RecordingManagerTests().testGetRecordingStartTime()
        try await RecordingManagerTests().testResetRecordingDuration()
    }
    
    @Test func testTranscriptionManager() async throws {
        try await TranscriptionManagerTests().testInitialization()
        try await TranscriptionManagerTests().testCancelTranscription()
    }
    
    @Test func testAnthropicService() async throws {
        try await AnthropicServiceTests().testInitialization()
        try await AnthropicServiceTests().testParseResponse()
        try await AnthropicServiceTests().testParseResponseWithMissingTitle()
        try await AnthropicServiceTests().testParseResponseWithMissingTranscript()
        try await AnthropicServiceTests().testProcessTranscriptAsyncSuccess()
        try await AnthropicServiceTests().testProcessTranscriptAsyncMissingAPIKey()
        try await AnthropicServiceTests().testProcessTranscriptAsyncHTTPError()
    }
    
    @Test func testObsidianService() async throws {
        try await ObsidianServiceTests().testInitialization()
        try await ObsidianServiceTests().testCreateVoiceNoteFileSuccess()
        try await ObsidianServiceTests().testCreateVoiceNoteFileMissingVaultPath()
        try await ObsidianServiceTests().testCopyAudioFileToVaultSuccess()
        try await ObsidianServiceTests().testCopyAudioFileToVaultMissingVaultPath()
        try await ObsidianServiceTests().testCopyAudioFileToVaultSourceNotFound()
    }
    
    @Test func testIntegration() async throws {
        try await IntegrationTests().testCompleteWorkflow()
        try await IntegrationTests().testWorkflowWithRecordingError()
        try await IntegrationTests().testWorkflowWithTranscriptionError()
        try await IntegrationTests().testWorkflowWithAnthropicError()
        try await IntegrationTests().testWorkflowWithObsidianError()
    }
}
