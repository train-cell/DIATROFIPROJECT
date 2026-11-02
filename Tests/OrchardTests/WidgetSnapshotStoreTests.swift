import XCTest
@testable import OrchardDomain
@testable import OrchardServices

final class WidgetSnapshotStoreTests: XCTestCase {

    func testSaveAndLoadWidgetSnapshot() throws {
        let suiteName = "test.orchard.widget.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WidgetSnapshotStore(userDefaults: defaults)

        let testTime = Date(timeIntervalSince1970: 1700000000)
        let snapshot = WidgetTodaySnapshot(
            progressFraction: 0.65,
            eatenKcal: 1300,
            plannedKcal: 2000,
            nextMealId: "pre",
            nextMealTitle: "Pre-workout Meal",
            nextMealTime: testTime,
            balanceNow: -150.0,
            lastUpdated: testTime
        )

        store.save(snapshot: snapshot)

        let loaded = store.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.progressFraction, 0.65)
        XCTAssertEqual(loaded?.eatenKcal, 1300)
        XCTAssertEqual(loaded?.plannedKcal, 2000)
        XCTAssertEqual(loaded?.nextMealId, "pre")
        XCTAssertEqual(loaded?.nextMealTitle, "Pre-workout Meal")
        XCTAssertEqual(loaded?.nextMealTime, testTime)
        XCTAssertEqual(loaded?.balanceNow, -150.0)
    }

    func testLoadReturnsNilWhenNoSnapshotSaved() {
        let suiteName = "test.orchard.widget.empty.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WidgetSnapshotStore(userDefaults: defaults)
        XCTAssertNil(store.load())
    }
}
