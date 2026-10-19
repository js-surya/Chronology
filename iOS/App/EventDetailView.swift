import SwiftUI
import ChronologyCore

struct EventDetailView: View {
    let event: Event
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var noteText = ""
    @FocusState private var noteFocused: Bool

    private var palette: [Color] {
        let base = hueForCourse(event.title) / 360
        return (0..<8).map { i in
            Color(hue: (base + Double(i) * 0.125).truncatingRemainder(dividingBy: 1), saturation: 0.6, brightness: 0.85)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle().fill(store.color(for: event)).frame(width: 10, height: 10)
                            Text(event.startTime.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(event.title)
                            .font(.title2.weight(.semibold))
                        Text(store.timeRange(event))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    if !event.location.isEmpty {
                        LabeledContent { Text(event.location).textSelection(.enabled) } label: {
                            Label("Location", systemImage: "mappin.and.ellipse")
                        }
                    }
                    LabeledContent { Text(duration) } label: {
                        Label("Duration", systemImage: "hourglass")
                    }
                    if let details = event.description, !details.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Details", systemImage: "doc.text")
                            Text(details)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { store.isImportant(event) },
                        set: { _ in Task { await store.toggleImportant(event) } }
                    )) {
                        Label("Important", systemImage: "star.fill")
                    }
                    .tint(.yellow)
                } footer: {
                    Text(store.isImportant(event)
                         ? "You'll get an extra reminder \(store.reminderMinutes) minutes before."
                         : "Important events get an extra reminder.")
                }

                Section("Color") {
                    HStack(spacing: 10) {
                        ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                            Button {
                                store.setColor(color, for: event)
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if store.hasCustomColor(event) && matches(color) {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(palette.firstIndex(of: color).map { $0 + 1 } ?? 0)")
                        }
                    }
                    if store.hasCustomColor(event) {
                        Button("Use Default Color") { store.setColor(nil, for: event) }
                    }
                }

                Section("Notes") {
                    TextField("Add a note", text: $noteText, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($noteFocused)
                }
            }
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .onAppear { noteText = store.note(for: event) }
            .onDisappear { store.setNote(noteText, for: event) }
        }
        .presentationDetents([.medium, .large])
    }

    private var duration: String {
        let minutes = Int(event.duration / 60)
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        return h > 0 ? "\(h)h" : "\(m)m"
    }

    private func matches(_ color: Color) -> Bool {
        let current = CodableColor(color: store.color(for: event))
        let candidate = CodableColor(color: color)
        return abs(current.red - candidate.red) < 0.02
            && abs(current.green - candidate.green) < 0.02
            && abs(current.blue - candidate.blue) < 0.02
    }
}
