//
//  RecordingManagerTests.swift
//  VoiceToObsidianTests
//
//  Tests for RecordingManager using @MainActor isolation pattern.
//  These tests verify initial state and safe methods without requiring
//  AVAudioSession or device permissions.

import Testing
import Foundation
@testable import VoiceToObsidian

@MainActor
struct RecordingManagerTests {

    // MARK: - Initial State Tests

    @Test func initialStateIsNotRecording() async {
        let manager = RecordingManager()
        #expect(manager.isRecording == false)
    }

    @Test func initialDurationIsZero() async {
        let manager = RecordingManager()
        #expect(manager.recordingDuration == 0)
    }

    @Test func initialRecordingURLIsNil() async {
        let manager = RecordingManager()
        #expect(manager.getCurrentRecordingURL() == nil)
    }

    @Test func initialStartTimeIsNil() async {
        let manager = RecordingManager()
        #expect(manager.getRecordingStartTime() == nil)
    }

    // MARK: - Safe Method Tests

    @Test func resetDurationSetsToZero() async {
        let manager = RecordingManager()
        manager.resetRecordingDuration()
        #expect(manager.recordingDuration == 0)
    }

    // MARK: - Error Condition Tests

    @Test func stopRecordingWhenNotRecordingThrows() async {
        let manager = RecordingManager()

        do {
            _ = try await manager.stopRecordingAsync()
            Issue.record("Expected error but got success")
        } catch {
            // Expected - should throw when not recording
            #expect(true)
        }
    }
}
