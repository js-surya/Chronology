import SwiftUI
import ChronologyCore

enum AppTab: Hashable {
    case agenda, calendar, settings, search
}

/// Tab bar on iPhone; becomes a sidebar on iPad (sidebarAdaptable).
struct MainTabView: View {
    @State private var selection: AppTab = .agenda
    @State private var selectedEvent: Event?
    @Environment(AppStore.self) private var store

    var body: some View {
        TabView(selection: $selection) {
            Tab("Up Next", systemImage: "list.bullet.rectangle.portrait", value: .agenda) {
                AgendaView(selectedEvent: $selectedEvent)
            }
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                CalendarScreen(selectedEvent: $selectedEvent)
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsScreen()
            }
            Tab(value: .search, role: .search) {
                SearchScreen(selectedEvent: $selectedEvent)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
    }
}

// MARK: - Shared toolbar: profile switcher

struct ProfileSwitcher: ToolbarContent {
    @Environment(AppStore.self) private var store

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if store.profiles.count > 1, let active = store.activeProfile {
                Menu {
                    Picker("Profile", selection: Binding(
                        get: { store.activeProfileID ?? active.id },
                        set: { store.activeProfileID = $0 }
                    )) {
                        ForEach(store.profiles) { profile in
                            Label(profile.name, systemImage: profile.emoji).tag(profile.id)
                        }
                    }
                } label: {
                    Label(active.name, systemImage: active.emoji)
                }
                // The profile's own icon color, like the Mac profile badge
                .tint(active.emojiColor?.color ?? store.accentColor)
            }
        }
    }
}
