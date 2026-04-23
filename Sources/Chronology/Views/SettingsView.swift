import SwiftUI
import UserNotifications

// MARK: - Sidebar panes

enum SettingsPane: String, CaseIterable, Identifiable {
    case profiles, appearance, hours, notifications, reminders, system, about

    var id: String { rawValue }
    var title: String {
        switch self {
        case .profiles:      return "Profiles"
        case .appearance:    return "Appearance"
        case .hours:         return "Hours"
        case .notifications: return "Notifications"
        case .reminders:     return "Reminders"
        case .system:        return "System"
        case .about:         return "About"
        }
    }
    var systemImage: String {
        switch self {
        case .profiles:      return "person.crop.circle.badge.plus"
        case .appearance:    return "paintbrush.fill"
        case .hours:         return "clock.fill"
        case .notifications: return "bell.badge.fill"
        case .reminders:     return "star.fill"
        case .system:        return "gearshape.2.fill"
        case .about:         return "info.circle.fill"
        }
    }
}

// MARK: - Main SettingsView

struct SettingsView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.colorScheme) var systemColorScheme
    @Binding var isPresented: Bool
    @State private var selection: SettingsPane = .appearance

    private var resolvedTheme: AppTheme {
        appViewModel.resolvedTheme(for: systemColorScheme)
    }

    private var isAmoledTheme: Bool { resolvedTheme == .amoled }
    private var isSolidTheme: Bool { resolvedTheme.isSolid }

    private var solidBackground: Color {
        switch resolvedTheme {
        case .amoled:    return .black
        case .darkSolid: return Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1))
        default:         return Color(nsColor: .windowBackgroundColor)
        }
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
                .background(solidBackground)
            }
        }
        .frame(width: 820, height: 560)
        .tint(appViewModel.accentColor)
        .background(solidBackground)
    }

    @ViewBuilder
    private var paneContent: some View {
        switch selection {
        case .profiles:      ProfilesPane(appViewModel: appViewModel, solidBackground: solidBackground)
        case .appearance:    AppearancePane(appViewModel: appViewModel)
        case .hours:         HoursPane(appViewModel: appViewModel)
        case .notifications: NotificationsPane(appViewModel: appViewModel)
        case .reminders:     RemindersPane(appViewModel: appViewModel)
        case .system:        SystemPane(appViewModel: appViewModel)
        case .about:         AboutPane()
        }
    }
}

// MARK: - Profiles pane

struct ProfilesPane: View {
    @ObservedObject var appViewModel: AppViewModel
    let solidBackground: Color

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
                         appViewModel: appViewModel, solidBackground: solidBackground,
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
                         appViewModel: appViewModel, solidBackground: solidBackground,
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
                .fill(solidBackground == Color(nsColor: .windowBackgroundColor) ? Color(nsColor: .controlBackgroundColor) : Color.white.opacity(0.04))
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
                HStack(spacing: 8) {
                    ForEach(AppTheme.allCases, id: \.self) { t in
                        Button {
                            appViewModel.themeMode = t.rawValue
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: t.systemImage)
                                    .font(.system(size: 18))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(appViewModel.themeMode == t.rawValue
                                                  ? appViewModel.accentColor.opacity(0.15)
                                                  : Color.primary.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(appViewModel.themeMode == t.rawValue
                                                    ? appViewModel.accentColor
                                                    : Color.clear, lineWidth: 1.5)
                                    )
                                Text(t.displayName)
                                    .font(.caption2)
                                    .foregroundColor(appViewModel.themeMode == t.rawValue
                                                     ? appViewModel.accentColor : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                if appViewModel.themeMode == "amoled" {
                    InlineCallout(text: "Pure black background for OLED displays. Saves battery on supported Macs.")
                }
                if appViewModel.themeMode == "darkSolid" {
                    InlineCallout(text: "Opaque dark surface — no translucency. Consistent on all display types.")
                }
            }

            SettingsSection(title: "Time Format", systemImage: "clock") {
                Picker("", selection: $appViewModel.use24HourFormat) {
                    Text("24-hour").tag(true)
                    Text("12-hour").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .onAppear { draftAccent = appViewModel.accentColor }
    }
}

// MARK: - Hours pane

struct HoursPane: View {
    @ObservedObject var appViewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hours")
                .font(.title2).fontWeight(.bold)

            SettingsSection(title: "Visible Range", systemImage: "clock.fill") {
                SettingsRow(title: "Start", subtitle: "First hour shown in the grid") {
                    HourStepperControl(
                        value: $appViewModel.startHour,
                        range: 0...(appViewModel.endHour - 1)
                    )
                }
                SettingsRow(title: "End", subtitle: "Last hour shown in the grid") {
                    HourStepperControl(
                        value: $appViewModel.endHour,
                        range: (appViewModel.startHour + 1)...23
                    )
                }
            }

            SettingsSection(title: "Week", systemImage: "calendar") {
                SettingsRow(title: "Week starts on", subtitle: "") {
                    Picker("", selection: .constant("monday")) {
                        Text("Monday").tag("monday")
                        Text("Sunday").tag("sunday")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 200)
                }
                Toggle(isOn: $appViewModel.use24HourFormat) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("24-Hour Format").font(.body)
                        Text("Display times in 24-hour notation").font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            SettingsSection(title: "Grid Lines", systemImage: "square.grid.3x3") {
                SettingsRow(title: "Line Opacity", subtitle: "Visibility of hour grid lines") {
                    HStack(spacing: 8) {
                        Slider(value: $appViewModel.gridLineOpacity, in: 0...0.5, step: 0.01)
                            .frame(width: 160)
                        Text(String(format: "%.0f%%", appViewModel.gridLineOpacity * 100))
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
            }
        }
    }
}

struct HourStepperControl: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if value > range.lowerBound { value -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .disabled(value <= range.lowerBound)

            Text(String(format: "%02d:00", value))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .center)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

            Button {
                if value < range.upperBound { value += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .disabled(value >= range.upperBound)
        }
    }
}

// MARK: - Reminders pane

struct RemindersPane: View {
    @ObservedObject var appViewModel: AppViewModel

    private var importantUpcoming: [ImportantEvent] {
        appViewModel.importantEvents
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reminders")
                .font(.title2).fontWeight(.bold)

            if importantUpcoming.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No starred events")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Star an event from its detail popover. Starred items appear here and trigger extra reminders.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                SettingsSection(title: "Starred Events", systemImage: "star.fill") {
                    ForEach(importantUpcoming, id: \.eventTitle) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.eventTitle)
                                    .font(.body)
                                    .lineLimit(1)
                                if item.reminderMinutes > 0 {
                                    Text("Remind \(item.reminderMinutes) min before")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
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
                SettingsRow(title: "Enable Notifications", subtitle: "Get notified before events start") {
                    GlassToggle(isOn: $appViewModel.notificationsEnabled,
                                accent: appViewModel.accentColor)
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
                SettingsRow(title: "Launch at Login",
                            subtitle: "Start Chronology automatically when you log in") {
                    GlassToggle(isOn: $launchAtLoginManager.isEnabled,
                                accent: appViewModel.accentColor)
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
                SettingsRow(title: "Show Menu Bar Icon",
                            subtitle: "Display schedule status in the menu bar") {
                    GlassToggle(isOn: $appViewModel.showMenuBarIcon,
                                accent: appViewModel.accentColor)
                }
                SettingsRow(title: "Hide from Dock",
                            subtitle: "Run in menu bar only, hide dock icon and window") {
                    GlassToggle(isOn: $appViewModel.hideFromDock,
                                accent: appViewModel.accentColor)
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
                    Text("Version 4.0.0")
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
    let solidBackground: Color
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
        .background(profileSheetBackground)
    }

    private var profileSheetBackground: Color { solidBackground }

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
