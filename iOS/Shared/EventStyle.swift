import SwiftUI
import ChronologyCore

/// Presentation rules shared by the app and the widgets.
enum EventStyle {
    /// User override first, then the stable course hue (same rule as the Mac app).
    static func color(for event: Event, customColors: [String: CodableColor]) -> Color {
        customColors[event.title]?.color ?? event.color(from: event.title)
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
    static func time(_ date: Date, use24Hour: Bool) -> String {
        (use24Hour ? clock24 : clock12).string(from: date)
    }

    static func timeRange(_ event: Event, use24Hour: Bool) -> String {
        "\(time(event.startTime, use24Hour: use24Hour)) – \(time(event.endTime, use24Hour: use24Hour))"
    }
}
