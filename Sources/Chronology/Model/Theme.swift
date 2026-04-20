import SwiftUI
import AppKit

enum AppTheme: String, CaseIterable {
    case light
    case dark       // glass / translucent
    case darkSolid  // opaque #1D1D22
    case amoled     // pure black

    var isSolid: Bool { self == .darkSolid || self == .amoled }
    var isDark: Bool { self != .light }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light:                        return .light
        case .dark, .darkSolid, .amoled:    return .dark
        }
    }

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

extension View {
    @ViewBuilder
    func glassSurface(_ theme: AppTheme) -> some View {
        switch theme {
        case .light, .dark:
            self.background(.regularMaterial)
        case .darkSolid:
            self.background(Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)))
        case .amoled:
            self.background(Color.black)
        }
    }
}
