import SwiftUI
import AppKit
import UserNotifications

@main
struct ChronologyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(appViewModel: appDelegate.appViewModel)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        
        MenuBarExtra(isInserted: .constant(appDelegate.appViewModel.showMenuBarIcon)) {
            MenuBarView()
                .environmentObject(appDelegate.appViewModel)
        } label: {
            HStack(spacing: 2) {
                Text(appDelegate.appViewModel.menuBarText)
                    .font(.system(size: 13, design: .monospaced))
            }
        }
        .menuBarExtraStyle(.window)
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
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    lazy var appViewModel = AppViewModel()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Set legacy notification center delegate
        NSUserNotificationCenter.default.delegate = self
        
        // Ensure initialization happens after app launch
        Task { @MainActor in
            appViewModel.ensureInitialized()
        }
        
        // Listen for reopen window requests
        NotificationCenter.default.addObserver(forName: Notification.Name("openMainWindow"), object: nil, queue: .main) { _ in
            NSApp.activate(ignoringOtherApps: true)
            // Find and show existing window or create new one
            if let window = NSApp.windows.first(where: { $0.title == "Chronology" }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    // Prevent app from terminating when main window is closed (keep menu bar running)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // Force notifications to show as banners even when app is active
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
    
    // Handle window closing - hide dock icon but keep menu bar
    func applicationDidUpdate(_ notification: Notification) {
        // Check if hideFromDock is disabled and no windows are visible
        if !appViewModel.hideFromDock {
            let hasVisibleWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeKey }
            if !hasVisibleWindow {
                // Hide dock icon when window is closed
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    // Handle dock icon click to reopen window
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Restore dock icon and bring window up
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
    
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
