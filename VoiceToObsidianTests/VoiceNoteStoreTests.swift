//
//  VoiceNoteStoreTests.swift
//  VoiceToObsidianTests
//
//  Created by Claude Code on 1/20/26.
//

import Testing
import Foundation
@testable import VoiceToObsidian

@MainActor
@Suite("VoiceNoteStore Tests", .serialized)
struct VoiceNoteStoreTests {

    /// Helper to clean up test data
    private func cleanupTestData() {
        // Clear the hasLaunchedBefore flag
        UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")

        // Remove voice notes file
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let voiceNotesURL = documentsDirectory.appendingPathComponent("voiceNotes.json")
            try? FileManager.default.removeItem(at: voiceNotesURL)
        }
    }

    @Test("Welcome note created on first launch")
    func testWelcomeNoteCreatedOnFirstLaunch() async {
        // Clean up before test
        cleanupTestData()

        // Create a new store with lazy init
        let store = await VoiceNoteStore(lazyInit: true)

        // Load notes (should trigger welcome note creation)
        await store.loadMoreVoiceNotes()

        // Wait for async operations
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Verify welcome note was created
        let notes = await store.voiceNotes
        #expect(!notes.isEmpty, "Should have at least one note")
        #expect(notes.first?.title == "Welcome to Coati", "First note should be welcome note")

        // Verify flag was set
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        #expect(hasLaunched, "hasLaunchedBefore should be true")

        // Clean up after test
        cleanupTestData()
    }

    @Test("Welcome note not duplicated on subsequent launches")
    func testWelcomeNoteNotDuplicated() async {
        // Clean up before test
        cleanupTestData()

        // Set the hasLaunchedBefore flag to simulate second launch
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")

        // Create a new store
        let store = await VoiceNoteStore(lazyInit: true)

        // Load notes
        await store.loadMoreVoiceNotes()

        // Wait for async operations
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Verify no welcome note was added
        let notes = await store.voiceNotes
        let welcomeNotes = notes.filter { $0.title == "Welcome to Coati" }
        #expect(welcomeNotes.isEmpty, "Should not create welcome note on subsequent launches")

        // Clean up after test
        cleanupTestData()
    }
}
