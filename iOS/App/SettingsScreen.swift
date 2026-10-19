import SwiftUI
import ChronologyCore

struct SettingsScreen: View {
    @Environment(AppStore.self) private var store
    @State private var editing: ScheduleProfile?
    @State private var addingProfile = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    ForEach(store.profiles) { profile in
                        Button {
                            editing = profile
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: profile.emoji)
                                    .foregroundStyle(profile.emojiColor?.color ?? .accentColor)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name).foregroundStyle(.primary)
                                    Text(URL(string: profile.icalUrl)?.host() ?? profile.icalUrl)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if profile.id == store.activeProfile?.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .accessibilityLabel("Active")
                                }
                            }
                        }
                        .tint(.primary) // Form buttons otherwise tint their whole label
                        .swipeActions(edge: .leading) {
                            if profile.id != store.activeProfile?.id {
                                Button("Use") { store.activeProfileID = profile.id }
                                    .tint(.accentColor)
                            }
                        }
                    }
                    .onDelete { store.deleteProfiles(at: $0) }

                    Button("Add Schedule", systemImage: "plus") { addingProfile = true }
                } header: {
                    Text("Schedules")
                } footer: {
                    Text("Swipe right to switch, left to delete.")
                }

                Section("Display") {
                    Toggle("24-Hour Time", isOn: $store.use24HourFormat)
                }

                Section {
                    Toggle("Reminders", isOn: Binding(
                        get: { store.notificationsEnabled },
                        set: { value in Task { await store.setNotificationsEnabled(value) } }
                    ))
                    if store.notificationsEnabled {
                        Picker("Remind Me", selection: $store.reminderMinutes) {
                            Text("5 minutes before").tag(5)
                            Text("15 minutes before").tag(15)
                            Text("30 minutes before").tag(30)
                            Text("1 hour before").tag(60)
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("If reminders won't turn on, allow notifications for Chronology in the Settings app.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                    Link(destination: URL(string: "https://github.com/js-surya/Chronology")!) {
                        Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $editing) { ProfileEditorView(profile: $0) }
            .sheet(isPresented: $addingProfile) { ProfileEditorView(profile: nil) }
        }
    }
}

// MARK: - Profile editor

struct ProfileEditorView: View {
    let profile: ScheduleProfile?
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var url = ""
    @State private var icon = "calendar"
    @State private var checking = false
    @State private var checkResult: String?
    @State private var checkFailed = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (try? ScheduleService.normalizedURL(url)) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Spring Semester", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    TextField("https://cloud.timeedit.net/…/ri…ics", text: $url, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(1...4)
                    Button {
                        if let pasted = UIPasteboard.general.string { url = pasted.trimmingCharacters(in: .whitespacesAndNewlines) }
                    } label: {
                        Label("Paste Link", systemImage: "doc.on.clipboard")
                    }
                    Button {
                        Task { await check() }
                    } label: {
                        HStack {
                            Label("Test Link", systemImage: "checkmark.seal")
                            Spacer()
                            if checking { ProgressView() }
                        }
                    }
                    .disabled(checking || (try? ScheduleService.normalizedURL(url)) == nil)
                } header: {
                    Text("iCal Link")
                } footer: {
                    if let checkResult {
                        Label(checkResult, systemImage: checkFailed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(checkFailed ? .orange : .green)
                    } else {
                        Text("In TimeEdit, choose Subscribe and copy the iCal (.ics) link — not the web page address.")
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(EmojiOptions.all.prefix(36), id: \.self) { symbol in
                            Button { icon = symbol } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 42, height: 42)
                                    .background(icon == symbol ? Color.accentColor.opacity(0.2) : Color.clear, in: .rect(cornerRadius: 10))
                                    .foregroundStyle(icon == symbol ? Color.accentColor : .primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol)
                            .accessibilityAddTraits(icon == symbol ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(profile == nil ? "New Schedule" : "Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if let profile {
                    name = profile.name
                    url = profile.icalUrl
                    icon = profile.emoji
                }
            }
        }
    }

    private func check() async {
        checking = true
        defer { checking = false }
        do {
            let events = try await ScheduleService.shared.fetchSchedule(from: url, maxAge: 0)
            checkFailed = events.isEmpty
            checkResult = events.isEmpty ? "Link works, but the calendar has no events." : "Found \(events.count) events."
        } catch {
            checkFailed = true
            checkResult = error.localizedDescription
        }
    }

    private func save() {
        let cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        if var existing = profile {
            existing.name = cleanName
            existing.icalUrl = cleanURL
            existing.emoji = icon
            store.updateProfile(existing)
        } else {
            store.addProfile(ScheduleProfile(name: cleanName, icalUrl: cleanURL, emoji: icon))
        }
        dismiss()
    }
}
