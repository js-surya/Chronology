import SwiftUI
import AppKit
import UserNotifications

@main
struct ChronologyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    
    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(appViewModel: appDelegate.appViewModel)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appDelegate.appViewModel.showingSettings = true
                    NotificationCenter.default.post(name: .openMainWindow, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandGroup(before: .toolbar) {
                Button("Day") { appDelegate.appViewModel.viewMode = "day" }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Week") { appDelegate.appViewModel.viewMode = "week" }
                    .keyboardShortcut("2", modifiers: .command)
                Divider()
            }
        }
        
        // The App body doesn't observe appViewModel, so the toggle is read from
        // the App's own @AppStorage and the label observes the view model itself
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarView()
                .environmentObject(appDelegate.appViewModel)
        } label: {
            MenuBarLabel(appViewModel: appDelegate.appViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var appViewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Text(appViewModel.menuBarText)
            .font(.system(size: 13, design: .monospaced))
            // Lives as long as the status item, so it can recreate the main window after
            // it was closed (AppDelegate only brings an existing window forward)
            .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
                if !NSApp.windows.contains(where: { $0.canBecomeMain && $0.title == "Chronology" }) {
                    openWindow(id: "main")
                }
            }
    }
}

struct RootView: View {
    @ObservedObject var appViewModel: AppViewModel
    
    var body: some View {
        ContentView()
            .environmentObject(appViewModel)
            .tint(appViewModel.accentColor)
            .frame(minWidth: 1000, minHeight: 700)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var appViewModel = AppViewModel()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set notification delegate (UNUserNotificationCenter traps without a bundle, e.g. `swift run`)
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        }
        
        // Ensure initialization happens after app launch
        Task { @MainActor in
            appViewModel.ensureInitialized()
        }
        
        // Listen for reopen window requests
        NotificationCenter.default.addObserver(forName: .openMainWindow, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if self?.appViewModel.hideFromDock == false {
                    NSApp.setActivationPolicy(.regular)
                }
                NSApp.activate(ignoringOtherApps: true)
                // Find and show existing window or create new one
                if let window = NSApp.windows.first(where: { $0.title == "Chronology" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
        
        // Hide dock icon once the last main window closes (menu bar keeps running)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] note in
            guard let closing = note.object as? NSWindow, closing.canBecomeMain else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, !self.appViewModel.hideFromDock else { return }
                    let hasMainWindow = NSApp.windows.contains { $0 !== closing && $0.isVisible && $0.canBecomeMain }
                    if !hasMainWindow {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
            }
        }
    }
    
    // Prevent app from terminating when main window is closed (keep menu bar running)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // Handle dock icon click to reopen window
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Restore dock icon and bring the window up (recreated if it was closed)
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
        }
        return true
    }
    
}

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}
