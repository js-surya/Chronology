import SwiftUI
import UserNotifications

// MARK: - Sidebar panes

enum SettingsPane: String, CaseIterable, Identifiable {
    case profiles, appearance, events, grid, notifications, system, about

    var id: String { rawValue }
    var title: String {
        switch self {
        case .profiles: return "Profiles"
        case .appearance: return "Appearance"
        case .events: return "Events"
        case .grid: return "Grid"
        case .notifications: return "Notifications"
        case .system: return "System"
        case .about: return "About"
        }
    }
    var systemImage: String {
        switch self {
        case .profiles: return "person.crop.circle.badge.plus"
        case .appearance: return "paintbrush.fill"
        case .events: return "rectangle.on.rectangle"
        case .grid: return "square.grid.3x3"
        case .notifications: return "bell.badge.fill"
        case .system: return "gearshape.2.fill"
        case .about: return "info.circle.fill"
        }
    }
}

// MARK: - Main SettingsView

struct SettingsView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.colorScheme) var systemColorScheme
    @Binding var isPresented: Bool
    @State private var selection: SettingsPane = .appearance

    private var isAmoledTheme: Bool {
        if appViewModel.themeMode == "amoled" { return true }
        if appViewModel.themeMode == "auto" && appViewModel.preferredDarkMode == "amoled" {
            return systemColorScheme == .dark
        }
        return false
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
            .listStyle(.sidebar)
        } detail: {
            VStack(spacing: 0) {
                ScrollView {
                    paneContent
                        .padding(20)
                }
                Divider()
                HStack {
                    Spacer()
                    Button("Done") { isPresented = false }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(isAmoledTheme ? Color.black : Color(nsColor: .windowBackgroundColor))
            }
        }
        .frame(width: 820, height: 560)
        .tint(appViewModel.accentColor)
        .background(isAmoledTheme ? Color.black : Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var paneContent: some View {
        switch selection {
        case .profiles: ProfilesPane(appViewModel: appViewModel, isAmoledTheme: isAmoledTheme)
        case .appearance: AppearancePane(appViewModel: appViewModel)
        case .events: EventsPane(appViewModel: appViewModel)
        case .grid: GridPane(appViewModel: appViewModel)
        case .notifications: NotificationsPane(appViewModel: appViewModel)
        case .system: SystemPane(appViewModel: appViewModel)
        case .about: AboutPane()
        }
    }
}

// MARK: - Profiles pane

struct ProfilesPane: View {
    @ObservedObject var appViewModel: AppViewModel
    let isAmoledTheme: Bool

    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var editingProfile: ScheduleProfile?
    @State private var profileToDelete: ScheduleProfile?
    @State private var tempName = ""
    @State private var tempUrl = ""
    @State private var tempDescription = ""
    @State private var tempEmoji = "calendar"
    @State private var tempEmojiColor = Color.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Profiles")
                    .font(.title2).fontWeight(.bold)
                Spacer()
                Button {
                    tempName = ""; tempUrl = ""; tempDescription = ""
                    tempEmoji = "calendar"; tempEmojiColor = .blue
                    showingAddSheet = true
                } label: {
                    Label("Add Profile", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }

            if appViewModel.profiles.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary)
                    Text("No profiles yet")
                        .font(.headline)
                    Text("Add your TimeEdit schedule to get started.")
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                VStack(spacing: 6) {
                    ForEach(appViewModel.profiles) { profile in
                        profileRow(profile)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ProfileSheet(title: "Add Profile",
                         name: $tempName, url: $tempUrl, description: $tempDescription,
                         emoji: $tempEmoji, emojiColor: $tempEmojiColor,
                         appViewModel: appViewModel, isAmoledTheme: isAmoledTheme,
                         onSave: {
                let profile = ScheduleProfile(name: tempName, icalUrl: tempUrl,
                                              description: tempDescription,
                                              emoji: tempEmoji,
                                              emojiColor: CodableColor(color: tempEmojiColor))
                appViewModel.addProfile(profile)
                showingAddSheet = false
            }, onCancel: { showingAddSheet = false })
        }
        .sheet(isPresented: $showingEditSheet) {
            ProfileSheet(title: "Edit Profile",
                         name: $tempName, url: $tempUrl, description: $tempDescription,
                         emoji: $tempEmoji, emojiColor: $tempEmojiColor,
                         appViewModel: appViewModel, isAmoledTheme: isAmoledTheme,
                         onSave: {
                if var profile = editingProfile {
                    profile.name = tempName
                    profile.icalUrl = tempUrl
                    profile.description = tempDescription
                    profile.emoji = tempEmoji
                    profile.emojiColor = CodableColor(color: tempEmojiColor)
                    appViewModel.updateProfile(profile)
                }
                showingEditSheet = false
            }, onCancel: { showingEditSheet = false })
        }
        .alert("Delete profile?",
               isPresented: Binding(get: { profileToDelete != nil },
                                    set: { if !$0 { profileToDelete = nil } })) {
            Button("Cancel", role: .cancel) { profileToDelete = nil }
            Button("Delete", role: .destructive) {
                if let p = profileToDelete { appViewModel.deleteProfile(p) }
                profileToDelete = nil
            }
        } message: {
            Text("“\(profileToDelete?.name ?? "")” will be removed. This cannot be undone.")
        }
    }

    private func profileRow(_ profile: ScheduleProfile) -> some View {
        HStack(spacing: 12) {
            Button {
                appViewModel.switchToProfile(profile)
            } label: {
                Image(systemName: appViewModel.activeProfileId == profile.id.uuidString
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(appViewModel.activeProfileId == profile.id.uuidString
                                     ? appViewModel.accentColor : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(appViewModel.activeProfileId == profile.id.uuidString
                  ? "Active profile" : "Switch to this profile")

            ZStack {
                let ringColor = profile.emojiColor?.color ?? .blue
                Circle().fill(ringColor.opacity(0.15)).frame(width: 34, height: 34)
                if profile.emoji.allSatisfy({ $0.isASCII }) {
                    Image(systemName: profile.emoji)
                        .font(.system(size: 16))
                        .foregroundColor(ringColor)
                } else {
                    Text(profile.emoji).font(.system(size: 20))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.headline)
                Text(profile.description.isEmpty ? profile.icalUrl : profile.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                editingProfile = profile
                tempName = profile.name
                tempUrl = profile.icalUrl
                tempDescription = profile.description
                tempEmoji = profile.emoji
                tempEmojiColor = profile.emojiColor?.color ?? .blue
                showingEditSheet = true
            } label: {
                Image(systemName: "pencil")
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Edit profile")

            Button(role: .destructive) {
                profileToDelete = profile
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Delete profile")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isAmoledTheme ? Color.white.opacity(0.04) : Color(nsColor: .controlBackgroundColor))
        )
    }
}

// MARK: - Appearance pane

struct AppearancePane: View {
    @ObservedObject var appViewModel: AppViewModel
    @State private var draftAccent: Color = .blue
    @State private var accentDebounce: Task<Void, Never>?

    private struct Preset: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
    }
    private let presets: [Preset] = [
        .init(name: "Blue", color: .blue),
        .init(name: "Purple", color: .purple),
        .init(name: "Pink", color: .pink),
        .init(name: "Red", color: .red),
        .init(name: "Orange", color: .orange),
        .init(name: "Green", color: .green),
        .init(name: "Teal", color: .teal)
    ]

    private func isSelected(_ color: Color) -> Bool {
        Self.colorsClose(appViewModel.accentColor, color)
    }

    static func colorsClose(_ a: Color, _ b: Color) -> Bool {
        guard let n1 = NSColor(a).usingColorSpace(.deviceRGB),
              let n2 = NSColor(b).usingColorSpace(.deviceRGB) else { return false }
        let t: CGFloat = 0.03
        return abs(n1.redComponent - n2.redComponent) < t
            && abs(n1.greenComponent - n2.greenComponent) < t
            && abs(n1.blueComponent - n2.blueComponent) < t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Appearance")
                .font(.title2).fontWeight(.bold)

            SettingsSection(title: "Accent Color", systemImage: "paintpalette.fill") {
                HStack(spacing: 12) {
                    ForEach(presets) { preset in
                        PresetColorButton(color: preset.color,
                                          isSelected: isSelected(preset.color)) {
                            appViewModel.saveAccentColor(preset.color)
                            draftAccent = preset.color
                        }
                        .help(preset.name)
                    }
                    Divider().frame(height: 24)
                    CustomColorPickerButton(appViewModel: appViewModel)
                        .help("Custom color")
                }
            }

            SettingsSection(title: "Theme", systemImage: "circle.lefthalf.filled") {
                Picker("", selection: $appViewModel.themeMode) {
                    Label("Auto", systemImage: "circle.lefthalf.filled").tag("auto")
                    Label("Light", systemImage: "sun.max.fill").tag("light")
                    Label("Dark", systemImage: "moon.fill").tag("dark")
                    Label("AMOLED", systemImage: "moon.stars.fill").tag("amoled")
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if appViewModel.themeMode == "auto" {
                    HStack {
                        Text("When auto switches to dark:")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $appViewModel.preferredDarkMode) {
                            Text("Standard").tag("dark")
                            Text("AMOLED").tag("amoled")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 130)
                    }
                }

                if appViewModel.themeMode == "amoled"
                    || (appViewModel.themeMode == "auto" && appViewModel.preferredDarkMode == "amoled") {
                    InlineCallout(text: "Pure black background for OLED displays. Saves battery on supported Macs.")
                }
            }
        }
        .onAppear { draftAccent = appViewModel.accentColor }
    }
}

// MARK: - Events pane (with live preview)

struct EventsPane: View {
    @ObservedObject var appViewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Events")
                .font(.title2).fontWeight(.bold)

            SettingsSection(title: "Live Preview", systemImage: "eye.fill") {
                HStack(spacing: 10) {
                    LiveEventPreview(appViewModel: appViewModel,
                                     title: "Lecture", location: "Room A1.05",
                                     tint: appViewModel.accentColor)
                    LiveEventPreview(appViewModel: appViewModel,
                                     title: "Lab", location: "Studio 3",
                                     tint: .orange)
                    LiveEventPreview(appViewModel: appViewModel,
                                     title: "Seminar", location: "Online",
                                     tint: .green)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
            }

            SettingsSection(title: "Card Style", systemImage: "rectangle.on.rectangle") {
                Picker("", selection: $appViewModel.eventCardStyle) {
                    Label("Filled", systemImage: "square.fill").tag("filled")
                    Label("Bordered", systemImage: "square").tag("bordered")
                    Label("Minimal", systemImage: "square.dashed").tag("minimal")
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                SettingsRow(title: "Corner Radius", subtitle: "Roundness of event cards") {
                    HStack(spacing: 8) {
                        Slider(value: $appViewModel.eventCornerRadius, in: 0...16, step: 1)
                            .frame(width: 160)
                        Text("\(Int(appViewModel.eventCornerRadius)) pt")
                            .font(.caption).foregroundColor(.secondary)
                            .monospacedDigit().frame(width: 44)
                    }
                }
                SettingsRow(title: "Border Width", subtitle: "Thickness of event borders") {
                    HStack(spacing: 8) {
                        Slider(value: $appViewModel.eventBorderWidth, in: 0...4, step: 0.5)
                            .frame(width: 160)
                        Text(String(format: "%.1f pt", appViewModel.eventBorderWidth))
                            .font(.caption).foregroundColor(.secondary)
                            .monospacedDigit().frame(width: 44)
                    }
                }
                Toggle(isOn: $appViewModel.eventShadowEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Card Shadows").font(.body)
                        Text("Add soft shadow beneath cards").font(.caption).foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: $appViewModel.showEventIcons) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Icons").font(.body)
                        Text("Display icons on event cards").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Grid pane

struct GridPane: View {
    @ObservedObject var appViewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Grid Appearance")
                .font(.title2).fontWeight(.bold)

            SettingsSection(title: "Preview", systemImage: "eye.fill") {
                GridPreviewSwatch(appViewModel: appViewModel)
            }

            SettingsSection(title: "Calendar Hours", systemImage: "clock.fill") {
                SettingsRow(title: "Visible Hours", subtitle: "Range shown in Week view") {
                    HStack(spacing: 8) {
                        Picker("Start", selection: $appViewModel.startHour) {
                            ForEach(0...22, id: \.self) { Text("\($0):00").tag($0) }
                        }
                        .labelsHidden().frame(width: 80)
                        Text("to").foregroundColor(.secondary)
                        Picker("End", selection: $appViewModel.endHour) {
                            ForEach(1...23, id: \.self) { Text("\($0):00").tag($0) }
                        }
                        .labelsHidden().frame(width: 80)
                    }
                }
                .onChange(of: appViewModel.startHour) { _, newStart in
                    if appViewModel.endHour <= newStart {
                        appViewModel.endHour = min(23, newStart + 1)
                    }
                }
                .onChange(of: appViewModel.endHour) { _, newEnd in
                    if newEnd <= appViewModel.startHour {
                        appViewModel.startHour = max(0, newEnd - 1)
                    }
                }
                Toggle(isOn: $appViewModel.use24HourFormat) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("24-Hour Format").font(.body)
                        Text("Display times in 24-hour notation").font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            SettingsSection(title: "Grid Lines", systemImage: "square.grid.3x3") {
                SettingsRow(title: "Background Opacity", subtitle: "Cell background tint") {
                    HStack(spacing: 8) {
                        Slider(value: $appViewModel.gridBackgroundOpacity, in: 0...0.3, step: 0.01)
                            .frame(width: 160)
                        Text(String(format: "%.0f%%", appViewModel.gridBackgroundOpacity * 100))
                            .font(.caption).foregroundColor(.secondary)
                            .monospacedDigit().frame(width: 44)
                    }
                }
                SettingsRow(title: "Line Thickness", subtitle: "Width of grid borders") {
                    HStack(spacing: 8) {
                        Slider(value: $appViewModel.gridLineThickness, in: 0.2...2.0, step: 0.1)
                            .frame(width: 160)
                        Text(String(format: "%.1f pt", appViewModel.gridLineThickness))
                            .font(.caption).foregroundColor(.secondary)
                            .monospacedDigit().frame(width: 44)
                    }
                }
                SettingsRow(title: "Line Opacity", subtitle: "Visibility of grid lines") {
                    HStack(spacing: 8) {
                        Slider(value: $appViewModel.gridLineOpacity, in: 0...0.5, step: 0.01)
                            .frame(width: 160)
                        Text(String(format: "%.0f%%", appViewModel.gridLineOpacity * 100))
                            .font(.caption).foregroundColor(.secondary)
                            .monospacedDigit().frame(width: 44)
                    }
                }
            }
        }
    }
}

// MARK: - Notifications pane

struct NotificationsPane: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var permissionDenied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notifications")
                .font(.title2).fontWeight(.bold)

            SettingsSection(title: "Reminders", systemImage: "bell.badge.fill") {
                Toggle(isOn: $appViewModel.notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Notifications").font(.body)
                        Text("Get notified before events start").font(.caption).foregroundColor(.secondary)
                    }
                }
                .onChange(of: appViewModel.notificationsEnabled) { old, new in
                    if new && !old {
                        NotificationManager.shared.requestAuthorization { granted in
                            if !granted {
                                appViewModel.notificationsEnabled = false
                                permissionDenied = true
                            }
                        }
                    }
                }

                if permissionDenied || (!notificationManager.isAuthorized && appViewModel.notificationsEnabled) {
                    InlineCallout(
                        text: "Notifications are disabled in System Settings. Enable them to receive reminders.",
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                    Button("Open Notification Settings…") {
                        NotificationManager.shared.openNotificationSettings()
                    }
                    .buttonStyle(.link)
                }

                if appViewModel.notificationsEnabled {
                    SettingsRow(title: "Reminder Timing", subtitle: "When to remind you before events") {
                        Picker("", selection: $appViewModel.notificationMinutesBefore) {
                            Text("5 minutes").tag(5)
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                            Text("1 hour").tag(60)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 130)
                    }

                    Divider()

                    TestNotificationButton()
                }
            }
        }
        .onAppear { NotificationManager.shared.checkAuthorizationStatus() }
    }
}

// MARK: - System pane

struct SystemPane: View {
    @ObservedObject var appViewModel: AppViewModel
    @StateObject var launchAtLoginManager = LaunchAtLoginManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("System")
                .font(.title2).fontWeight(.bold)

            SettingsSection(title: "Startup", systemImage: "power") {
                Toggle(isOn: $launchAtLoginManager.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login").font(.body)
                        Text("Start Chronology automatically when you log in")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                if !launchAtLoginManager.isEnabled {
                    Button("Open Login Items Settings…") {
                        launchAtLoginManager.openLoginItemsSettings()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }

            SettingsSection(title: "Menu Bar & Dock", systemImage: "macwindow") {
                Toggle(isOn: $appViewModel.showMenuBarIcon) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Menu Bar Icon").font(.body)
                        Text("Display schedule status in the menu bar")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: $appViewModel.hideFromDock) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide from Dock").font(.body)
                        Text("Run in menu bar only, hide dock icon and window")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .disabled(!appViewModel.showMenuBarIcon)

                if appViewModel.hideFromDock {
                    InlineCallout(text: "Click the menu bar icon to access the app and settings.")
                }
            }
        }
        .onAppear { launchAtLoginManager.refreshStatus() }
    }
}

// MARK: - About pane

struct AboutPane: View {
    @State private var showConfetti = false
    @State private var clickCount = 0
    @State private var lastClickTime = Date()
    @State private var heartScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            VStack(spacing: 18) {
                if let appIcon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 128, height: 128)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                VStack(spacing: 4) {
                    Text("Chronology")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Version 3.0.0")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Text("A beautiful schedule viewer for TimeEdit.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Spacer()

                Button {
                    heartBounce()
                    handleHeartClick()
                } label: {
                    HStack(spacing: 4) {
                        Text("Made with")
                        Text("❤️")
                            .foregroundColor(.red)
                            .scaleEffect(heartScale)
                        Text("by Surya & AI")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Click rapidly for a surprise!")
                .padding(.bottom)
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showConfetti {
                ConfettiExplosionView()
            }
        }
    }

    private func heartBounce() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) { heartScale = 1.3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) { heartScale = 1.0 }
        }
    }

    private func handleHeartClick() {
        let now = Date()
        if now.timeIntervalSince(lastClickTime) < 0.4 { clickCount += 1 } else { clickCount = 1 }
        lastClickTime = now
        if clickCount >= 5 {
            showConfetti = true
            clickCount = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { showConfetti = false }
        }
    }
}

// MARK: - Profile sheet

struct ProfileSheet: View {
    let title: String
    @Binding var name: String
    @Binding var url: String
    @Binding var description: String
    @Binding var emoji: String
    @Binding var emojiColor: Color
    @ObservedObject var appViewModel: AppViewModel
    let isAmoledTheme: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    private let gridColumns = Array(repeating: GridItem(.fixed(40), spacing: 8), count: 8)

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(emojiColor.opacity(0.15)).frame(width: 64, height: 64)
                if emoji.allSatisfy({ $0.isASCII }) {
                    Image(systemName: emoji).font(.system(size: 30)).foregroundColor(emojiColor)
                } else {
                    Text(emoji).font(.system(size: 36))
                }
            }
            Text(title).font(.title2).fontWeight(.bold)

            VStack(alignment: .leading, spacing: 6) {
                Text("Icon").font(.caption).foregroundColor(.secondary).textCase(.uppercase)
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 8) {
                        ForEach(EmojiOptions.all, id: \.self) { opt in
                            Button { emoji = opt } label: {
                                ZStack {
                                    if emoji == opt {
                                        Circle().fill(appViewModel.accentColor.opacity(0.2))
                                            .frame(width: 38, height: 38)
                                    }
                                    Image(systemName: opt)
                                        .font(.title3)
                                        .foregroundColor(emoji == opt ? appViewModel.accentColor : .primary)
                                        .frame(width: 38, height: 38)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 150)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                )

                HStack {
                    Text("Icon Color").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    ColorPicker("", selection: $emojiColor, supportsOpacity: false)
                        .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                labeledField("Profile Name", placeholder: "e.g., My Schedule", text: $name)
                labeledField("Description (Optional)", placeholder: "e.g., Fall Semester 2025", text: $description)
                labeledField("iCal URL", placeholder: "https://…", text: $url)
            }

            HStack {
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || url.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480, height: 580)
        .background(isAmoledTheme ? Color.black : Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func labeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary).textCase(.uppercase)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Test notification button

struct TestNotificationButton: View {
    @State private var resultMessage: String = ""
    @State private var showResult: Bool = false
    @State private var isSuccess: Bool = false
    @ObservedObject private var notificationManager = NotificationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        switch settings.authorizationStatus {
                        case .notDetermined:
                            NotificationManager.shared.requestAuthorization { granted in
                                if granted {
                                    sendTest()
                                } else {
                                    show(success: false, message: "Permission denied. Open Notification Settings to enable.")
                                }
                            }
                        case .denied:
                            show(success: false, message: "Notifications were disabled. Open Notification Settings above to enable them.")
                        case .authorized, .provisional, .ephemeral:
                            sendTest()
                        @unknown default:
                            show(success: false, message: "Unknown notification status. Check System Settings.")
                        }
                    }
                }
            } label: {
                Label("Send Test Notification", systemImage: "bell.fill")
            }
            .buttonStyle(.bordered)

            if showResult {
                HStack(spacing: 6) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isSuccess ? .green : .orange)
                    Text(resultMessage).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .onAppear { NotificationManager.shared.checkAuthorizationStatus() }
    }

    private func sendTest() {
        NotificationManager.shared.sendTestNotification { success, message in
            show(success: success, message: message)
        }
    }

    private func show(success: Bool, message: String) {
        isSuccess = success
        resultMessage = message
        showResult = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { showResult = false }
    }
}

// MARK: - Preset color button

struct PresetColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color).frame(width: 26, height: 26)
                if isSelected {
                    Circle()
                        .strokeBorder(color, lineWidth: 2)
                        .frame(width: 34, height: 34)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1)
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}

// MARK: - Custom color picker (debounced)

struct CustomColorPickerButton: View {
    @ObservedObject var appViewModel: AppViewModel
    @State private var localColor: Color = .blue
    @State private var debounce: Task<Void, Never>?

    var body: some View {
        ColorPicker("", selection: $localColor, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 28, height: 28)
            .onAppear { localColor = appViewModel.accentColor }
            .onChange(of: localColor) { _, newColor in
                debounce?.cancel()
                debounce = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    if !Task.isCancelled {
                        appViewModel.saveAccentColor(newColor)
                    }
                }
            }
    }
}

// MARK: - Confetti

struct ConfettiExplosionView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<75, id: \.self) { _ in
                    ConfettiParticle(containerSize: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ConfettiParticle: View {
    let containerSize: CGSize
    @State private var position: CGPoint
    @State private var opacity: Double = 1.0
    @State private var rotation: Double = 0
    @State private var rotation3D: Double = 0

    let color: Color = [Color.red, .blue, .green, .yellow, .pink, .purple, .orange, .cyan, .mint].randomElement()!

    init(containerSize: CGSize) {
        self.containerSize = containerSize
        let startX = CGFloat.random(in: 0...containerSize.width)
        let startY = CGFloat.random(in: -100...0)
        _position = State(initialValue: CGPoint(x: startX, y: startY))
    }

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 8)
            .position(position)
            .rotationEffect(.degrees(rotation))
            .rotation3DEffect(.degrees(rotation3D), axis: (x: 1, y: 1, z: 0))
            .opacity(opacity)
            .onAppear {
                let duration = Double.random(in: 2.0...4.0)
                withAnimation(.linear(duration: duration)) {
                    position.y = containerSize.height + 50
                    position.x += CGFloat.random(in: -40...40)
                    rotation += Double.random(in: 180...720)
                    rotation3D += Double.random(in: 180...720)
                }
                withAnimation(.easeIn(duration: 0.5).delay(duration - 0.5)) {
                    opacity = 0
                }
            }
    }
}
