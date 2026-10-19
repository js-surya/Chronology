import SwiftUI
import ChronologyCore

/// Search tab (iOS 26 floats it beside the tab bar).
struct SearchScreen: View {
    @Binding var selectedEvent: Event?
    @Environment(AppStore.self) private var store
    @State private var query = ""

    private var results: [Event] {
        let upcoming = store.upcoming()
        guard !query.isEmpty else { return Array(upcoming.prefix(30)) }
        return upcoming.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.location.localizedCaseInsensitiveContains(query)
                || ($0.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List(results) { event in
                Button { selectedEvent = event } label: {
                    EventRow(event: event, showsDate: true)
                }
                .tint(.primary)
            }
            .overlay {
                if !query.isEmpty && results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Search")
            // Always visible under the title; the tab-bar search field didn't appear reliably
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Courses, rooms, teachers")
        }
    }
}
