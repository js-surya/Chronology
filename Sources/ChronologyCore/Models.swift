import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Models

public struct Event: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let location: String
    public let startTime: Date
    public let endTime: Date
    public let description: String?
    public var isAllDay: Bool = false

    public init(id: String? = nil, title: String, location: String, startTime: Date, endTime: Date, description: String?, isAllDay: Bool = false) {
        self.id = id ?? "\(title)@\(Int(startTime.timeIntervalSince1970))"
        self.title = title
        self.location = location
        self.startTime = startTime
        self.endTime = endTime
        self.description = description
        self.isAllDay = isAllDay
    }

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public func color(from seed: String) -> Color {
        // hueForCourse is deterministic; String.hashValue is reseeded every launch
        Color(hue: hueForCourse(seed) / 360.0, saturation: 0.7, brightness: 0.9)
    }
}

/// Stable hue (0..<360) from a course title (djb2 over UTF-8).
public func hueForCourse(_ title: String) -> Double {
    var hash: UInt64 = 5381
    for byte in title.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
    return Double(hash % 360)
}

public struct ScheduleProfile: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var icalUrl: String
    public var description: String
    public var emoji: String
    public var emojiColor: CodableColor?

    public init(id: UUID = UUID(), name: String, icalUrl: String, description: String = "", emoji: String = "calendar", emojiColor: CodableColor? = nil) {
        self.id = id
        self.name = name
        self.icalUrl = icalUrl
        self.description = description
        self.emoji = emoji
        self.emojiColor = emojiColor
    }

    // Custom decoding to handle missing emoji/emojiColor in old profiles
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icalUrl = try container.decode(String.self, forKey: .icalUrl)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "calendar"
        emojiColor = try container.decodeIfPresent(CodableColor.self, forKey: .emojiColor)
    }
}

// MARK: - User Customizations

public struct CourseCustomization: Identifiable, Codable, Sendable {
    public let id: UUID
    public let courseName: String
    public var customColor: CodableColor?

    public init(id: UUID = UUID(), courseName: String, customColor: CodableColor? = nil) {
        self.id = id
        self.courseName = courseName
        self.customColor = customColor
    }
}

public struct EventNote: Identifiable, Codable, Sendable {
    public let id: UUID
    public let eventTitle: String
    public let eventDate: Date
    public var note: String
    public var createdAt: Date
    public var modifiedAt: Date

    public init(id: UUID = UUID(), eventTitle: String, eventDate: Date, note: String) {
        self.id = id
        self.eventTitle = eventTitle
        self.eventDate = eventDate
        self.note = note
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

public struct ImportantEvent: Identifiable, Codable, Sendable {
    public let id: UUID
    public let eventTitle: String
    public let eventDate: Date
    public var reminderMinutes: Int

    public init(id: UUID = UUID(), eventTitle: String, eventDate: Date, reminderMinutes: Int) {
        self.id = id
        self.eventTitle = eventTitle
        self.eventDate = eventDate
        self.reminderMinutes = reminderMinutes
    }

    /// Same occurrence: matching title and start within a minute.
    public func matches(_ event: Event) -> Bool {
        eventTitle == event.title && abs(eventDate.timeIntervalSince(event.startTime)) < 60
    }
}

// Helper for encoding/decoding Color
public struct CodableColor: Codable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        #if canImport(AppKit)
        // Convert to device RGB to ensure consistent component extraction
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(UIKit)
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        self.init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }

    public var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
