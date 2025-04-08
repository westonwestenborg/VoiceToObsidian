import Foundation

struct DateFormatUtil {
    static let shared = DateFormatUtil()
    
    private let standardDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let spokenDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    // Format a Date in "MMM d, h:mm a" style
    func formattedDate(_ date: Date) -> String {
        return standardDateFormatter.string(from: date)
    }
    
    // Format a Date with longer, voice-friendly style
    func formattedDateSpoken(_ date: Date) -> String {
        return spokenDateFormatter.string(from: date)
    }
    
    // Format a Date in timestamp format (yyyy-MM-dd HH:mm:ss)
    func formatTimestamp(date: Date) -> String {
        return timestampFormatter.string(from: date)
    }

    // Format TimeInterval as mm:ss for short usage
    func formatTimeShort(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // A more advanced or spoken style: "X minute(s) and Y second(s)"
    func formatTimeSpoken(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") and \(seconds) second\(seconds == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
    }
}
