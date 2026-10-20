import Foundation

/// Small key-value storage shared across the user's devices.
@MainActor
public protocol KeyValueSyncStore: AnyObject {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data, forKey key: String)
    func synchronize()
    /// Posted when another device changed a value; nil when the store never changes remotely.
    var externalChangeNotification: Notification.Name? { get }
}

/// iCloud key-value storage. Works only in builds signed with the iCloud capability;
/// otherwise values simply stay on this device.
@MainActor
public final class UbiquitousSyncStore: KeyValueSyncStore {
    private let store = NSUbiquitousKeyValueStore.default
    public init() {}
    public func data(forKey key: String) -> Data? { store.data(forKey: key) }
    public func setData(_ data: Data, forKey key: String) { store.set(data, forKey: key) }
    public func synchronize() { store.synchronize() }
    public var externalChangeNotification: Notification.Name? { NSUbiquitousKeyValueStore.didChangeExternallyNotification }

    /// Whether this device is signed in to iCloud.
    public static var isAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }
}

/// For tests and previews. Several `CloudSync` instances can share one to act as separate devices.
@MainActor
public final class InMemorySyncStore: KeyValueSyncStore {
    private var values: [String: Data] = [:]
    public init() {}
    public func data(forKey key: String) -> Data? { values[key] }
    public func setData(_ data: Data, forKey key: String) { values[key] = data }
    public func synchronize() {}
    public var externalChangeNotification: Notification.Name? { nil }
}

/// What syncs between the Mac and iOS apps. Device-specific settings (theme, haptics,
/// notifications, Live Activity) stay local.
public enum SyncSection: String, CaseIterable, Sendable {
    case profiles, courseColors, notes, importantEvents, timeFormat

    var key: String { "sync.\(rawValue).v1" }
}

/// Per-section last-writer-wins sync over a key-value store.
///
/// Each section is stored with the time it was changed; a device applies a remote value only
/// when it is newer than the last one it saw. The first sync on a device merges instead of
/// overwriting, so turning sync on never drops schedules made before.
@MainActor
public final class CloudSync {
    private struct Stamped<T: Codable>: Codable {
        let value: T
        let modifiedAt: Date
    }

    private let store: any KeyValueSyncStore
    private let defaults: UserDefaults
    private var observer: NSObjectProtocol?

    /// `defaults` remembers which remote versions this device has seen.
    public init(store: any KeyValueSyncStore, defaults: UserDefaults) {
        self.store = store
        self.defaults = defaults
    }

    /// Calls `onRemoteChange` whenever another device saves.
    public func start(onRemoteChange: @escaping @MainActor () -> Void) {
        guard observer == nil else { return }
        if let name = store.externalChangeNotification {
            observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { onRemoteChange() }
            }
        }
        store.synchronize()
    }

    /// Publishes a local change.
    public func push<T: Codable>(_ value: T, to section: SyncSection, now: Date = Date()) {
        write(value, section: section, at: now)
    }

    /// Reconciles one section. Returns a value to apply locally, or nil when nothing changed.
    /// `firstMerge(remote, local)` runs only on this device's first sync of the section.
    public func reconcile<T: Codable & Equatable>(_ section: SyncSection, local: T, now: Date = Date(),
                                                   firstMerge: (T, T) -> T) -> T? {
        guard let remote = read(T.self, section: section) else {
            write(local, section: section, at: now)
            return nil
        }
        guard let seen = lastSeen(section) else {
            let merged = firstMerge(remote.value, local)
            write(merged, section: section, at: now)
            return merged == local ? nil : merged
        }
        guard remote.modifiedAt > seen else { return nil }
        setLastSeen(remote.modifiedAt, for: section)
        return remote.value == local ? nil : remote.value
    }

    /// Forgets which versions were seen, so the next reconcile merges again (sync turned back on).
    public func resetSeenVersions() {
        for section in SyncSection.allCases {
            defaults.removeObject(forKey: seenKey(section))
        }
    }

    // MARK: - Merges for the first sync

    /// Remote items plus local ones it doesn't have, matched by `id`.
    public static func union<T: Identifiable>(_ remote: [T], _ local: [T]) -> [T] {
        let ids = Set(remote.map(\.id))
        return remote + local.filter { !ids.contains($0.id) }
    }

    /// Remote entries win; local-only keys are kept.
    public static func union<V>(_ remote: [String: V], _ local: [String: V]) -> [String: V] {
        remote.merging(local) { remoteValue, _ in remoteValue }
    }

    // MARK: - Storage

    private func read<T: Codable>(_ type: T.Type, section: SyncSection) -> Stamped<T>? {
        store.data(forKey: section.key).flatMap { try? JSONDecoder().decode(Stamped<T>.self, from: $0) }
    }

    private func write<T: Codable>(_ value: T, section: SyncSection, at date: Date) {
        guard let data = try? JSONEncoder().encode(Stamped(value: value, modifiedAt: date)) else { return }
        store.setData(data, forKey: section.key)
        setLastSeen(date, for: section)
    }

    private func seenKey(_ section: SyncSection) -> String { "cloudSync.seen.\(section.rawValue)" }

    private func lastSeen(_ section: SyncSection) -> Date? {
        defaults.object(forKey: seenKey(section)) as? Date
    }

    private func setLastSeen(_ date: Date, for section: SyncSection) {
        defaults.set(date, forKey: seenKey(section))
    }
}
