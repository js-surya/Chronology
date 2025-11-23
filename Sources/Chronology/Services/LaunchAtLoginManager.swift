import Foundation
import ServiceManagement
import AppKit

class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()
    
    @Published var isEnabled: Bool {
        didSet {
            if oldValue != isEnabled {
                updateLoginItem()
            }
        }
    }
    
    private init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    func refreshStatus() {
        let currentStatus = SMAppService.mainApp.status == .enabled
        if isEnabled != currentStatus {
            DispatchQueue.main.async {
                self.isEnabled = currentStatus
            }
        }
    }
    
    private func updateLoginItem() {
        do {
            if isEnabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Failed to update login item: \(error)")
            // Revert state if failed
            DispatchQueue.main.async {
                self.isEnabled = SMAppService.mainApp.status == .enabled
            }
        }
    }
    
    func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback to general settings if specific URL fails
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
        }
    }
}
