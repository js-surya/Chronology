import SwiftUI
import UserNotifications
import ChronologyCore

@main
struct ChronologyMobileApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = ForegroundNotifications.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { await store.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await store.refreshIfStale() } }
                }
        }
    }
}

/// Show reminders as banners even while the app is open.
final class ForegroundNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotifications()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if store.profiles.isEmpty {
            OnboardingView()
        } else {
            MainTabView()
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @State private var showingEditor = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "calendar.day.timeline.left")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .nonRepeating)

            VStack(spacing: 10) {
                Text("Welcome to Chronology")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Your TimeEdit schedule, with a Next Up countdown, reminders and a Home Screen widget.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                showingEditor = true
            } label: {
                Text("Add Your Schedule")
                    .font(.headline)
                    .frame(maxWidth: 360)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showingEditor) {
            ProfileEditorView(profile: nil)
        }
    }
}
