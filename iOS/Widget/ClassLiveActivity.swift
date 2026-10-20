import ActivityKit
import WidgetKit
import SwiftUI
import ChronologyCore

struct ClassLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassActivityAttributes.self) { context in
            LockScreenClassView(state: context.state, phase: context.state.phase(isStale: context.isStale))
                .activityBackgroundTint(context.state.color.color.opacity(0.25))
                .activitySystemActionForegroundColor(context.state.color.color)
        } dynamicIsland: { context in
            let state = context.state
            let phase = state.phase(isStale: context.isStale)
            let color = state.color.color
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(phase.caption)
                    } icon: {
                        Image(systemName: phase.symbol)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ClassTimer(state: state, phase: phase)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(color)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.event.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(details(state))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if phase == .inProgress {
                            ProgressView(timerInterval: state.event.startTime...state.event.endTime, countsDown: false) {
                                EmptyView()
                            } currentValueLabel: {
                                EmptyView()
                            }
                            .tint(color)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: phase.symbol)
                    .foregroundStyle(color)
            } compactTrailing: {
                ClassTimer(state: state, phase: phase)
                    .foregroundStyle(color)
                    .frame(maxWidth: 52)
            } minimal: {
                if phase == .inProgress {
                    ProgressView(timerInterval: state.event.startTime...state.event.endTime, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        Image(systemName: "graduationcap.fill").font(.system(size: 9))
                    }
                    .progressViewStyle(.circular)
                    .tint(color)
                } else {
                    Image(systemName: phase.symbol).foregroundStyle(color)
                }
            }
            .keylineTint(color)
        }
    }

    private func details(_ state: ClassActivityAttributes.ContentState) -> String {
        let range = EventStyle.timeRange(state.event, use24Hour: state.use24Hour)
        return state.event.location.isEmpty ? range : "\(range) · \(state.event.location)"
    }
}

// MARK: - Lock Screen

private struct LockScreenClassView: View {
    let state: ClassActivityAttributes.ContentState
    let phase: ClassPhase

    var body: some View {
        let color = state.color.color
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Capsule().fill(color).frame(width: 5)
                VStack(alignment: .leading, spacing: 3) {
                    Text(phase.caption.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(color)
                    Text(state.event.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                ClassTimer(state: state, phase: phase)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110, alignment: .trailing)
            }
            .fixedSize(horizontal: false, vertical: true)

            if phase == .inProgress {
                ProgressView(timerInterval: state.event.startTime...state.event.endTime, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(color)
            }
        }
        .padding(16)
    }

    private var details: String {
        let range = EventStyle.timeRange(state.event, use24Hour: state.use24Hour)
        return state.event.location.isEmpty ? range : "\(range) · \(state.event.location)"
    }
}

// MARK: - Pieces

/// Ticks on its own: counts down to the start, then to the end of class.
private struct ClassTimer: View {
    let state: ClassActivityAttributes.ContentState
    let phase: ClassPhase

    var body: some View {
        switch phase {
        case .upcoming:
            Text(timerInterval: state.updatedAt...max(state.updatedAt, state.event.startTime), countsDown: true)
                .monospacedDigit()
        case .inProgress:
            Text(timerInterval: state.event.startTime...state.event.endTime, countsDown: true)
                .monospacedDigit()
        case .finished:
            Text("Done")
        }
    }
}

extension ClassPhase {
    var caption: String {
        switch self {
        case .upcoming: "Starts in"
        case .inProgress: "Ends in"
        case .finished: "Finished"
        }
    }

    var symbol: String {
        switch self {
        case .upcoming: "calendar.badge.clock"
        case .inProgress: "graduationcap.fill"
        case .finished: "checkmark.circle.fill"
        }
    }
}
