import Foundation

/// Product copy shared by the Mac and iOS apps.
public enum AboutText {
    public static let appName = "Chronology"
    public static let tagline = "Your schedule, on time"
    /// Says what the app is for, where the tagline alone wouldn't (onboarding, About).
    public static let purpose = "A schedule viewer for TimeEdit calendars"
    public static let privacy = "Chronology collects no data. Your calendar link and notes stay on your devices."
    public static let credit = "Built with ❤️ by SyntaxError and Claude"
    /// The project's source code (the About footer shows no account name).
    public static let sourceCode = URL(string: "https://github.com/js-surya/Chronology")!

    /// Third-party notices. Chronology has no dependencies, so these are trademark notes.
    public static let acknowledgements = [
        "TimeEdit is a trademark of TimeEdit AB. Chronology is not affiliated with TimeEdit.",
        "Icons are SF Symbols by Apple.",
        "The app icon was made for Chronology in Icon Composer."
    ]

    /// What people see: "1.1.0".
    public static var displayVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// With the build number, for bug reports: "1.1.0 (12)".
    public static var versionWithBuild: String {
        "\(displayVersion) (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))"
    }
}
