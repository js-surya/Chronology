import SwiftUI
import ChronologyCore

struct SettingsScreen: View {
    @Environment(AppStore.self) private var store
    @State private var editing: ScheduleProfile?
    @State private var addingProfile = false
    @State private var testResult: String?

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

                Section("Appearance") {
                    Picker("Theme", selection: $store.appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        ForEach(AccentPreset.all) { preset in
                            Button { store.accentPreset = preset.id } label: {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        if store.accentPreset == preset.id {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(preset.id.capitalized) accent")
                            .accessibilityAddTraits(store.accentPreset == preset.id ? .isSelected : [])
                        }
                        Spacer(minLength: 0)
                        ColorPicker("Custom accent", selection: Binding(
                            get: { store.accentColor },
                            set: { store.customAccent = CodableColor(color: $0); store.accentPreset = "custom" }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)
                }

                Section {
                    Toggle("24-Hour Time", isOn: $store.use24HourFormat)
                    Picker("Day Starts", selection: $store.dayStartHour) {
                        ForEach(0..<store.dayEndHour, id: \.self) { Text(hourLabel($0, use24Hour: store.use24HourFormat)).tag($0) }
                    }
                    Picker("Day Ends", selection: $store.dayEndHour) {
                        ForEach((store.dayStartHour + 1)...24, id: \.self) { Text(hourLabel($0, use24Hour: store.use24HourFormat)).tag($0) }
                    }
                } header: {
                    Text("Calendar")
                } footer: {
                    Text("The timeline still stretches to show classes outside these hours.")
                }

                Section {
                    Toggle(isOn: $store.liveActivityEnabled) {
                        Label("Live Activity", systemImage: "platter.filled.top.iphone")
                    }
                } header: {
                    Text("Dynamic Island")
                } footer: {
                    if store.liveActivityEnabled && !store.liveActivitiesAllowedBySystem {
                        Text("Live Activities are turned off for Chronology in the Settings app.")
                    } else {
                        Text("Shows the current class, or the next one starting within an hour, in the Dynamic Island and on the Lock Screen.")
                    }
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
                        Toggle(isOn: $store.alertAtClassStart) {
                            Label("When Class Starts", systemImage: "bell.and.waves.left.and.right")
                        }
                        Toggle(isOn: $store.alertAtClassEnd) {
                            Label("When Class Ends", systemImage: "checkmark.circle")
                        }
                    }
                    NavigationLink {
                        ImportantEventsView()
                    } label: {
                        LabeledContent {
                            Text("\(store.importantUpcoming().count)")
                        } label: {
                            Label("Important Events", systemImage: "star.fill")
                        }
                    }
                    Button("Send Test Notification", systemImage: "bell.badge") {
                        Task { testResult = await store.sendTestNotification() }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text(testResult ?? "If reminders won't turn on, allow notifications for Chronology in the Settings app.")
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        LabeledContent {
                            Text(AboutText.displayVersion)
                        } label: {
                            Label("About", systemImage: "info.circle")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .tint(store.accentColor) // menu pickers in a Form don't inherit the root tint
            .sheet(item: $editing) { ProfileEditorView(profile: $0) }
            .sheet(isPresented: $addingProfile) { ProfileEditorView(profile: nil) }
        }
    }
}

func hourLabel(_ hour: Int, use24Hour: Bool) -> String {
    if use24Hour { return String(format: "%02d:00", hour) }
    let h = hour % 12 == 0 ? 12 : hour % 12
    return "\(h) \(hour < 12 || hour == 24 ? "AM" : "PM")"
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: AboutText.displayVersion)
                Text(AboutText.purpose)
                Text(AboutText.privacy).foregroundStyle(.secondary)
            }
            Section {
                ForEach(AboutText.acknowledgements, id: \.self) { Text($0) }
                    .font(.footnote)
            } header: {
                Text("Acknowledgements")
            }
            Section {
                AboutFooter()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 24, trailing: 0))
            }
        }
        .navigationTitle("About")
    }
}

/// The sign-off at the bottom of About: app icon, name, tagline, credit and a link to the source code.
struct AboutFooter: View {
    var body: some View {
        VStack(spacing: 10) {
            Image("about-app-icon")
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .accessibilityHidden(true)
            VStack(spacing: 2) {
                Text(AboutText.appName).font(.headline)
                Text(AboutText.tagline).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(AboutText.credit)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            Link(destination: AboutText.sourceCode) {
                Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.tint.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .padding(.top, 2)
            .accessibilityLabel("Source code on GitHub")
            .accessibilityHint("Opens in your browser")
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Important events

/// Starred upcoming events with their own reminder time (the Mac Reminders pane).
struct ImportantEventsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let events = store.importantUpcoming()
        List {
            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 8) {
                    EventRow(event: event, showsDate: true)
                    Picker("Remind me", selection: Binding(
                        get: { store.reminderMinutes(for: event) },
                        set: { store.setReminderMinutes($0, for: event) }
                    )) {
                        Text("5 min before").tag(5)
                        Text("15 min before").tag(15)
                        Text("30 min before").tag(30)
                        Text("1 hour before").tag(60)
                        Text("1 day before").tag(1440)
                    }
                    .font(.subheadline)
                }
                .swipeActions {
                    Button("Unstar", systemImage: "star.slash", role: .destructive) {
                        Task { await store.toggleImportant(event) }
                    }
                }
            }
        }
        .overlay {
            if events.isEmpty {
                ContentUnavailableView("No Important Events", systemImage: "star",
                                       description: Text("Open an event and turn on Important to get an extra reminder."))
            }
        }
        .navigationTitle("Important Events")
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
    @State private var iconColor: String?
    @State private var checking = false
    @State private var checkResult: String?
    @State private var checkFailed = false

    private var selectedIconColor: Color {
        AccentPreset.all.first { $0.id == iconColor }?.color ?? .accentColor
    }

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
                    HStack(spacing: 10) {
                        ForEach(AccentPreset.all) { preset in
                            Button { iconColor = preset.id } label: {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        if iconColor == preset.id {
                                            Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(preset.id.capitalized) icon color")
                        }
                    }
                    .padding(.vertical, 2)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(EmojiOptions.all.prefix(36), id: \.self) { symbol in
                            Button { icon = symbol } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 42, height: 42)
                                    .background(icon == symbol ? selectedIconColor.opacity(0.2) : Color.clear, in: .rect(cornerRadius: 10))
                                    .foregroundStyle(icon == symbol ? selectedIconColor : .primary)
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
                    iconColor = profile.emojiColor.flatMap { stored in
                        AccentPreset.all.first { CodableColor(color: $0.color) == stored }?.id
                    }
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
            existing.emojiColor = iconColor == nil ? existing.emojiColor : CodableColor(color: selectedIconColor)
            store.updateProfile(existing)
        } else {
            store.addProfile(ScheduleProfile(name: cleanName, icalUrl: cleanURL, emoji: icon,
                                             emojiColor: iconColor == nil ? nil : CodableColor(color: selectedIconColor)))
        }
        dismiss()
    }
}
