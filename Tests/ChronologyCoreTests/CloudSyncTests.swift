import XCTest
@testable import ChronologyCore

/// Two devices share one in-memory "iCloud" but keep their own defaults.
@MainActor
final class CloudSyncTests: XCTestCase {
    private var cloud: InMemorySyncStore!
    private var mac: CloudSync!
    private var phone: CloudSync!
    private let t0 = Date(timeIntervalSince1970: 1_000)

    override func setUp() async throws {
        cloud = InMemorySyncStore()
        mac = CloudSync(store: cloud, defaults: freshDefaults())
        phone = CloudSync(store: cloud, defaults: freshDefaults())
    }

    private func freshDefaults() -> UserDefaults {
        let name = "CloudSyncTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func profile(_ name: String) -> ScheduleProfile {
        ScheduleProfile(name: name, icalUrl: "https://example.com/\(name).ics")
    }

    func testFirstDeviceUploadsItsData() {
        let local = [profile("Spring")]
        XCTAssertNil(mac.reconcile(.profiles, local: local, now: t0, firstMerge: CloudSync.union))
        // The phone has nothing yet, so it adopts the Mac's schedules
        XCTAssertEqual(phone.reconcile(.profiles, local: [ScheduleProfile](), now: t0, firstMerge: CloudSync.union), local)
    }

    func testFirstSyncMergesInsteadOfOverwriting() {
        let spring = profile("Spring"), autumn = profile("Autumn")
        _ = mac.reconcile(.profiles, local: [spring], now: t0, firstMerge: CloudSync.union)
        let merged = phone.reconcile(.profiles, local: [autumn], now: t0.addingTimeInterval(1), firstMerge: CloudSync.union)
        XCTAssertEqual(merged.map { Set($0.map(\.id)) }, Set([spring.id, autumn.id]))
        // ...and the Mac then receives the merged list
        XCTAssertEqual(mac.reconcile(.profiles, local: [spring], firstMerge: CloudSync.union).map { Set($0.map(\.id)) },
                       Set([spring.id, autumn.id]))
    }

    func testNewerRemoteChangeIsApplied() {
        _ = mac.reconcile(.timeFormat, local: true, now: t0, firstMerge: { r, _ in r })
        _ = phone.reconcile(.timeFormat, local: true, now: t0, firstMerge: { r, _ in r })
        phone.push(false, to: .timeFormat, now: t0.addingTimeInterval(10))
        XCTAssertEqual(mac.reconcile(.timeFormat, local: true, firstMerge: { r, _ in r }), false)
    }

    func testAlreadySeenChangeIsNotReapplied() {
        _ = mac.reconcile(.timeFormat, local: true, now: t0, firstMerge: { r, _ in r })
        _ = phone.reconcile(.timeFormat, local: true, now: t0, firstMerge: { r, _ in r })
        phone.push(false, to: .timeFormat, now: t0.addingTimeInterval(10))
        _ = mac.reconcile(.timeFormat, local: true, firstMerge: { r, _ in r })
        // The Mac changed it back locally afterwards; the old remote value must not win again
        XCTAssertNil(mac.reconcile(.timeFormat, local: true, firstMerge: { r, _ in r }))
    }

    func testOwnPushIsNotEchoedBack() {
        _ = mac.reconcile(.notes, local: [EventNote](), now: t0, firstMerge: CloudSync.union)
        let note = EventNote(eventTitle: "Math", eventDate: t0, note: "Bring calculator")
        mac.push([note], to: .notes, now: t0.addingTimeInterval(5))
        XCTAssertNil(mac.reconcile(.notes, local: [note], firstMerge: CloudSync.union))
    }

    func testDictionaryUnionPrefersRemote() {
        let red = CodableColor(red: 1, green: 0, blue: 0), blue = CodableColor(red: 0, green: 0, blue: 1)
        let merged = CloudSync.union(["Math": red], ["Math": blue, "Physics": blue])
        XCTAssertEqual(merged, ["Math": red, "Physics": blue])
    }

    func testResetMakesNextSyncMergeAgain() {
        let spring = profile("Spring"), autumn = profile("Autumn")
        _ = mac.reconcile(.profiles, local: [spring], now: t0, firstMerge: CloudSync.union)
        _ = phone.reconcile(.profiles, local: [spring], now: t0, firstMerge: CloudSync.union)
        phone.resetSeenVersions()
        let merged = phone.reconcile(.profiles, local: [spring, autumn], firstMerge: CloudSync.union)
        XCTAssertEqual(merged.map { Set($0.map(\.id)) }, nil, "local already contains remote, nothing to apply")
        XCTAssertEqual(mac.reconcile(.profiles, local: [spring], firstMerge: CloudSync.union)?.count, 2)
    }
}
