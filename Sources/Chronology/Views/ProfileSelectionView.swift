import SwiftUI

struct ProfileSelectionView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.colorScheme) var systemColorScheme
    @State private var showingAddProfile = false
    @State private var tempName = ""
    @State private var tempUrl = ""
    @State private var tempDescription = ""
    
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
        HStack(spacing: 0) {
            // Left panel - Branding and Actions
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    if let appIcon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    } else {
                        Image(systemName: "calendar.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(appViewModel.accentColor)
                    }
                    
                    Text("Chronology")
                        .font(.system(size: 36, weight: .bold))
                    
                    Text("Schedule Viewer")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 60)
                
                VStack(spacing: 16) {
                    Button {
                        tempName = ""
                        tempUrl = ""
                        tempDescription = ""
                        showingAddProfile = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Create New Profile")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    if !appViewModel.profiles.isEmpty {
                        Text("or")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Choose an Existing Profile →")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: 280)
                
                Spacer()
            }
            .frame(width: 400)
            .background(isAmoledTheme ? Color.black : Color(nsColor: .controlBackgroundColor))
            
            // Right panel - Recent Profiles
            VStack(alignment: .leading, spacing: 0) {
                if !appViewModel.profiles.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Profiles")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 40)
                            .padding(.top, 40)
                        
                        List {
                            ForEach(appViewModel.profiles) { profile in
                                ProfileRow(
                                    profile: profile,
                                    isActive: appViewModel.activeProfileId == profile.id.uuidString,
                                    action: {
                                        appViewModel.switchToProfile(profile)
                                    },
                                    appViewModel: appViewModel
                                )
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            }
                            .onMove { source, destination in
                                appViewModel.moveProfile(from: source, to: destination)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                } else {
                    VStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Profiles Yet")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Create your first profile to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isAmoledTheme ? Color.black : Color(nsColor: .windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isAmoledTheme ? Color.black : Color.clear)
        .sheet(isPresented: $showingAddProfile) {
            AddProfileSheet(name: $tempName, url: $tempUrl, description: $tempDescription, appViewModel: appViewModel) { emoji, emojiColor in
                print("DEBUG: Add Profile button clicked")
                print("DEBUG: Name: \(tempName), URL: \(tempUrl)")
                print("DEBUG: Emoji: \(emoji), Color: \(emojiColor)")
                
                let profile = ScheduleProfile(
                    name: tempName,
                    icalUrl: tempUrl,
                    description: tempDescription,
                    emoji: emoji,
                    emojiColor: CodableColor(color: emojiColor)
                )
                print("DEBUG: Profile created: \(profile.name)")
                appViewModel.addProfile(profile)
                print("DEBUG: Profile added to viewmodel")
                appViewModel.switchToProfile(profile)
                print("DEBUG: Switched to profile")
                showingAddProfile = false
            } onCancel: {
                print("DEBUG: Cancel clicked")
                showingAddProfile = false
            }
        }
    }
}

struct ProfileRow: View {
    let profile: ScheduleProfile
    let isActive: Bool
    let action: () -> Void
    @ObservedObject var appViewModel: AppViewModel
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Emoji icon with optional color background
            ZStack {
                if let emojiColor = profile.emojiColor {
                    Circle()
                        .fill(emojiColor.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    if profile.emoji.allSatisfy({ $0.isASCII }) {
                        Image(systemName: profile.emoji)
                            .font(.system(size: 20))
                            .foregroundColor(emojiColor.color)
                    } else {
                        Text(profile.emoji)
                            .font(.system(size: 24))
                    }
                } else {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    if profile.emoji.allSatisfy({ $0.isASCII }) {
                        Image(systemName: profile.emoji)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    } else {
                        Text(profile.emoji)
                            .font(.system(size: 24))
                    }
                }
            }
            .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(profile.description.isEmpty ? extractDomain(from: profile.icalUrl) : profile.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(appViewModel.accentColor)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(isHovering ? 1 : 0.5)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .background(isHovering ? appViewModel.accentColor.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            print("DEBUG: ProfileRow clicked for profile: \(profile.name), ID: \(profile.id.uuidString)")
            action()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private func extractDomain(from url: String) -> String {
        if let urlObj = URL(string: url), let host = urlObj.host {
            return host
        }
        return "TimeEdit Schedule"
    }
}

struct AddProfileSheet: View {
    @Environment(\.colorScheme) var systemColorScheme
    @Binding var name: String
    @Binding var url: String
    @Binding var description: String
    @State var emoji: String = "calendar"
    @State var emojiColor: Color = .blue
    @State var showColorPicker: Bool = false
    @ObservedObject var appViewModel: AppViewModel
    let onSave: (String, Color) -> Void
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
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(emojiColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    if emoji.allSatisfy({ $0.isASCII }) {
                        Image(systemName: emoji)
                            .font(.system(size: 40))
                            .foregroundColor(emojiColor)
                    } else {
                        Text(emoji)
                            .font(.system(size: 48))
                    }
                }
                
                Text("Add New Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Connect your TimeEdit schedule")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Profile Icon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
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
                                                .frame(width: 44, height: 44)
                                        }
                                        
                                        Image(systemName: emojiOption)
                                            .font(.title2)
                                            .foregroundColor(emoji == emojiOption ? appViewModel.accentColor : .primary)
                                            .frame(width: 44, height: 44)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Icon Color:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ColorPicker("", selection: $emojiColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Profile Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    TextField("e.g., My Schedule", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description (Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    TextField("e.g., Fall Semester 2025", text: $description)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("iCal URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    TextField("https://...", text: $url)
                        .textFieldStyle(.roundedBorder)
                    Text("Paste your TimeEdit iCal subscription URL")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    print("DEBUG: Cancel button tapped")
                    onCancel()
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    print("DEBUG: Add Profile button tapped in AddProfileSheet")
                    print("DEBUG: Name is empty: \(name.isEmpty), URL is empty: \(url.isEmpty)")
                    print("DEBUG: Name: '\(name)', URL: '\(url)'")
                    print("DEBUG: Emoji: '\(emoji)', Color: \(emojiColor)")
                    onSave(emoji, emojiColor)
                } label: {
                    Text("Add Profile")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || url.isEmpty)
            }
        }
        .padding(32)
        .frame(width: 500, height: 650)
        .background(isAmoledTheme ? Color.black : Color(nsColor: .windowBackgroundColor))
    }
}
