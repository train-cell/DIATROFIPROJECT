import XCTest
@testable import OrchardDomain

final class HydrationTests: XCTestCase {

    func testDefaultInitializationTarget4L() {
        let hydration = HydrationDay()
        XCTAssertEqual(hydration.targetMl, 4000.0, "Daily water hydration target must strictly be 4.0 Liters (4000 ml)")
        XCTAssertEqual(hydration.consumedMl, 0.0)
        XCTAssertEqual(hydration.litersTarget, 4.0)
        XCTAssertEqual(hydration.litersConsumed, 0.0)
        XCTAssertEqual(hydration.remainingMl, 4000.0)
        XCTAssertFalse(hydration.isGoalReached)
        XCTAssertEqual(hydration.percentage, 0)
        XCTAssertEqual(hydration.progressFraction, 0.0)
    }

    func testQuickAddWaterIncrements() {
        var hydration = HydrationDay()

        // Add 250ml (glass of water)
        hydration.add(ml: 250)
        XCTAssertEqual(hydration.consumedMl, 250.0)
        XCTAssertEqual(hydration.remainingMl, 3750.0)
        XCTAssertEqual(hydration.percentage, 6) // 250 / 4000 = 6.25% -> 6%

        // Add 500ml (shaker / bottle)
        hydration.add(ml: 500)
        XCTAssertEqual(hydration.consumedMl, 750.0)
        XCTAssertEqual(hydration.remainingMl, 3250.0)
        XCTAssertEqual(hydration.percentage, 19) // 750 / 4000 = 18.75% -> 19%

        // Add 1000ml (1 Liter)
        hydration.add(ml: 1000)
        XCTAssertEqual(hydration.consumedMl, 1750.0)
        XCTAssertEqual(hydration.remainingMl, 2250.0)
        XCTAssertEqual(hydration.percentage, 44) // 1750 / 4000 = 43.75% -> 44%

        // Add 500ml Bolero
        hydration.add(ml: 500)
        XCTAssertEqual(hydration.consumedMl, 2250.0)
        XCTAssertEqual(hydration.percentage, 56) // 2250 / 4000 = 56.25% -> 56%
    }

    func testGoalAchievedAndClamping() {
        var hydration = HydrationDay(targetMl: 4000.0, consumedMl: 3500.0)
        XCTAssertFalse(hydration.isGoalReached)
        XCTAssertEqual(hydration.remainingMl, 500.0)

        // Reach exactly 4000ml
        hydration.add(ml: 500.0)
        XCTAssertTrue(hydration.isGoalReached)
        XCTAssertEqual(hydration.remainingMl, 0.0)
        XCTAssertEqual(hydration.percentage, 100)
        XCTAssertEqual(hydration.progressFraction, 1.0)

        // Exceed target (e.g. 4500ml)
        hydration.add(ml: 500.0)
        XCTAssertEqual(hydration.consumedMl, 4500.0)
        XCTAssertEqual(hydration.litersConsumed, 4.5)
        XCTAssertTrue(hydration.isGoalReached)
        XCTAssertEqual(hydration.remainingMl, 0.0, "Remaining water should clamp to 0 once target is exceeded")
        XCTAssertEqual(hydration.progressFraction, 1.0, "Progress fraction for UI gauges should be clamped at 1.0")
        XCTAssertEqual(hydration.percentage, 100)
    }

    func testResetHydration() {
        var hydration = HydrationDay(targetMl: 4000.0, consumedMl: 2750.0)
        XCTAssertEqual(hydration.consumedMl, 2750.0)

        hydration.reset()
        XCTAssertEqual(hydration.consumedMl, 0.0)
        XCTAssertEqual(hydration.remainingMl, 4000.0)
        XCTAssertFalse(hydration.isGoalReached)
        XCTAssertEqual(hydration.percentage, 0)
    }

    func testCodableSerialization() throws {
        let original = HydrationDay(date: Date(), targetMl: 4000.0, consumedMl: 2250.0)
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HydrationDay.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.targetMl, 4000.0)
        XCTAssertEqual(decoded.consumedMl, 2250.0)
        XCTAssertEqual(decoded.percentage, original.percentage)
    }
}
