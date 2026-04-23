import SwiftUI
import AppKit

enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark       // glass / translucent
    case darkSolid  // opaque #1D1D22
    case amoled     // pure black

    var id: String { rawValue }

    // Translucency
    var isTranslucent: Bool { self == .light || self == .dark }
    var isSolid: Bool { !isTranslucent }
    var isDark: Bool { self != .light }

    var colorScheme: ColorScheme? {
        self == .light ? .light : .dark
    }
    var preferredColorScheme: ColorScheme? { colorScheme }

    var displayName: String {
        switch self {
        case .light:     return "Light"
        case .dark:      return "Glass"
        case .darkSolid: return "Solid"
        case .amoled:    return "AMOLED"
        }
    }

    var systemImage: String {
        switch self {
        case .light:     return "sun.max.fill"
        case .dark:      return "sparkles"
        case .darkSolid: return "moon.fill"
        case .amoled:    return "moon.stars.fill"
        }
    }
}

// MARK: - Theme resolution

func resolveTheme(mode: String, systemDark: Bool, preferredDark: String) -> AppTheme {
    switch mode {
    case "light":     return .light
    case "dark":      return .dark
    case "darkSolid": return .darkSolid
    case "amoled":    return .amoled
    default:
        guard systemDark else { return .light }
        switch preferredDark {
        case "amoled":    return .amoled
        case "darkSolid": return .darkSolid
        default:          return .dark
        }
    }
}

// MARK: - Layout tokens

enum ChronoTokens {
    static let hourHeight: CGFloat  = 58
    static let timeColW: CGFloat    = 64
    static let cardRadius: CGFloat  = 10
    static let panelRadius: CGFloat = 14
    static let windowRadius: CGFloat = 20
}

// MARK: - Surface helpers

extension View {
    /// Primary window/panel background.
    @ViewBuilder
    func glassSurface(_ theme: AppTheme, corner: CGFloat = 0) -> some View {
        switch theme {
        case .light, .dark:
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: corner))
        case .darkSolid:
            self.background(Color(red: 0.113, green: 0.113, blue: 0.133),
                            in: RoundedRectangle(cornerRadius: corner))
        case .amoled:
            self.background(Color.black, in: RoundedRectangle(cornerRadius: corner))
        }
    }

    /// Floating panel (Next Up card, menu bar dropdown, settings sheet).
    @ViewBuilder
    func glassPanel(_ theme: AppTheme, corner: CGFloat = 14) -> some View {
        switch theme {
        case .light:
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: corner))
                .overlay(RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(.white.opacity(0.55), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        case .dark:
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: corner))
                .overlay(RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
        case .darkSolid:
            self.background(Color(red: 0.14, green: 0.14, blue: 0.16),
                            in: RoundedRectangle(cornerRadius: corner))
                .overlay(RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
        case .amoled:
            self.background(Color.black, in: RoundedRectangle(cornerRadius: corner))
                .overlay(RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.7), radius: 18, y: 8)
        }
    }
}

// MARK: - Event color helpers (HSB approximation of oklch palette)

extension Color {
    static func eventTint(hue: Double, isDark: Bool) -> Color {
        Color(hue: hue / 360,
              saturation: isDark ? 0.55 : 0.45,
              brightness: isDark ? 0.55 : 0.85,
              opacity: isDark ? 0.55 : 0.45)
    }
    static func eventBar(hue: Double) -> Color {
        Color(hue: hue / 360, saturation: 0.75, brightness: 0.62)
    }
    static func eventHeader(hue: Double) -> Color {
        Color(hue: hue / 360, saturation: 0.75, brightness: 0.45)
    }
}

// Stable hue from course title.
func hueForCourse(_ title: String) -> Double {
    var hash: UInt64 = 5381
    for byte in title.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
    return Double(hash % 360)
}
