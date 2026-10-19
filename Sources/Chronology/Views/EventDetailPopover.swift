import SwiftUI
import UserNotifications
import ChronologyCore

struct EventDetailPopover: View {
    let event: Event
    @EnvironmentObject var appViewModel: AppViewModel

    @State private var noteText = ""
    @State private var isEditingNote = false
    @State private var selectedColor: Color

    private var eventColor: Color { appViewModel.eventColor(for: event) }

    private var isImportant: Bool { appViewModel.isEventImportant(event) }

    init(event: Event) {
        self.event = event
        _selectedColor = State(initialValue: event.color(from: event.title))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Accent band header
            accentBand

            // Sized to content: popovers on macOS hug their content, so no ScrollView padding gap
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

            Divider()

            // Footer: marking important also schedules its own reminder
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(isImportant ? "Important" : "Not marked")
                        .font(.subheadline.weight(.medium))
                    Text(reminderCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isImportant {
                    Button(action: toggleImportant) {
                        Label("Important", systemImage: "star.fill")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(eventColor)
                } else {
                    Button(action: toggleImportant) {
                        Label("Mark Important", systemImage: "star")
                    }
                    .buttonStyle(.glass)
                    .tint(eventColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 360)
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

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(eventColor)
                        .frame(width: 10, height: 10)
                    Text("CLASS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1.2)
                }
                Text(event.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text(appViewModel.timeRange(event))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
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
            iconDetailRow(icon: "doc.text", label: "DETAILS", value: desc, lineLimit: 6)
        }
    }

    private func iconDetailRow(icon: String, label: String, value: String, lineLimit: Int? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(eventColor)
                .frame(width: 28, height: 28)
                .background(eventColor.opacity(0.14), in: .rect(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.8)
                Text(value)
                    .font(.body)
                    .lineLimit(lineLimit)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    // MARK: - Color section

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("COLOR")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
                Spacer()
                Button("Reset") {
                    selectedColor = event.color(from: event.title)
                    appViewModel.setCustomColor(for: event.title, color: nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(eventColor)
                .disabled(appViewModel.getCustomColor(for: event.title) == nil)
            }

            // 9 × 28pt + 8 × 6pt = 300pt, fits the 320pt content width
            HStack(spacing: 6) {
                ForEach(Array(colorPalette.enumerated()), id: \.offset) { _, color in
                    Button {
                        selectedColor = color
                        appViewModel.setCustomColor(for: event.title, color: color)
                    } label: {
                        let selected = colorsMatch(color, selectedColor)
                        Circle()
                            .fill(color)
                            .frame(width: 24, height: 24)
                            .overlay {
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(2)
                            .overlay(Circle().strokeBorder(selected ? color : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(colorsMatch(color, selectedColor) ? "Selected color" : "Color option")
                }

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
                    .padding(6)
                    .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 10))
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

    private var dateString: String {
        event.startTime.formatted(date: .complete, time: .omitted)
    }

    private var reminderCaption: String {
        guard isImportant else { return "Important events get an extra reminder" }
        let minutes = appViewModel.getImportantEvent(event)?.reminderMinutes ?? 15
        return "Reminder \(minutes) min before"
    }

    private func toggleImportant() {
        let becomingImportant = !isImportant
        appViewModel.toggleImportant(event)
        // A reminder needs notifications on
        if becomingImportant && !appViewModel.notificationsEnabled {
            appViewModel.notificationsEnabled = true
        }
    }

    private var durationText: String {
        let d = Int(event.endTime.timeIntervalSince(event.startTime))
        let h = d / 3600; let m = (d % 3600) / 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        return h > 0 ? "\(h)h" : "\(m)m"
    }

    private var colorPalette: [Color] {
        let baseHue = hueForCourse(event.title) / 360.0
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
