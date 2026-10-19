import Foundation

/// Storage shared between the app and its widgets.
enum AppGroup {
    static let id = "group.com.codingpasanga.chronology"

    /// Falls back to standard defaults when the group container is unavailable (e.g. unsigned builds).
    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

enum WidgetKind {
    static let nextUp = "NextUp"
}
