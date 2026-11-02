import SwiftUI

/// Design System Color Tokens for Orchard
public enum OrchardColors {
    // Hex definitions
    public static let appleRedHex = "#E0483E"
    public static let leafGreenHex = "#5FB760"
    public static let creamHex = "#FFF8EF"
    public static let inkHex = "#2B2320"
    public static let darkBgHex = "#16130F"

    // SwiftUI Colors
    public static let appleRed = Color(hex: appleRedHex)
    public static let leafGreen = Color(hex: leafGreenHex)
    public static let cream = Color(hex: creamHex)
    public static let ink = Color(hex: inkHex)
    public static let darkBackground = Color(hex: darkBgHex)

    // Dynamic adaptive background
    public static let background = Color(uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0x16/255.0, green: 0x13/255.0, blue: 0x0F/255.0, alpha: 1.0)
            : UIColor(red: 0xFF/255.0, green: 0xF8/255.0, blue: 0xEF/255.0, alpha: 1.0)
    })

    // Dynamic adaptive text / ink
    public static let text = Color(uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0xFF/255.0, green: 0xF8/255.0, blue: 0xEF/255.0, alpha: 1.0)
            : UIColor(red: 0x2B/255.0, green: 0x23/255.0, blue: 0x20/255.0, alpha: 1.0)
    })
}

extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
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
