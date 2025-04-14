import Foundation

/// A utility structure that centralizes all date and time formatting operations throughout the app.
///
/// `DateFormatUtil` provides a consistent approach to formatting dates and time intervals
/// in various contexts, including UI display and voice output. It maintains a set of
/// pre-configured formatters to ensure consistent formatting across the application.
///
/// This utility follows the singleton pattern with a `shared` instance that should be used
/// for all formatting operations, ensuring consistent date and time representation.
///
/// ## Example Usage
/// ```swift
/// // Format a date for UI display
/// let displayDate = DateFormatUtil.shared.formattedDate(voiceNote.creationDate)
///
/// // Format a date for voice output
/// let spokenDate = DateFormatUtil.shared.formattedDateSpoken(voiceNote.creationDate)
///
/// // Format a time interval for display
/// let duration = DateFormatUtil.shared.formatTimeShort(voiceNote.duration)
/// ```
struct DateFormatUtil {
    /// The shared instance of `DateFormatUtil` that should be used throughout the app.
    ///
    /// Using this shared instance ensures consistent date and time formatting across the application.
    static let shared = DateFormatUtil()
    
    /// A formatter for standard date display in the UI.
    ///
    /// This formatter uses medium date style and short time style, resulting in formats like
    /// "Jan 12, 2023, 3:30 PM" depending on the user's locale settings.
    private let standardDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// A formatter for dates that will be spoken or used in voice contexts.
    ///
    /// This formatter uses long date style and short time style, resulting in more verbose formats
    /// like "January 12, 2023 at 3:30 PM" that are more natural for voice output.
    private let spokenDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// A formatter for technical timestamp representation.
    ///
    /// This formatter uses a fixed format "yyyy-MM-dd HH:mm:ss" (e.g., "2023-01-12 15:30:45"),
    /// which is suitable for logging, file naming, and other technical contexts where
    /// a standardized, sortable format is needed.
    private let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    /// Formats a date for standard display in the UI.
    ///
    /// This method uses the standard date formatter to create a string representation
    /// of the date that is appropriate for display in the user interface.
    ///
    /// - Parameter date: The date to format
    /// - Returns: A formatted string representation of the date (e.g., "Jan 12, 2023, 3:30 PM")
    func formattedDate(_ date: Date) -> String {
        return standardDateFormatter.string(from: date)
    }
    
    /// Formats a date in a longer, voice-friendly style suitable for speech.
    ///
    /// This method uses the spoken date formatter to create a more verbose string representation
    /// of the date that sounds more natural when spoken by a voice assistant or TTS system.
    ///
    /// - Parameter date: The date to format
    /// - Returns: A formatted string representation of the date (e.g., "January 12, 2023 at 3:30 PM")
    func formattedDateSpoken(_ date: Date) -> String {
        return spokenDateFormatter.string(from: date)
    }
    
    /// Formats a date as a technical timestamp.
    ///
    /// This method formats the date in a standardized "yyyy-MM-dd HH:mm:ss" format,
    /// which is suitable for logging, file naming, and other technical contexts.
    ///
    /// - Parameter date: The date to format
    /// - Returns: A formatted timestamp string (e.g., "2023-01-12 15:30:45")
    func formatTimestamp(date: Date) -> String {
        return timestampFormatter.string(from: date)
    }

    /// Formats a time interval in a compact mm:ss format.
    ///
    /// This method converts a time interval (in seconds) to a compact string representation
    /// in the format "mm:ss", which is suitable for displaying recording durations, playback times,
    /// and other time-based measurements in the UI.
    ///
    /// - Parameter interval: The time interval in seconds
    /// - Returns: A formatted string in the format "mm:ss" (e.g., "3:45" for 3 minutes and 45 seconds)
    func formatTimeShort(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formats a time interval in a natural language format suitable for speech.
    ///
    /// This method converts a time interval (in seconds) to a natural language string
    /// representation that sounds natural when spoken, using the format "X minute(s) and Y second(s)"
    /// or just "Y second(s)" for intervals less than a minute.
    ///
    /// - Parameter interval: The time interval in seconds
    /// - Returns: A formatted string in natural language (e.g., "3 minutes and 45 seconds")
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
