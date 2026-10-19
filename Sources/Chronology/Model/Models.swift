import Foundation
import SwiftUI

// MARK: - Models

struct Event: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let location: String
    let startTime: Date
    let endTime: Date
    let description: String?
    var isAllDay: Bool = false

    init(id: String? = nil, title: String, location: String, startTime: Date, endTime: Date, description: String?, isAllDay: Bool = false) {
        self.id = id ?? "\(title)@\(Int(startTime.timeIntervalSince1970))"
        self.title = title
        self.location = location
        self.startTime = startTime
        self.endTime = endTime
        self.description = description
        self.isAllDay = isAllDay
    }

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    func color(from seed: String) -> Color {
        // hueForCourse is deterministic; String.hashValue is reseeded every launch
        Color(hue: hueForCourse(seed) / 360.0, saturation: 0.7, brightness: 0.9)
    }
}

struct ScheduleProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icalUrl: String
    var description: String
    var emoji: String
    var emojiColor: CodableColor?
    
    init(id: UUID = UUID(), name: String, icalUrl: String, description: String = "", emoji: String = "calendar", emojiColor: CodableColor? = nil) {
        self.id = id
        self.name = name
        self.icalUrl = icalUrl
        self.description = description
        self.emoji = emoji
        self.emojiColor = emojiColor
    }
    
    // Custom decoding to handle missing emoji/emojiColor in old profiles
    init(from decoder: Decoder) throws {
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

struct CourseCustomization: Identifiable, Codable {
    let id: UUID
    let courseName: String
    var customColor: CodableColor?
    
    init(id: UUID = UUID(), courseName: String, customColor: CodableColor? = nil) {
        self.id = id
        self.courseName = courseName
        self.customColor = customColor
    }
}

struct EventNote: Identifiable, Codable {
    let id: UUID
    let eventTitle: String
    let eventDate: Date
    var note: String
    var createdAt: Date
    var modifiedAt: Date
    
    init(id: UUID = UUID(), eventTitle: String, eventDate: Date, note: String) {
        self.id = id
        self.eventTitle = eventTitle
        self.eventDate = eventDate
        self.note = note
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

struct ImportantEvent: Identifiable, Codable {
    let id: UUID
    let eventTitle: String
    let eventDate: Date
    var reminderMinutes: Int
    
    init(id: UUID = UUID(), eventTitle: String, eventDate: Date, reminderMinutes: Int) {
        self.id = id
        self.eventTitle = eventTitle
        self.eventDate = eventDate
        self.reminderMinutes = reminderMinutes
    }
}

// Helper for encoding/decoding Color
struct CodableColor: Codable, Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(color: Color) {
        #if os(macOS)
        // Convert to device RGB to ensure consistent component extraction
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.alpha = Double(nsColor.alphaComponent)
        #endif
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
