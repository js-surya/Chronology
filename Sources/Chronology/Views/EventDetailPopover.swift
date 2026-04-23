import SwiftUI
import UserNotifications

struct EventDetailPopover: View {
    let event: Event
    @EnvironmentObject var appViewModel: AppViewModel

    @State private var noteText = ""
    @State private var isEditingNote = false
    @State private var selectedColor: Color

    private var eventColor: Color {
        appViewModel.getCustomColor(for: event.title) ?? event.color(from: event.title)
    }

    private var isImportant: Bool { appViewModel.isEventImportant(event) }

    init(event: Event) {
        self.event = event
        _selectedColor = State(initialValue: event.color(from: event.title))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Accent band header
            accentBand

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Detail rows
                    detailRows

                    softDivider

                    // Color palette
                    colorSection

                    softDivider

                    // Notes
                    notesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }

            Divider()

            // Footer buttons
            HStack(spacing: 10) {
                Button(isImportant ? "★ Important" : "Mark important") {
                    appViewModel.toggleImportant(event)
                }
                .buttonStyle(DetailCapsuleStyle(accent: eventColor, filled: isImportant))

                Button {
                    appViewModel.toggleImportant(event)
                    if !appViewModel.notificationsEnabled {
                        appViewModel.notificationsEnabled = true
                    }
                } label: {
                    Label(isImportant ? "Reminder set" : "Remind me", systemImage: isImportant ? "bell.fill" : "bell")
                }
                .buttonStyle(DetailCapsuleStyle(accent: eventColor, filled: isImportant))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 360, height: 560)
        .onAppear {
            if let note = appViewModel.getNote(for: event) { noteText = note.note }
            if let custom = appViewModel.getCustomColor(for: event.title) { selectedColor = custom }
        }
    }

    // MARK: - Accent band

    private var accentBand: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [eventColor.opacity(0.7), eventColor.opacity(0.2), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 120)

            // Blur fade at bottom edge
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 32)
                    .mask(
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    )
            }
            .frame(height: 120)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(eventColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: eventColor.opacity(0.6), radius: 4)
                    Text("CLASS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1.2)
                }
                Text(event.title)
                    .font(.system(size: 22, weight: .semibold))
                    .lineLimit(2)
                Text(timeRange)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Detail rows

    @ViewBuilder
    private var detailRows: some View {
        if !event.location.isEmpty {
            iconDetailRow(icon: "mappin.circle.fill", label: "LOCATION", value: event.location)
        }
        iconDetailRow(icon: "clock.fill", label: "DURATION", value: durationText)
        iconDetailRow(icon: "calendar", label: "DATE", value: dateString)

        if let desc = event.description, !desc.isEmpty {
            iconDetailRow(icon: "doc.text", label: "DETAILS", value: desc)
        }
    }

    private func iconDetailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.8)
                Text(value)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    // MARK: - Color section

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COLOR")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(1.2)

            HStack(spacing: 10) {
                ForEach(Array(colorPalette.enumerated()), id: \.offset) { _, color in
                    Button {
                        selectedColor = color
                        appViewModel.setCustomColor(for: event.title, color: color)
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(colorsMatch(color, selectedColor) ? 0.85 : 0), lineWidth: 1.5)
                            )
                            .shadow(color: colorsMatch(color, selectedColor) ? color.opacity(0.8) : color.opacity(0.3), radius: colorsMatch(color, selectedColor) ? 6 : 3, y: 1)
                            .scaleEffect(colorsMatch(color, selectedColor) ? 1.12 : 1)
                            .animation(.spring(response: 0.2), value: colorsMatch(color, selectedColor))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button("Reset") {
                    selectedColor = event.color(from: event.title)
                    appViewModel.setCustomColor(for: event.title, color: nil)
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
    }

    // MARK: - Notes section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("NOTES", systemImage: "note.text")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
                Spacer()
                Button(isEditingNote ? "Save" : "Edit") {
                    if isEditingNote {
                        appViewModel.saveNote(for: event, noteText: noteText)
                    }
                    isEditingNote.toggle()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(eventColor)
            }

            if isEditingNote {
                TextEditor(text: $noteText)
                    .frame(height: 70)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                    )
            } else if !noteText.isEmpty {
                Text(noteText)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.primary)
            } else {
                Text("No notes yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }

    // MARK: - Helpers

    private var softDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
            .padding(.vertical, 2)
    }

    private var timeRange: String {
        let fmt = DateFormatter(); fmt.timeStyle = .short
        return "\(fmt.string(from: event.startTime)) – \(fmt.string(from: event.endTime))"
    }

    private var dateString: String {
        let fmt = DateFormatter(); fmt.dateFormat = "EEEE, MMM d, yyyy"
        return fmt.string(from: event.startTime)
    }

    private var durationText: String {
        let d = Int(event.endTime.timeIntervalSince(event.startTime))
        let h = d / 3600; let m = (d % 3600) / 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        return h > 0 ? "\(h)h" : "\(m)m"
    }

    private var colorPalette: [Color] {
        let baseHue = Double(abs(event.title.hashValue) % 360) / 360.0
        return (0..<9).map { i in
            let hue = (baseHue + Double(i) * 0.11).truncatingRemainder(dividingBy: 1.0)
            return Color(hue: hue, saturation: 0.55, brightness: 0.82)
        }
    }

    private func colorsMatch(_ a: Color, _ b: Color) -> Bool {
        guard let n1 = NSColor(a).usingColorSpace(.deviceRGB),
              let n2 = NSColor(b).usingColorSpace(.deviceRGB) else { return false }
        let t: CGFloat = 0.03
        return abs(n1.redComponent - n2.redComponent) < t
            && abs(n1.greenComponent - n2.greenComponent) < t
            && abs(n1.blueComponent - n2.blueComponent) < t
    }
}

// MARK: - Liquid glass button style

struct DetailCapsuleStyle: ButtonStyle {
    let accent: Color
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if filled {
                    Capsule().fill(accent.gradient)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .overlay(
                Capsule()
                    .strokeBorder(
                        filled ? accent.opacity(0.4) : Color.white.opacity(0.18),
                        lineWidth: 0.5
                    )
            )
            .foregroundStyle(filled ? .white : .primary)
            .shadow(color: filled ? accent.opacity(0.35) : .black.opacity(0.12), radius: filled ? 8 : 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}
