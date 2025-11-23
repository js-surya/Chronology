import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.colorScheme) var systemColorScheme
    @Binding var isPresented: Bool
    @State private var selectedTab = 1
    
    private var isAmoledTheme: Bool {
        if appViewModel.themeMode == "amoled" {
            return true
        }
        if appViewModel.themeMode == "auto" && appViewModel.preferredDarkMode == "amoled" {
            return systemColorScheme == .dark
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Label("Profiles", systemImage: "person.badge.plus").tag(0)
                Label("General", systemImage: "gear").tag(1)
                Label("About", systemImage: "info.circle").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.top, 20)
            .padding(.horizontal, 20)
            .labelsHidden()
            
            Group {
                switch selectedTab {
                case 0:
                    ProfilesTab(appViewModel: appViewModel, isAmoledTheme: isAmoledTheme)
                case 1:
                    GeneralTab(appViewModel: appViewModel)
                case 2:
                    AboutTab()
                default:
                    EmptyView()
                }
            }
            .padding()
            .frame(width: 500, height: 400)
            
            HStack {
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(isAmoledTheme ? Color.black : Color(nsColor: .windowBackgroundColor))
        }
        .background(isAmoledTheme ? Color.black : Color(nsColor: .windowBackgroundColor))
        .tint(appViewModel.accentColor)
    }
}

struct ProfilesTab: View {
    @ObservedObject var appViewModel: AppViewModel
    let isAmoledTheme: Bool
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var editingProfile: ScheduleProfile?
    @State private var tempName = ""
    @State private var tempUrl = ""
    @State private var tempDescription = ""
    @State private var tempEmoji = "calendar"
    @State private var tempEmojiColor = Color.blue
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Profiles")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {
                    tempName = ""
                    tempUrl = ""
                    tempDescription = ""
                    tempEmoji = "calendar"
                    tempEmojiColor = .blue
                    showingAddSheet = true
                }) {
                    Label("Add Profile", systemImage: "plus")
                }
            }
            .padding(.bottom)
            
            List {
                ForEach(appViewModel.profiles) { profile in
                    HStack(spacing: 12) {
                        Image(systemName: appViewModel.activeProfileId == profile.id.uuidString ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(appViewModel.activeProfileId == profile.id.uuidString ? appViewModel.accentColor : .secondary)
                            .font(.title3)
                            .onTapGesture {
                                appViewModel.switchToProfile(profile)
                            }
                        
                        // Profile emoji with color
                        ZStack {
                            if let emojiColor = profile.emojiColor {
                                Circle()
                                    .fill(emojiColor.color.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                
                                if profile.emoji.allSatisfy({ $0.isASCII }) {
                                    Image(systemName: profile.emoji)
                                        .font(.system(size: 16))
                                        .foregroundColor(emojiColor.color)
                                } else {
                                    Text(profile.emoji)
                                        .font(.system(size: 20))
                                }
                            } else {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                
                                if profile.emoji.allSatisfy({ $0.isASCII }) {
                                    Image(systemName: profile.emoji)
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                } else {
                                    Text(profile.emoji)
                                        .font(.system(size: 20))
                                }
                            }
                        }
                        .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.headline)
                            Text(profile.description.isEmpty ? profile.icalUrl : profile.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            editingProfile = profile
                            tempName = profile.name
                            tempUrl = profile.icalUrl
                            tempDescription = profile.description
                            tempEmoji = profile.emoji
                            tempEmojiColor = profile.emojiColor?.color ?? .blue
                            showingEditSheet = true
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            appViewModel.deleteProfile(profile)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                            .opacity(0.5)
                    }
                    .padding(8)
                    .background(isAmoledTheme ? Color.gray.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .onMove { source, destination in
                    appViewModel.moveProfile(from: source, to: destination)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            
            if appViewModel.profiles.isEmpty {
                Text("No profiles added. Add one to get started.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .sheet(isPresented: $showingAddSheet) {
            ProfileSheet(title: "Add Profile", name: $tempName, url: $tempUrl, description: $tempDescription, emoji: $tempEmoji, emojiColor: $tempEmojiColor, appViewModel: appViewModel, isAmoledTheme: isAmoledTheme) {
                let profile = ScheduleProfile(name: tempName, icalUrl: tempUrl, description: tempDescription, emoji: tempEmoji, emojiColor: CodableColor(color: tempEmojiColor))
                appViewModel.addProfile(profile)
                showingAddSheet = false
            } onCancel: {
                showingAddSheet = false
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ProfileSheet(title: "Edit Profile", name: $tempName, url: $tempUrl, description: $tempDescription, emoji: $tempEmoji, emojiColor: $tempEmojiColor, appViewModel: appViewModel, isAmoledTheme: isAmoledTheme) {
                if var profile = editingProfile {
                    profile.name = tempName
                    profile.icalUrl = tempUrl
                    profile.description = tempDescription
                    profile.emoji = tempEmoji
                    profile.emojiColor = CodableColor(color: tempEmojiColor)
                    appViewModel.updateProfile(profile)
                }
                showingEditSheet = false
            } onCancel: {
                showingEditSheet = false
            }
        }
    }
}

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
    
    let emojiOptions = [
        // General
        "calendar", "clock.fill", "person.fill", "house.fill", "building.2.fill",
        
        // Academic & Work
        "book.fill", "graduationcap.fill", "pencil", "book.closed.fill", "building.columns.fill",
        "briefcase.fill", "doc.text.fill", "folder.fill", "paperclip", "archivebox.fill",
        "studentdesk", "backpack.fill", "lanyard.card.fill", "printer.fill",
        
        // Science & Tech
        "atom", "flask.fill", "stethoscope", "cross.case.fill", "pills.fill",
        "desktopcomputer", "laptopcomputer", "keyboard.fill", "cpu", "server.rack",
        "display", "printer.fill", "scanner.fill", "faxmachine",
        
        // Tools & Objects
        "alarm.fill", "lightbulb.fill", "hammer.fill", "wrench.and.screwdriver.fill",
        "gearshape.fill", "scissors", "paintbrush.fill", "paintpalette.fill",
        
        // Activities & Sports
        "figure.run", "dumbbell.fill", "tennis.racket", "trophy.fill", "medal.fill",
        "soccerball", "basketball.fill", "baseball.fill", "volleyball.fill", "football.fill",
        "gamecontroller.fill", "music.note", "guitar.fill", "pianokeys", "mic.fill",
        "theatermasks.fill", "party.popper.fill", "film.fill", "ticket.fill",
        
        // Travel & Nature
        "airplane", "car.fill", "bus.fill", "tram.fill", "bicycle",
        "leaf.fill", "sun.max.fill", "cloud.rain.fill", "moon.fill", "flame.fill",
        "drop.fill", "bolt.fill", "snowflake",
        
        // Food & Drink
        "cup.and.saucer.fill", "fork.knife", "takeoutbag.and.cup.and.straw.fill", "wineglass.fill",
        
        // Misc
        "heart.fill", "star.fill", "gift.fill", "cart.fill", "creditcard.fill",
        "tag.fill", "bookmark.fill", "flag.fill", "bell.fill", "target"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(emojiColor.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                if emoji.allSatisfy({ $0.isASCII }) {
                    Image(systemName: emoji)
                        .font(.system(size: 30))
                        .foregroundColor(emojiColor)
                } else {
                    Text(emoji)
                        .font(.system(size: 36))
                }
            }
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Icon")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(emojiOptions, id: \.self) { emojiOption in
                            Button {
                                emoji = emojiOption
                            } label: {
                                ZStack {
                                    if emoji == emojiOption {
                                        Circle()
                                            .fill(appViewModel.accentColor.opacity(0.2))
                                            .frame(width: 40, height: 40)
                                    }
                                    
                                    Image(systemName: emojiOption)
                                        .font(.title2)
                                        .foregroundColor(emoji == emojiOption ? appViewModel.accentColor : .primary)
                                        .frame(width: 40, height: 40)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                HStack {
                    Text("Color:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ColorPicker("", selection: $emojiColor, supportsOpacity: false)
                        .labelsHidden()
                }
            }
            
            TextField("Profile Name", text: $name)
                .textFieldStyle(.roundedBorder)
            
            TextField("Description (Optional)", text: $description)
                .textFieldStyle(.roundedBorder)
            
            TextField("iCal URL", text: $url)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || url.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 450, height: 550)
        .background(isAmoledTheme ? Color.black : Color(nsColor: .windowBackgroundColor))
    }
}

struct TestNotificationButton: View {
    @State private var resultMessage: String = ""
    @State private var showResult: Bool = false
    @State private var isSuccess: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                NotificationManager.shared.sendTestNotification { success, message in
                    isSuccess = success
                    resultMessage = message
                    showResult = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        showResult = false
                    }
                }
            } label: {
                Label("Send Test Notification", systemImage: "bell.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
            if showResult {
                HStack(spacing: 6) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isSuccess ? .green : .orange)
                    Text(resultMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 4)
            }
        }
    }
}

struct PresetColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: isSelected ? 3 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}

struct CustomColorPickerButton: View {
    @ObservedObject var appViewModel: AppViewModel
    
    var body: some View {
        ColorPicker("", selection: Binding(
            get: { appViewModel.accentColor },
            set: { newColor in
                appViewModel.saveAccentColor(newColor)
            }
        ), supportsOpacity: false)
        .labelsHidden()
        .frame(width: 28, height: 28)
        .help("Choose custom color")
    }
}

struct GeneralTab: View {
    @ObservedObject var appViewModel: AppViewModel
    @StateObject var launchAtLoginManager = LaunchAtLoginManager.shared
    
    // Helper function to compare colors
    private func isColorSimilar(_ color1: Color, _ color2: Color) -> Bool {
        guard let nsColor1 = NSColor(color1).usingColorSpace(.deviceRGB),
              let nsColor2 = NSColor(color2).usingColorSpace(.deviceRGB) else {
            return false
        }
        
        let threshold: CGFloat = 0.01
        return abs(nsColor1.redComponent - nsColor2.redComponent) < threshold &&
               abs(nsColor1.greenComponent - nsColor2.greenComponent) < threshold &&
               abs(nsColor1.blueComponent - nsColor2.blueComponent) < threshold
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("General")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)
                    .onAppear {
                        launchAtLoginManager.refreshStatus()
                    }
                
                // Time & Display
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Time & Display", systemImage: "clock.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Divider()
                        
                        Toggle(isOn: $appViewModel.use24HourFormat) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("24-Hour Format")
                                    .font(.body)
                                Text("Display times in 24-hour format")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Calendar Hours")
                                    .font(.body)
                                Text("Set visible hours in week view")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                Picker("Start", selection: $appViewModel.startHour) {
                                    ForEach(0...23, id: \.self) { hour in
                                        Text("\(hour):00").tag(hour)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 70)
                                
                                Text("to")
                                    .foregroundColor(.secondary)
                                
                                Picker("End", selection: $appViewModel.endHour) {
                                    ForEach(0...23, id: \.self) { hour in
                                        Text("\(hour):00").tag(hour)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 70)
                            }
                        }
                    }
                    .padding(12)
                }
                
                // Interface
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Interface", systemImage: "macwindow")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Accent Color")
                                        .font(.body)
                                    Text("Customize button and highlight colors")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 12) {
                                    // Preset colors with selection state
                                    PresetColorButton(color: .blue, isSelected: isColorSimilar(appViewModel.accentColor, .blue)) {
                                        appViewModel.saveAccentColor(.blue)
                                    }
                                    PresetColorButton(color: .purple, isSelected: isColorSimilar(appViewModel.accentColor, .purple)) {
                                        appViewModel.saveAccentColor(.purple)
                                    }
                                    PresetColorButton(color: .pink, isSelected: isColorSimilar(appViewModel.accentColor, .pink)) {
                                        appViewModel.saveAccentColor(.pink)
                                    }
                                    PresetColorButton(color: .red, isSelected: isColorSimilar(appViewModel.accentColor, .red)) {
                                        appViewModel.saveAccentColor(.red)
                                    }
                                    PresetColorButton(color: .orange, isSelected: isColorSimilar(appViewModel.accentColor, .orange)) {
                                        appViewModel.saveAccentColor(.orange)
                                    }
                                    PresetColorButton(color: .green, isSelected: isColorSimilar(appViewModel.accentColor, .green)) {
                                        appViewModel.saveAccentColor(.green)
                                    }
                                    PresetColorButton(color: .teal, isSelected: isColorSimilar(appViewModel.accentColor, .teal)) {
                                        appViewModel.saveAccentColor(.teal)
                                    }
                                    
                                    // Custom color picker with restart prompt
                                    CustomColorPickerButton(appViewModel: appViewModel)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Appearance")
                                        .font(.body)
                                    Text("Choose your preferred theme")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Picker("", selection: $appViewModel.themeMode) {
                                    Label("Auto", systemImage: "circle.lefthalf.filled").tag("auto")
                                    Label("Light", systemImage: "sun.max.fill").tag("light")
                                    Label("Dark", systemImage: "moon.fill").tag("dark")
                                    Label("AMOLED", systemImage: "moon.stars.fill").tag("amoled")
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 300)
                            }
                            
                            if appViewModel.themeMode == "auto" {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Dark Mode Style")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    HStack {
                                        Text("When auto switches to dark:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Picker("", selection: $appViewModel.preferredDarkMode) {
                                            Text("Standard Dark").tag("dark")
                                            Text("AMOLED Black").tag("amoled")
                                        }
                                        .frame(width: 150)
                                    }
                                }
                                .padding(.leading, 4)
                            }
                            
                            if appViewModel.themeMode == "amoled" || (appViewModel.themeMode == "auto" && appViewModel.preferredDarkMode == "amoled") {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("Pure black background for OLED displays")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 4)
                            }
                        }
                    }
                    .padding(12)
                }
                
                // System
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("System", systemImage: "gearshape.2.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Divider()
                        
                        Toggle(isOn: $launchAtLoginManager.isEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Launch at Login")
                                    .font(.body)
                                Text("Automatically start Chronology when you log in")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button("Open Login Items Settings...") {
                            launchAtLoginManager.openLoginItemsSettings()
                        }
                        .font(.caption)
                        .buttonStyle(.link)
                        
                        Divider()
                        
                        Toggle(isOn: $appViewModel.showMenuBarIcon) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show Menu Bar Icon")
                                    .font(.body)
                                Text("Display schedule status in the menu bar")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        Toggle(isOn: $appViewModel.hideFromDock) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hide from Dock")
                                    .font(.body)
                                Text("Run in menu bar only, hide dock icon and window")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disabled(!appViewModel.showMenuBarIcon)
                        
                        if appViewModel.hideFromDock {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Click the menu bar icon to access settings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 20)
                        }
                    }
                    .padding(12)
                }
                
                // Notifications
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Notifications", systemImage: "bell.badge.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Divider()
                        
                        Toggle(isOn: $appViewModel.notificationsEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enable Notifications")
                                    .font(.body)
                                Text("Get notified before events start")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button("Open Notification Settings...") {
                            NotificationManager.shared.openNotificationSettings()
                        }
                        .font(.caption)
                        .buttonStyle(.link)
                        
                        if appViewModel.notificationsEnabled {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Notification Timing")
                                        .font(.body)
                                    Text("When to remind you")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Picker("", selection: $appViewModel.notificationMinutesBefore) {
                                    Text("5 minutes").tag(5)
                                    Text("15 minutes").tag(15)
                                    Text("30 minutes").tag(30)
                                    Text("1 hour").tag(60)
                                }
                                .labelsHidden()
                                .frame(width: 110)
                            }
                            .padding(.leading, 20)
                            
                            Divider()
                            
                            TestNotificationButton()
                        }
                    }
                    .padding(12)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct AboutTab: View {
    @State private var showConfetti = false
    @State private var clickCount = 0
    @State private var lastClickTime = Date()
    @State private var heartScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                if let appIcon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 128, height: 128)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                
                Text("Chronology")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 2.0.0 (Rewrite)")
                    .foregroundColor(.secondary)
                
                Text("A beautiful schedule viewer for TimeEdit.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("Made with")
                    Text("❤️")
                        .foregroundColor(.red)
                        .scaleEffect(heartScale)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                                heartScale = 1.3
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                                    heartScale = 1.0
                                }
                            }
                            handleHeartClick()
                        }
                        .help("Click rapidly for a surprise!")
                    Text("by Surya & AI")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
            }
            .padding()
            
            if showConfetti {
                ConfettiExplosionView()
            }
        }
    }
    
    private func handleHeartClick() {
        let now = Date()
        if now.timeIntervalSince(lastClickTime) < 0.4 {
            clickCount += 1
        } else {
            clickCount = 1
        }
        lastClickTime = now
        
        if clickCount >= 5 {
            triggerConfetti()
            clickCount = 0
        }
    }
    
    private func triggerConfetti() {
        showConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            showConfetti = false
        }
    }
}

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
