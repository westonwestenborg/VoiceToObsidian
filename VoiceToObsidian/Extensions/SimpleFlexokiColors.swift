import SwiftUI

/// Flexoki color palette implementation
/// Based on https://stephango.com/flexoki
extension Color {
    // Base colors
    static let flexokiPaper = Color(hex: "FFFCF0")
    static let flexokiBlack = Color(hex: "100F0F")
    
    // Background colors
    static let flexokiBg = Color(hex: "FFFCF0")
    static let flexokiBg2 = Color(hex: "F2F0E5")
    static let flexokiBgDark = Color(hex: "1C1B1A")
    static let flexokiBg2Dark = Color(hex: "282726")
    
    // UI colors
    static let flexokiUi = Color(hex: "E6E4D9")
    static let flexokiUi2 = Color(hex: "DAD8CE")
    static let flexokiUi3 = Color(hex: "CECDC3")
    static let flexokiUiDark = Color(hex: "343331")
    static let flexokiUi2Dark = Color(hex: "403E3C")
    static let flexokiUi3Dark = Color(hex: "575653")
    
    // Text colors
    static let flexokiTx = Color(hex: "100F0F")
    static let flexokiTx2 = Color(hex: "6F6E69")
    static let flexokiTx3 = Color(hex: "878580")
    static let flexokiTxDark = Color(hex: "FFFCF0")
    static let flexokiTx2Dark = Color(hex: "B7B5AC")
    static let flexokiTx3Dark = Color(hex: "878580")
    
    // Accent colors - 600 (for light mode)
    static let flexokiRed = Color(hex: "AF3029")
    static let flexokiOrange = Color(hex: "BC5215")
    static let flexokiYellow = Color(hex: "AD8301")
    static let flexokiGreen = Color(hex: "66800B")
    static let flexokiCyan = Color(hex: "24837B")
    static let flexokiBlue = Color(hex: "205EA6")
    static let flexokiPurple = Color(hex: "5E409D")
    static let flexokiMagenta = Color(hex: "A02F6F")
    
    // Accent colors - 400 (for dark mode)
    static let flexokiRedDark = Color(hex: "D14D41")
    static let flexokiOrangeDark = Color(hex: "DA702C")
    static let flexokiYellowDark = Color(hex: "D0A215")
    static let flexokiGreenDark = Color(hex: "879A39")
    static let flexokiCyanDark = Color(hex: "3AA99F")
    static let flexokiBlueDark = Color(hex: "4385BE")
    static let flexokiPurpleDark = Color(hex: "8B7EC8")
    static let flexokiMagentaDark = Color(hex: "CE5D97")
    
    // Helper initializer for hex colors
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Extension to provide dynamic colors based on color scheme
extension Color {
    static var flexokiBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color.flexokiBgDark) : UIColor(Color.flexokiBg)
        })
    }
    
    static var flexokiBackground2: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color.flexokiBg2Dark) : UIColor(Color.flexokiBg2)
        })
    }
    
    static var flexokiUI: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color.flexokiUiDark) : UIColor(Color.flexokiUi)
        })
    }
    
    static var flexokiUI2: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color.flexokiUi2Dark) : UIColor(Color.flexokiUi2)
        })
    }
    
    static var flexokiText: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color.flexokiTxDark) : UIColor(Color.flexokiTx)
        })
    }
    
    static var flexokiText2: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color.flexokiTx2Dark) : UIColor(Color.flexokiTx2)
        })
    }
    
    static var flexokiAccentBlue: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color.flexokiBlueDark) : UIColor(Color.flexokiBlue)
        })
    }
    
    static var flexokiAccentRed: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color.flexokiRedDark) : UIColor(Color.flexokiRed)
        })
    }
}
