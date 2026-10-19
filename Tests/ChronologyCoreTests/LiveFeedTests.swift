import XCTest
@testable import ChronologyCore

/// Opt-in check against a real feed: `CHRONOLOGY_LIVE_URL=https://... swift test --filter LiveFeedTests`
final class LiveFeedTests: XCTestCase {
    func testLiveFeedParsesCleanly() async throws {
        guard let urlString = ProcessInfo.processInfo.environment["CHRONOLOGY_LIVE_URL"], !urlString.isEmpty else {
            throw XCTSkip("Set CHRONOLOGY_LIVE_URL to run")
        }

        let url = try ScheduleService.normalizedURL(urlString)
        let (data, _) = try await URLSession.shared.data(from: url)
        let raw = String(decoding: data, as: UTF8.self)
        let declared = raw.components(separatedBy: "BEGIN:VEVENT").count - 1

        let events = try await ScheduleService.shared.fetchSchedule(from: urlString, maxAge: 0)

        XCTAssertGreaterThan(declared, 0, "Feed has no VEVENTs")
        XCTAssertEqual(events.count, declared, "Every VEVENT should become an Event")
        XCTAssertEqual(Set(events.map(\.id)).count, events.count, "Event ids must be unique")
        for event in events {
            XCTAssertFalse(event.title.isEmpty, "Empty title: \(event.id)")
            XCTAssertGreaterThanOrEqual(event.endTime, event.startTime, "End before start: \(event.title)")
            for text in [event.title, event.location, event.description ?? ""] {
                XCTAssertFalse(text.contains("\\,") || text.contains("\\;") || text.contains("\\n"), "Escapes left in: \(text)")
            }
        }

        // Second call must come from cache (same ids, no new download needed)
        let cached = try await ScheduleService.shared.fetchSchedule(from: urlString)
        XCTAssertEqual(cached.map(\.id), events.map(\.id))

        let sample = events.sorted { $0.startTime < $1.startTime }.first { $0.startTime > Date() }
        print("LIVE: \(events.count) events, all-day \(events.filter(\.isAllDay).count), next: \(sample.map { "\($0.title) @ \($0.startTime)" } ?? "none")")
    }
}
