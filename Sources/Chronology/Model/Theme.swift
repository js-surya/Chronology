import SwiftUI
import AppKit
import ChronologyCore

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

// MARK: - Layout tokens

enum ChronoTokens {
    static let hourHeight: CGFloat  = 58
    static let timeColW: CGFloat    = 64
    static let cardRadius: CGFloat  = 10
    static let panelRadius: CGFloat = 16
}

// MARK: - Event presentation

extension AppViewModel {
    /// Single source for an event's color: user override first, then the stable course hue.
    func eventColor(for event: Event) -> Color {
        getCustomColor(for: event.title) ?? event.color(from: event.title)
    }

    private static let clock24: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let clock12: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f
    }()

    /// Clock time honoring the 12/24-hour setting (locale hour cycles would override it).
    func timeString(_ date: Date) -> String {
        (use24HourFormat ? Self.clock24 : Self.clock12).string(from: date)
    }

    func timeRange(_ event: Event) -> String {
        "\(timeString(event.startTime)) – \(timeString(event.endTime))"
    }
}
