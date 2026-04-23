import SwiftUI

// MARK: - Glass event card (week + day grids)

struct EventCardView: View {
    let event: Event
    let theme: AppTheme
    var compact: Bool = false
    var onTap: (() -> Void)? = nil

    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingDetail = false
    @State private var isHovering = false

    private var hue: Double { hueForCourse(event.title) }
    private var isDark: Bool { theme != .light }
    private var duration: TimeInterval { event.endTime.timeIntervalSince(event.startTime) }
    private var isImportant: Bool { appViewModel.isEventImportant(event) }

    var body: some View {
        Button {
            if let onTap { onTap() } else { showingDetail = true }
        } label: {
            ZStack(alignment: .topLeading) {
                cardBackground
                accentBar
                contentStack
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }
        .popover(isPresented: $showingDetail) {
            EventDetailPopover(event: event)
                .environmentObject(appViewModel)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: ChronoTokens.cardRadius)
            .fill(Color.eventTint(hue: hue, isDark: isDark))
            .background(
                Group {
                    if theme.isTranslucent {
                        RoundedRectangle(cornerRadius: ChronoTokens.cardRadius)
                            .fill(.ultraThinMaterial)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChronoTokens.cardRadius)
                    .strokeBorder(
                        theme.isTranslucent ? Color.white.opacity(0.55) : Color.white.opacity(0.10),
                        lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(isDark ? 0.35 : 0.08), radius: 4, y: 2)
    }

    private var accentBar: some View {
        Capsule()
            .fill(Color.eventBar(hue: hue))
            .frame(width: 2.5)
            .padding(.vertical, 5)
            .padding(.leading, 3)
            .shadow(color: Color.eventBar(hue: hue).opacity(0.7), radius: 3)
    }

    private var contentStack: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: compact ? 11.5 : 13.5, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(compact ? 2 : 3)
                if duration > 30 * 60 || !compact {
                    Text("\(timeString(event.startTime)) – \(timeString(event.endTime)) · \(event.location)")
                        .font(.system(size: compact ? 10 : 11.5))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if isHovering || isImportant {
                Button {
                    appViewModel.toggleImportant(event)
                } label: {
                    Image(systemName: isImportant ? "star.fill" : "star")
                        .font(.system(size: compact ? 9 : 11))
                        .foregroundStyle(isImportant
                            ? Color(red: 1.0, green: 0.69, blue: 0.12)
                            : Color.secondary)
                        .shadow(color: isImportant
                            ? Color(red: 1.0, green: 0.69, blue: 0.12).opacity(0.6) : .clear,
                                radius: 4)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }
        }
        .padding(.leading, compact ? 13 : 18)
        .padding(.vertical, compact ? 6 : 10)
        .padding(.trailing, 8)
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
}

// MARK: - Day header date cell

struct DayHeaderCell: View {
    let date: Date
    let weekday: String
    let isToday: Bool
    let accent: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(weekday.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(isToday ? accent : Color.secondary)
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 15, weight: isToday ? .semibold : .medium))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isToday ? AnyShapeStyle(accent) : AnyShapeStyle(Color.clear))
                        .shadow(color: isToday ? accent.opacity(0.4) : .clear, radius: 6, y: 2)
                )
        }
    }
}
