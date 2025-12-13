import Foundation

extension String {
    /// Characters invalid in Obsidian filenames across all platforms
    /// Includes: * " / \ < > : | ? [ ] # ^
    private static let invalidFilenameCharacters = CharacterSet(charactersIn: "*\"/\\<>:|?[]#^")

    /// Sanitizes a string for use as an Obsidian-compatible filename.
    /// - Replaces invalid characters with hyphens
    /// - Removes leading dots (hidden files)
    /// - Truncates to 250 characters (leaving room for .md extension)
    /// - Falls back to "Untitled Note" if result is empty
    func sanitizedForFilename() -> String {
        // Replace invalid characters with hyphens
        var sanitized = self.unicodeScalars
            .map { Self.invalidFilenameCharacters.contains($0) ? "-" : String($0) }
            .joined()

        // Collapse multiple consecutive hyphens into one
        while sanitized.contains("--") {
            sanitized = sanitized.replacingOccurrences(of: "--", with: "-")
        }

        // Remove leading/trailing hyphens and whitespace
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-").union(.whitespaces))

        // Remove leading dots (hidden files)
        while sanitized.hasPrefix(".") {
            sanitized = String(sanitized.dropFirst())
        }

        // Truncate to safe length (APFS limit is 255, leave room for .md)
        if sanitized.count > 250 {
            sanitized = String(sanitized.prefix(250))
            // Don't end with hyphen or space after truncation
            sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-").union(.whitespaces))
        }

        // Fallback for empty result
        if sanitized.trimmingCharacters(in: .whitespaces).isEmpty {
            sanitized = "Untitled Note"
        }

        return sanitized
    }
}
