import XCTest
@testable import VoiceToObsidian

final class StringFilenameTests: XCTestCase {

    // MARK: - Basic Sanitization

    func testSanitizesColons() {
        XCTAssertEqual("Meeting: Project Review".sanitizedForFilename(), "Meeting- Project Review")
    }

    func testSanitizesSlashes() {
        XCTAssertEqual("Q1/Q2 Planning".sanitizedForFilename(), "Q1-Q2 Planning")
    }

    func testSanitizesQuestionMarks() {
        XCTAssertEqual("What's Next?".sanitizedForFilename(), "What's Next")
    }

    func testSanitizesMultipleInvalidChars() {
        XCTAssertEqual("Test: File/Path?".sanitizedForFilename(), "Test- File-Path")
    }

    func testSanitizesAllInvalidChars() {
        let allInvalid = "a*b\"c/d\\e<f>g:h|i?j[k]l#m^n"
        let result = allInvalid.sanitizedForFilename()
        // Should not contain any invalid characters
        let invalidChars = CharacterSet(charactersIn: "*\"/\\<>:|?[]#^")
        XCTAssertFalse(result.unicodeScalars.contains(where: { invalidChars.contains($0) }))
    }

    // MARK: - Edge Cases

    func testRemovesLeadingDots() {
        XCTAssertEqual(".hidden".sanitizedForFilename(), "hidden")
        XCTAssertEqual("..hidden".sanitizedForFilename(), "hidden")
        XCTAssertEqual("...multiple".sanitizedForFilename(), "multiple")
    }

    func testEmptyStringFallback() {
        XCTAssertEqual("".sanitizedForFilename(), "Untitled Note")
    }

    func testOnlyInvalidCharsFallback() {
        XCTAssertEqual(":::".sanitizedForFilename(), "Untitled Note")
        XCTAssertEqual("???".sanitizedForFilename(), "Untitled Note")
    }

    func testTruncatesLongStrings() {
        let longString = String(repeating: "a", count: 300)
        let result = longString.sanitizedForFilename()
        XCTAssertLessThanOrEqual(result.count, 250)
    }

    func testPreservesValidCharacters() {
        let validTitle = "My Voice Note 2024-01-15"
        XCTAssertEqual(validTitle.sanitizedForFilename(), validTitle)
    }

    func testCollapsesConsecutiveHyphens() {
        XCTAssertEqual("a::b".sanitizedForFilename(), "a-b")
        XCTAssertEqual("a:::b".sanitizedForFilename(), "a-b")
    }

    func testTrimsLeadingTrailingHyphens() {
        XCTAssertEqual(":test:".sanitizedForFilename(), "test")
    }

    // MARK: - Real-World Examples

    func testRealWorldMeetingTitle() {
        XCTAssertEqual(
            "Meeting: Weekly Team Sync".sanitizedForFilename(),
            "Meeting- Weekly Team Sync"
        )
    }

    func testRealWorldQuarterlyPlanning() {
        XCTAssertEqual(
            "Q1/Q2 Budget Review: Final".sanitizedForFilename(),
            "Q1-Q2 Budget Review- Final"
        )
    }

    func testRealWorldQuestionTitle() {
        XCTAssertEqual(
            "What should we do next?".sanitizedForFilename(),
            "What should we do next"
        )
    }
}
