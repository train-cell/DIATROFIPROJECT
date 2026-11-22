import XCTest
@testable import OrchardDomain

final class HydrationTests: XCTestCase {

    func testDefaultInitializationTarget3L() {
        let hydration = HydrationDay()
        XCTAssertEqual(hydration.targetMl, 3000.0, "Daily water hydration target must strictly be 3.0 Liters (3000 ml)")
        XCTAssertEqual(hydration.consumedMl, 0.0)
        XCTAssertEqual(hydration.litersTarget, 3.0)
        XCTAssertEqual(hydration.litersConsumed, 0.0)
        XCTAssertEqual(hydration.remainingMl, 3000.0)
        XCTAssertFalse(hydration.isGoalReached)
        XCTAssertEqual(hydration.percentage, 0)
        XCTAssertEqual(hydration.progressFraction, 0.0)
    }

    func testQuickAddWaterIncrements() {
        var hydration = HydrationDay()

        // Add 250ml (glass of water)
        hydration.add(ml: 250)
        XCTAssertEqual(hydration.consumedMl, 250.0)
        XCTAssertEqual(hydration.remainingMl, 2750.0)
        XCTAssertEqual(hydration.percentage, 8) // 250 / 3000 = 8.33% -> 8%

        // Add 500ml (shaker / bottle)
        hydration.add(ml: 500)
        XCTAssertEqual(hydration.consumedMl, 750.0)
        XCTAssertEqual(hydration.remainingMl, 2250.0)
        XCTAssertEqual(hydration.percentage, 25) // 750 / 3000 = 25%

        // Add 1000ml (1 Liter)
        hydration.add(ml: 1000)
        XCTAssertEqual(hydration.consumedMl, 1750.0)
        XCTAssertEqual(hydration.remainingMl, 1250.0)
        XCTAssertEqual(hydration.percentage, 58) // 1750 / 3000 = 58.33% -> 58%

        // Add 500ml HIGH5 Shaker
        hydration.add(ml: 500)
        XCTAssertEqual(hydration.consumedMl, 2250.0)
        XCTAssertEqual(hydration.remainingMl, 750.0)
        XCTAssertEqual(hydration.percentage, 75) // 2250 / 3000 = 75%
    }

    func testGoalAchievedAndClamping() {
        var hydration = HydrationDay(targetMl: 3000.0, consumedMl: 2500.0)
        XCTAssertFalse(hydration.isGoalReached)
        XCTAssertEqual(hydration.remainingMl, 500.0)

        // Reach exactly 3000ml
        hydration.add(ml: 500.0)
        XCTAssertTrue(hydration.isGoalReached)
        XCTAssertEqual(hydration.remainingMl, 0.0)
        XCTAssertEqual(hydration.percentage, 100)
        XCTAssertEqual(hydration.progressFraction, 1.0)

        // Exceed target (e.g. 3500ml)
        hydration.add(ml: 500.0)
        XCTAssertEqual(hydration.consumedMl, 3500.0)
        XCTAssertEqual(hydration.litersConsumed, 3.5)
        XCTAssertTrue(hydration.isGoalReached)
        XCTAssertEqual(hydration.remainingMl, 0.0, "Remaining water should clamp to 0 once target is exceeded")
        XCTAssertEqual(hydration.progressFraction, 1.0, "Progress fraction for UI gauges should be clamped at 1.0")
        XCTAssertEqual(hydration.percentage, 100)
    }

    func testResetHydration() {
        var hydration = HydrationDay(targetMl: 3000.0, consumedMl: 2750.0)
        XCTAssertEqual(hydration.consumedMl, 2750.0)

        hydration.reset()
        XCTAssertEqual(hydration.consumedMl, 0.0)
        XCTAssertEqual(hydration.remainingMl, 3000.0)
        XCTAssertFalse(hydration.isGoalReached)
        XCTAssertEqual(hydration.percentage, 0)
    }

    func testCodableSerialization() throws {
        let original = HydrationDay(date: Date(), targetMl: 3000.0, consumedMl: 2250.0)
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HydrationDay.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.targetMl, 3000.0)
        XCTAssertEqual(decoded.consumedMl, 2250.0)
        XCTAssertEqual(decoded.percentage, original.percentage)
    }
}
