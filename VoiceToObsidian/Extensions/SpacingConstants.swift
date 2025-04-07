import SwiftUI

/// Standard spacing constants to ensure consistent UI spacing throughout the app
struct Spacing {
    /// Tight spacing (8pt) for closely related elements
    static let tight: CGFloat = 8
    
    /// Standard spacing (16pt) for general element separation
    static let standard: CGFloat = 16
    
    /// Loose spacing (24pt) for major section separation
    static let loose: CGFloat = 24
    
    /// Standard horizontal margin for screens (16pt on iPhone)
    static let horizontalMargin: CGFloat = 16
    
    /// Standard touch target size (44pt) per Apple HIG
    static let minimumTouchTarget: CGFloat = 44
}
