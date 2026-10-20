import ActivityKit
import Foundation
import ChronologyCore

/// Live Activity for the current or next class (Dynamic Island + Lock Screen).
struct ClassActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var event: Event
        var color: CodableColor
        var use24Hour: Bool
        /// Whether the class had started when the app last updated the activity.
        var startedAtUpdate: Bool
        var updatedAt: Date
    }

    var profileName: String
}

enum ClassPhase {
    case upcoming, inProgress, finished
}

extension ClassActivityAttributes.ContentState {
    /// The app can't wake at every boundary, so the activity's stale date carries it forward:
    /// stale while upcoming means class has started; stale while in progress means it ended.
    func phase(isStale: Bool) -> ClassPhase {
        switch (startedAtUpdate, isStale) {
        case (false, false): .upcoming
        case (false, true), (true, false): .inProgress
        case (true, true): .finished
        }
    }

    /// The moment the system should flip to the next phase.
    var staleDate: Date { startedAtUpdate ? event.endTime : event.startTime }
}
