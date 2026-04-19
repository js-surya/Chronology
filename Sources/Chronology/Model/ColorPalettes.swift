import SwiftUI

// Curated color palettes inspired by ColorHunt
struct ColorPalettes {
    static let palettes: [[String]] = [
        // Warm Sunset
        ["#FF6B6B", "#FFD93D", "#6BCB77", "#4D96FF"],
        // Ocean Breeze
        ["#0B2447", "#19376D", "#576CBC", "#A5D7E8"],
        // Berry Smoothie
        ["#FF90BC", "#FFC0D9", "#F9F9E0", "#8ACDD7"],
        // Forest Earth
        ["#2C5F2D", "#97BC62", "#E8D5C4", "#F4A460"],
        // Neon Nights
        ["#FF006E", "#8338EC", "#3A86FF", "#06FFA5"],
        // Pastel Dream
        ["#FFB4B4", "#FFDBA4", "#C3F4C4", "#A8DDFD"],
        // Professional
        ["#364F6B", "#3FC1C9", "#F5F5F5", "#FC5185"],
        // Vintage
        ["#B85042", "#E7E8D1", "#A7BEAE", "#D6CDA4"],
        // Modern Dark
        ["#212121", "#323232", "#0D7377", "#14FFEC"],
        // Candy Pop
        ["#FE346E", "#FFBD39", "#00DFA2", "#F706CF"],
    ]
}

extension Color {
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
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
