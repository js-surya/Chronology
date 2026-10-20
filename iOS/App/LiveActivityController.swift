import ActivityKit
import Foundation
import ChronologyCore

/// Keeps one Live Activity in step with the current or next class.
@MainActor
enum LiveActivityController {
    /// Show the activity once the next class is this close.
    static let leadTime: TimeInterval = 60 * 60

    static var systemAllowsActivities: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// The class the activity should show right now: the one in progress, else the next one within `leadTime`.
    static func target(in events: [Event], now: Date) -> Event? {
        Countdown.liveActivityTarget(in: events, now: now, leadTime: leadTime)
    }

    /// Starts, updates or ends the activity. Safe to call often (refresh, foreground, settings change).
    static func sync(enabled: Bool, events: [Event], profileName: String, color: (Event) -> CodableColor, use24Hour: Bool, now: Date = Date()) async {
        let running = Activity<ClassActivityAttributes>.activities
        guard enabled, systemAllowsActivities, let event = target(in: events, now: now) else {
            await endAll(running)
            return
        }

        let state = ClassActivityAttributes.ContentState(
            event: event,
            color: color(event),
            use24Hour: use24Hour,
            startedAtUpdate: event.startTime <= now,
            updatedAt: now
        )
        let content = ActivityContent(state: state, staleDate: state.staleDate, relevanceScore: 100)

        if let activity = running.first {
            if activity.content.state != state {
                await activity.update(content)
            }
            // Only ever keep one
            await endAll(Array(running.dropFirst()))
        } else {
            do {
                _ = try Activity.request(attributes: ClassActivityAttributes(profileName: profileName), content: content, pushType: nil)
            } catch {
                // Starting is only allowed while the app is in the foreground; the next foreground sync retries
            }
        }
    }

    static func endAll() async {
        await endAll(Activity<ClassActivityAttributes>.activities)
    }

    private static func endAll(_ activities: [Activity<ClassActivityAttributes>]) async {
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
