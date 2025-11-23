import Foundation
import SwiftUI
import Combine

@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var appViewModel: AppViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        self.isLoading = true // Start loading immediately to prevent empty state flash
        
        NotificationCenter.default.publisher(for: .rescheduleNotifications)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.rescheduleNotifications()
                }
            }
            .store(in: &cancellables)
    }
    
    func rescheduleNotifications() {
        guard appViewModel.notificationsEnabled else { return }
        NotificationManager.shared.scheduleNotifications(
            for: events,
            minutesBefore: appViewModel.notificationMinutesBefore
        )
        
        // Also reschedule important event reminders
        NotificationManager.shared.scheduleImportantReminders(
            for: events,
            importantEvents: appViewModel.importantEvents
        )
    }
    
    func loadSchedule() async {
        let urlString = appViewModel.activeProfileUrl
        
        guard !urlString.isEmpty else {
            self.events = []
            self.isLoading = false
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            let fetchedEvents = try await ScheduleService.shared.fetchSchedule(from: urlString)
            self.events = fetchedEvents
            self.isLoading = false
            
            // Schedule notifications if enabled
            if appViewModel.notificationsEnabled {
                NotificationManager.shared.scheduleNotifications(
                    for: fetchedEvents,
                    minutesBefore: appViewModel.notificationMinutesBefore
                )
                
                // Also schedule important event reminders
                NotificationManager.shared.scheduleImportantReminders(
                    for: fetchedEvents,
                    importantEvents: appViewModel.importantEvents
                )
            }
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }
    
    func filteredEvents(searchText: String) -> [Event] {
        if searchText.isEmpty {
            return events
        } else {
            return events.filter { event in
                event.title.localizedCaseInsensitiveContains(searchText) ||
                event.location.localizedCaseInsensitiveContains(searchText) ||
                (event.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
}
