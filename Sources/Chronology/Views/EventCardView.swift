import SwiftUI
import ChronologyCore

// MARK: - Event card (week + day grids)

struct EventCardView: View {
    let event: Event
    let theme: AppTheme
    var compact: Bool = false
    /// Split overlap columns: one truncated line instead of breaking words mid-letter
    var narrow: Bool = false
    var onTap: (() -> Void)? = nil

    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingDetail = false
    @State private var isHovering = false

    private var color: Color { appViewModel.eventColor(for: event) }
    private var isDark: Bool { theme != .light }
    private var isImportant: Bool { appViewModel.isEventImportant(event) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: ChronoTokens.cardRadius, style: .continuous) }

    var body: some View {
        Button {
            if let onTap { onTap() } else { showingDetail = true }
        } label: {
            HStack(alignment: .top, spacing: 0) {
                // Color bar, inset to follow the card's corner
                Capsule()
                    .fill(color)
                    .frame(width: 3)
                    .padding(.vertical, 4)
                    .padding(.leading, 4)
                contentStack
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                // Opaque base so grid lines don't show through the tint
                shape.fill(baseFill)
                shape.fill(color.opacity(fillOpacity))
            }
            .overlay(shape.strokeBorder(color.opacity(isDark ? 0.45 : 0.35), lineWidth: 0.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { isHovering = h } }
        .popover(isPresented: $showingDetail, arrowEdge: .trailing) {
            EventDetailPopover(event: event)
                .environmentObject(appViewModel)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    private var baseFill: Color {
        switch theme {
        case .amoled:    return .black
        case .darkSolid: return Color(red: 0.11, green: 0.11, blue: 0.13)
        default:         return Color(nsColor: .windowBackgroundColor)
        }
    }

    private var fillOpacity: Double {
        let base = isDark ? 0.30 : 0.18
        return isHovering ? base + 0.12 : base
    }

    private var contentStack: some View {
        HStack(alignment: .top, spacing: 2) {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: compact ? 11.5 : 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(narrow ? 1 : (compact ? 2 : 3))
                if event.duration > 30 * 60 || !compact {
                    Text(subtitle)
                        .font(.system(size: compact ? 10 : 11.5))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if (isHovering || isImportant) && !narrow {
                Button {
                    appViewModel.toggleImportant(event)
                } label: {
                    Image(systemName: isImportant ? "star.fill" : "star")
                        .font(.system(size: compact ? 9 : 11))
                        .foregroundStyle(isImportant ? AnyShapeStyle(.yellow) : AnyShapeStyle(.secondary))
                }
                .buttonStyle(.plain)
                .help(isImportant ? "Remove from Important" : "Mark as Important")
            }
        }
        .padding(.leading, compact ? 6 : 10)
        .padding(.vertical, compact ? 5 : 8)
        .padding(.trailing, 6)
    }

    private var subtitle: String {
        let time = appViewModel.timeRange(event)
        return event.location.isEmpty ? time : "\(time) · \(event.location)"
    }

    private var accessibilityText: String {
        var parts = [event.title, appViewModel.timeRange(event)]
        if !event.location.isEmpty { parts.append(event.location) }
        if isImportant { parts.append("Important") }
        return parts.joined(separator: ", ")
    }
}
