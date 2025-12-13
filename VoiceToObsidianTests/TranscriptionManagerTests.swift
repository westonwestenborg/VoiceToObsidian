//
//  TranscriptionManagerTests.swift
//  VoiceToObsidianTests
//
//  Tests for TranscriptionManager using @MainActor isolation pattern.
//  These tests verify initial state and safe methods without requiring
//  SFSpeechRecognizer or device authorization.

import Testing
import Foundation
@testable import VoiceToObsidian

@MainActor
struct TranscriptionManagerTests {

    // MARK: - Initial State Tests

    @Test func initialStateIsNotTranscribing() async {
        let manager = TranscriptionManager()
        #expect(manager.isTranscribing == false)
    }

    @Test func initialProgressIsZero() async {
        let manager = TranscriptionManager()
        #expect(manager.transcriptionProgress == 0)
    }

    // MARK: - Safe Method Tests

    @Test func cancelWhenNotTranscribingIsSafe() async {
        let manager = TranscriptionManager()
        // Should not crash when called without active transcription
        manager.cancelTranscription()
        #expect(manager.isTranscribing == false)
    }

    // MARK: - Error Condition Tests
    // Note: Tests that call transcribeAudioFileAsync are disabled because they
    // require speech recognition authorization and may hang waiting for timeouts.
    // These should be tested via integration tests on a real device.
}
