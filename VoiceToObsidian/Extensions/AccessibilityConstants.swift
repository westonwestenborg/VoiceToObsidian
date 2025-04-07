import SwiftUI

/// Constants and modifiers to improve accessibility throughout the app
struct Accessibility {
    /// Standard dynamic type size range that works well for most UI elements
    /// - Small: Allows for smaller text for users who prefer it
    /// - Accessibility5: Supports larger text for users with visual impairments
    static let standardDynamicTypeRange: ClosedRange<DynamicTypeSize> = .small...(.accessibility5)
    
    /// Minimum tap target size (44pt) per Apple Human Interface Guidelines
    static let minimumTapTargetSize: CGFloat = 44
    
    /// Standard corner radius for UI elements
    static let standardCornerRadius: CGFloat = 8
    
    /// Large corner radius for prominent UI elements
    static let largeCornerRadius: CGFloat = 12
}

// MARK: - View Modifiers

/// Applies standard accessibility settings to buttons
struct AccessibleButtonStyle: ViewModifier {
    var isPrimary: Bool = true
    var isDestructive: Bool = false
    
    func body(content: Content) -> some View {
        content
            .frame(minHeight: Accessibility.minimumTapTargetSize)
            .dynamicTypeSize(Accessibility.standardDynamicTypeRange)
            .if(isPrimary) { view in
                view.foregroundColor(Color.flexokiPaper)
                    .background(isDestructive ? Color.flexokiRed : Color.flexokiAccentBlue)
                    .cornerRadius(Accessibility.standardCornerRadius)
            }
            .if(!isPrimary) { view in
                view.foregroundColor(isDestructive ? Color.flexokiRed : Color.flexokiAccentBlue)
                    .background(Color.flexokiBackground)
                    .cornerRadius(Accessibility.standardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Accessibility.standardCornerRadius)
                            .stroke(isDestructive ? Color.flexokiRed : Color.flexokiAccentBlue, lineWidth: 1)
                    )
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a condition to a view
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Applies standard accessibility settings to a primary button
    func accessibleButton(isPrimary: Bool = true, isDestructive: Bool = false) -> some View {
        self.modifier(AccessibleButtonStyle(isPrimary: isPrimary, isDestructive: isDestructive))
    }
    
    /// Applies standard text style with proper dynamic type support
    func accessibleText(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: size, weight: weight))
            .dynamicTypeSize(Accessibility.standardDynamicTypeRange)
    }
}
