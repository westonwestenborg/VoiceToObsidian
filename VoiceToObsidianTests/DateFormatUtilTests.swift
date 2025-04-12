import Testing
import Foundation
@testable import VoiceToObsidian

struct DateFormatUtilTests {
    
    @Test func testFormattedDate() async throws {
        // Create a specific date for testing (January 15, 2025, 10:30 AM)
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 10
        components.minute = 30
        components.second = 0
        
        let testDate = calendar.date(from: components)!
        
        // Get formatted date
        let formattedDate = DateFormatUtil.shared.formattedDate(testDate)
        
        // Since the exact format depends on locale settings, we'll check for expected components
        #expect(formattedDate.contains("2025") || formattedDate.contains("25"))
        #expect(formattedDate.contains("Jan") || formattedDate.contains("1") || formattedDate.contains("01"))
        #expect(formattedDate.contains("15"))
        #expect(formattedDate.contains("10:30") || formattedDate.contains("10.30"))
    }
    
    @Test func testFormattedDateSpoken() async throws {
        // Create a specific date for testing
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 10
        components.minute = 30
        components.second = 0
        
        let testDate = calendar.date(from: components)!
        
        // Get spoken date format
        let spokenDate = DateFormatUtil.shared.formattedDateSpoken(testDate)
        
        // Check for expected components in the spoken format
        #expect(spokenDate.contains("2025"))
        #expect(spokenDate.contains("January") || spokenDate.contains("Jan"))
        #expect(spokenDate.contains("15"))
        #expect(spokenDate.contains("10:30") || spokenDate.contains("10.30"))
    }
    
    @Test func testFormatTimestamp() async throws {
        // Create a specific date for testing
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 10
        components.minute = 30
        components.second = 45
        
        let testDate = calendar.date(from: components)!
        
        // Get timestamp format
        let timestamp = DateFormatUtil.shared.formatTimestamp(date: testDate)
        
        // Check exact format for timestamp (this should be locale-independent)
        #expect(timestamp == "2025-01-15 10:30:45")
    }
    
    @Test func testFormatTimeShort() async throws {
        // Test various time intervals
        let oneMinuteThirtySeconds: TimeInterval = 90
        let threeMinutes: TimeInterval = 180
        let tenSeconds: TimeInterval = 10
        
        // Format the intervals
        let formatted90Seconds = DateFormatUtil.shared.formatTimeShort(oneMinuteThirtySeconds)
        let formatted180Seconds = DateFormatUtil.shared.formatTimeShort(threeMinutes)
        let formatted10Seconds = DateFormatUtil.shared.formatTimeShort(tenSeconds)
        
        // Check the formatted strings
        #expect(formatted90Seconds == "1:30")
        #expect(formatted180Seconds == "3:00")
        #expect(formatted10Seconds == "0:10")
    }
    
    @Test func testFormatTimeSpoken() async throws {
        // Test various time intervals
        let oneMinuteThirtySeconds: TimeInterval = 90
        let threeMinutes: TimeInterval = 180
        let oneSecond: TimeInterval = 1
        let tenSeconds: TimeInterval = 10
        
        // Format the intervals
        let formatted90Seconds = DateFormatUtil.shared.formatTimeSpoken(oneMinuteThirtySeconds)
        let formatted180Seconds = DateFormatUtil.shared.formatTimeSpoken(threeMinutes)
        let formatted1Second = DateFormatUtil.shared.formatTimeSpoken(oneSecond)
        let formatted10Seconds = DateFormatUtil.shared.formatTimeSpoken(tenSeconds)
        
        // Check the formatted strings
        #expect(formatted90Seconds == "1 minute and 30 seconds")
        #expect(formatted180Seconds == "3 minutes and 0 seconds")
        #expect(formatted1Second == "1 second")
        #expect(formatted10Seconds == "10 seconds")
    }
}
