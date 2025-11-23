import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var hasShownProfileSelection = false
    @Environment(\.colorScheme) var systemColorScheme
    @State private var scheduleViewModel: ScheduleViewModel?
    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var isReady = false
    @State private var currentDayIcon = "\(Calendar.current.component(.day, from: Date())).square"
    
    var body: some View {
        Group {
            if !isReady {
                ProgressView("Starting Chronology...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appViewModel.profiles.isEmpty || appViewModel.activeProfileId.isEmpty {
                // Show profile selection when no profiles exist or no active profile
                ProfileSelectionView()
                    .environmentObject(appViewModel)
            } else if let vm = scheduleViewModel {
                ScheduleContainerView(vm: vm, searchText: searchText)
            } else {
                EmptyStateView(showingSettings: $showingSettings)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // View mode switcher
                if isReady {
                    Picker("View", selection: $appViewModel.viewMode) {
                        Label("Week", systemImage: "calendar").tag("week")
                        Label("Day", systemImage: currentDayIcon).tag("day")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .help("Switch View Mode")
                }
                
                // Profile switcher - Go back to welcome screen
                if isReady && !appViewModel.activeProfileId.isEmpty {
                    Button {
                        // Clear active profile to show welcome screen
                        scheduleViewModel = nil
                        appViewModel.activeProfileId = ""
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .help("Change Profile")
                }
                
                // Refresh button
                Button {
                    if let vm = scheduleViewModel {
                        Task { await vm.loadSchedule() }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(scheduleViewModel == nil)
                .help("Refresh Schedule")
                
                // Settings button
                Button {
                    showingSettings.toggle()
                } label: {
                    Image(systemName: "gear")
                }
                .help("Settings")
            }
        }
        .searchable(text: $searchText, prompt: "Search events...")
        .preferredColorScheme(colorScheme(for: appViewModel.themeMode))
        .background(isAmoledTheme ? Color.black : Color.clear)
        .amoledToolbar(enabled: isAmoledTheme)
        .sheet(isPresented: $showingSettings) {
            SettingsView(isPresented: $showingSettings)
                .environmentObject(appViewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showingSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            currentDayIcon = "\(Calendar.current.component(.day, from: Date())).square"
        }
        .task {
            // Initialize everything here - after view is ready
            appViewModel.ensureInitialized()
            
            // Don't clear active profile - let menu bar work independently
            // User can manually change profile via toolbar button
            
            isReady = true
            
            // Initialize scheduleViewModel if there's an active profile
            if !appViewModel.activeProfileId.isEmpty {
                print("DEBUG: Initial load - Creating ScheduleViewModel for profile: \(appViewModel.activeProfileId)")
                print("DEBUG: Active profile URL: \(appViewModel.activeProfileUrl)")
                let vm = ScheduleViewModel(appViewModel: appViewModel)
                scheduleViewModel = vm
                Task {
                    print("DEBUG: Loading schedule...")
                    await vm.loadSchedule()
                    print("DEBUG: Schedule loaded. Events count: \(vm.events.count)")
                }
            }
        }
        .onChange(of: appViewModel.activeProfileId) { oldId, newId in
            print("DEBUG: Profile changed from '\(oldId)' to '\(newId)'")
            // Recreate scheduleViewModel when profile changes
            if !newId.isEmpty {
                print("DEBUG: Creating new ScheduleViewModel for profile: \(newId)")
                print("DEBUG: Active profile URL: \(appViewModel.activeProfileUrl)")
                let vm = ScheduleViewModel(appViewModel: appViewModel)
                scheduleViewModel = vm
                Task {
                    print("DEBUG: Loading schedule...")
                    await vm.loadSchedule()
                    print("DEBUG: Schedule loaded. Events count: \(vm.events.count)")
                }
            } else {
                print("DEBUG: Clearing scheduleViewModel")
                scheduleViewModel = nil
            }
        }
    }
    
    private func colorScheme(for mode: String) -> ColorScheme? {
        switch mode {
        case "light":
            return .light
        case "dark", "amoled":
            return .dark
        default:
            return nil // Auto - follows system
        }
    }
    
    private var isAmoledTheme: Bool {
        if appViewModel.themeMode == "amoled" {
            return true
        }
        // In auto mode, check if system is dark and user prefers AMOLED
        if appViewModel.themeMode == "auto" && appViewModel.preferredDarkMode == "amoled" {
            return systemColorScheme == .dark
        }
        return false
    }
}

struct ScheduleContainerView: View {
    @ObservedObject var vm: ScheduleViewModel
    let searchText: String
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        if vm.isLoading {
            ProgressView("Loading schedule...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text(error)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Retry") {
                    Task { await vm.loadSchedule() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.events.isEmpty && !vm.isLoading {
            // Check if URL is empty
            if appViewModel.activeProfileUrl.isEmpty {
                // This case should ideally be handled by parent, but safe fallback
                Text("No URL configured")
            } else {
                // URL exists but no events - might be loading or empty schedule
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Events")
                        .font(.title2)
                    Text("Your schedule is empty or no events found")
                        .foregroundColor(.secondary)
                    Button("Refresh") {
                        Task { await vm.loadSchedule() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            if appViewModel.viewMode == "day" {
                DayView(events: vm.filteredEvents(searchText: searchText))
                    .environmentObject(appViewModel)
            } else {
                WeekGridView(events: vm.filteredEvents(searchText: searchText))
                    .environmentObject(appViewModel)
            }
        }
    }
}

struct EmptyStateView: View {
    @Binding var showingSettings: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Schedule Configured")
                .font(.title)
            
            Text("Add your TimeEdit iCal URL in settings to get started")
                .foregroundColor(.secondary)
            
            Button("Open Settings") {
                showingSettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    @ViewBuilder
    func amoledToolbar(enabled: Bool) -> some View {
        if enabled {
            self.toolbarBackground(Color.black, for: .windowToolbar)
        } else {
            self
        }
    }
}
