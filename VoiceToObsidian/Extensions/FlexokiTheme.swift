import SwiftUI

/// Standardized UI components using the Flexoki theme
struct FlexokiTheme {
    // MARK: - Text Styles
    
    /// Primary heading style
    static func heading1() -> some ViewModifier {
        TextStyle(size: 24, weight: .bold, color: .flexokiText)
    }
    
    /// Secondary heading style
    static func heading2() -> some ViewModifier {
        TextStyle(size: 20, weight: .semibold, color: .flexokiText)
    }
    
    /// Standard body text style
    static func bodyText() -> some ViewModifier {
        TextStyle(size: 16, weight: .regular, color: .flexokiText)
    }
    
    /// Caption text style
    static func captionText() -> some ViewModifier {
        TextStyle(size: 14, weight: .regular, color: .flexokiText2)
    }
    
    // MARK: - Button Styles
    
    /// Primary button style
    static func primaryButton() -> some ViewModifier {
        ButtonStyle(background: .flexokiAccentBlue, foreground: .flexokiPaper)
    }
    
    /// Secondary button style
    static func secondaryButton() -> some ViewModifier {
        OutlinedButtonStyle(borderColor: .flexokiAccentBlue, foreground: .flexokiAccentBlue)
    }
    
    /// Destructive button style
    static func destructiveButton() -> some ViewModifier {
        ButtonStyle(background: .flexokiRed, foreground: .flexokiPaper)
    }
    
    /// Destructive secondary button style
    static func destructiveSecondaryButton() -> some ViewModifier {
        OutlinedButtonStyle(borderColor: .flexokiRed, foreground: .flexokiRed)
    }
    
    // MARK: - Input Styles
    
    /// Standard text input style
    static func textInput() -> some ViewModifier {
        TextInputStyle()
    }
}

// MARK: - Implementation of Modifiers

/// Text style modifier
struct TextStyle: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight))
            .foregroundColor(color)
            .dynamicTypeSize(Accessibility.standardDynamicTypeRange)
    }
}

/// Button style modifier
struct ButtonStyle: ViewModifier {
    let background: Color
    let foreground: Color
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(foreground)
            .frame(minHeight: Accessibility.minimumTapTargetSize)
            .padding(.horizontal, 16)
            .background(background)
            .cornerRadius(Accessibility.standardCornerRadius)
            .dynamicTypeSize(Accessibility.standardDynamicTypeRange)
    }
}

/// Outlined button style modifier
struct OutlinedButtonStyle: ViewModifier {
    let borderColor: Color
    let foreground: Color
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(foreground)
            .frame(minHeight: Accessibility.minimumTapTargetSize)
            .padding(.horizontal, 16)
            .background(Color.flexokiBackground)
            .cornerRadius(Accessibility.standardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Accessibility.standardCornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .dynamicTypeSize(Accessibility.standardDynamicTypeRange)
    }
}

/// Text input style modifier
struct TextInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(Color.flexokiBackground)
            .cornerRadius(Accessibility.standardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Accessibility.standardCornerRadius)
                    .stroke(Color.flexokiUI, lineWidth: 1)
            )
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .foregroundColor(Color.flexokiText)
    }
}

// MARK: - View Extensions

extension View {
    // Text styles
    func flexokiHeading1() -> some View {
        self.modifier(FlexokiTheme.heading1())
    }
    
    func flexokiHeading2() -> some View {
        self.modifier(FlexokiTheme.heading2())
    }
    
    func flexokiBodyText() -> some View {
        self.modifier(FlexokiTheme.bodyText())
    }
    
    func flexokiCaptionText() -> some View {
        self.modifier(FlexokiTheme.captionText())
    }
    
    // Button styles
    func flexokiPrimaryButton() -> some View {
        self.modifier(FlexokiTheme.primaryButton())
    }
    
    func flexokiSecondaryButton() -> some View {
        self.modifier(FlexokiTheme.secondaryButton())
    }
    
    func flexokiDestructiveButton() -> some View {
        self.modifier(FlexokiTheme.destructiveButton())
    }
    
    func flexokiDestructiveSecondaryButton() -> some View {
        self.modifier(FlexokiTheme.destructiveSecondaryButton())
    }
    
    // Input styles
    func flexokiTextInput() -> some View {
        self.modifier(FlexokiTheme.textInput())
    }
}
