import XCTest
@testable import OrchardDomain

final class AppleProgressTests: XCTestCase {

    func testProgressFractionCalculation() {
        let now = Date()
        let slice1 = AppleSlice(
            id: "1", itemId: "m1", title: "Meal 1", plannedKcal: 500, actualKcal: 500,
            scheduledTime: now, state: .eaten
        )
        let slice2 = AppleSlice(
            id: "2", itemId: "m2", title: "Meal 2", plannedKcal: 500,
            scheduledTime: now.addingTimeInterval(3600), state: .pending
        )
        let slice3 = AppleSlice(
            id: "3", itemId: "m3", title: "Meal 3", plannedKcal: 1000,
            scheduledTime: now.addingTimeInterval(7200), state: .pending
        )

        let progress = AppleProgress(slices: [slice1, slice2, slice3])
        XCTAssertEqual(progress.totalPlannedKcal, 2000)
        XCTAssertEqual(progress.totalEatenKcal, 500)
        XCTAssertEqual(progress.progressFraction, 0.25, accuracy: 0.001)
        XCTAssertFalse(progress.isComplete)
        XCTAssertEqual(progress.remainingKcal, 1500)
        XCTAssertEqual(progress.eatenCount, 1)
        XCTAssertEqual(progress.pendingCount, 2)
        XCTAssertEqual(progress.totalCount, 3)
    }

    func testProgressFraction100PercentCompletion() {
        let now = Date()
        let slice1 = AppleSlice(
            id: "1", itemId: "m1", title: "Meal 1", plannedKcal: 800, actualKcal: 800,
            scheduledTime: now, state: .eaten
        )
        let slice2 = AppleSlice(
            id: "2", itemId: "m2", title: "Meal 2", plannedKcal: 1200, actualKcal: 1400, // surplus eaten
            scheduledTime: now, state: .eaten
        )

        let progress = AppleProgress(slices: [slice1, slice2])
        XCTAssertEqual(progress.totalPlannedKcal, 2000)
        XCTAssertEqual(progress.totalEatenKcal, 2200)
        XCTAssertEqual(progress.progressFraction, 1.0)
        XCTAssertTrue(progress.isComplete)
        XCTAssertEqual(progress.remainingKcal, 0)
        XCTAssertEqual(progress.eatenCount, 2)
    }

    func testZeroPlannedCaloriesEdgeCase() {
        // Edge Case 1: Empty day
        let emptyProgress = AppleProgress(slices: [])
        XCTAssertEqual(emptyProgress.totalPlannedKcal, 0)
        XCTAssertEqual(emptyProgress.totalEatenKcal, 0)
        XCTAssertEqual(emptyProgress.progressFraction, 0.0)
        XCTAssertFalse(emptyProgress.isComplete)

        // Edge Case 2: Meals with 0 planned kcal (e.g. fasting or unmeasured day)
        let now = Date()
        let s1 = AppleSlice(
            id: "1", itemId: "m1", title: "Water fasting meal 1", plannedKcal: 0,
            scheduledTime: now, state: .pending
        )
        let s2 = AppleSlice(
            id: "2", itemId: "m2", title: "Water fasting meal 2", plannedKcal: 0,
            scheduledTime: now, state: .pending
        )

        let p1 = AppleProgress(slices: [s1, s2])
        XCTAssertEqual(p1.totalPlannedKcal, 0)
        XCTAssertEqual(p1.progressFraction, 0.0)
        XCTAssertFalse(p1.isComplete)

        // When 1 of 2 is eaten
        var s1Eaten = s1
        s1Eaten.state = .eaten
        let p2 = AppleProgress(slices: [s1Eaten, s2])
        XCTAssertEqual(p2.progressFraction, 0.5, accuracy: 0.001)
        XCTAssertFalse(p2.isComplete)

        // When all 2 are eaten
        var s2Eaten = s2
        s2Eaten.state = .eaten
        let p3 = AppleProgress(slices: [s1Eaten, s2Eaten])
        XCTAssertEqual(p3.progressFraction, 1.0, accuracy: 0.001)
        XCTAssertTrue(p3.isComplete)
    }

    func testSliceStatesPendingEatenSkippedOverdue() {
        let referenceDate = Date(timeIntervalSince1970: 1700000000) // Fixed point in time

        let pastTime = referenceDate.addingTimeInterval(-3600)  // 1 hour ago
        let futureTime = referenceDate.addingTimeInterval(3600) // 1 hour ahead

        let itemPast = PlanItem(id: "item_past", type: .meal, title: "Breakfast", anchor: .absolute(time: "08:00"), kcal: 400)
        let itemFuture = PlanItem(id: "item_future", type: .meal, title: "Dinner", anchor: .absolute(time: "20:00"), kcal: 600)
        let itemSkipped = PlanItem(id: "item_skip", type: .meal, title: "Snack", anchor: .absolute(time: "16:00"), kcal: 200)
        let itemEaten = PlanItem(id: "item_eaten", type: .meal, title: "Lunch", anchor: .absolute(time: "13:00"), kcal: 500)

        let eventPast = ScheduledEvent(id: "evt.past", itemId: itemPast.id, item: itemPast, date: referenceDate, resolvedTime: pastTime)
        let eventFuture = ScheduledEvent(id: "evt.future", itemId: itemFuture.id, item: itemFuture, date: referenceDate, resolvedTime: futureTime)
        let eventSkipped = ScheduledEvent(id: "evt.skip", itemId: itemSkipped.id, item: itemSkipped, date: referenceDate, resolvedTime: pastTime)
        let eventEaten = ScheduledEvent(id: "evt.eaten", itemId: itemEaten.id, item: itemEaten, date: referenceDate, resolvedTime: pastTime)

        let logSkipped = LogEntry(eventKey: "evt.skip", itemId: itemSkipped.id, status: .skipped, timestamp: pastTime)
        let logEaten = LogEntry(eventKey: "evt.eaten", itemId: itemEaten.id, status: .done, timestamp: pastTime, kcal: 550)

        let progress = AppleProgress.calculate(
            events: [eventPast, eventFuture, eventSkipped, eventEaten],
            logEntries: [logSkipped, logEaten],
            referenceDate: referenceDate,
            overdueGraceMinutes: 0
        )

        XCTAssertEqual(progress.slices.count, 4)

        guard let pastSlice = progress.slices.first(where: { $0.id == "evt.past" }),
              let futureSlice = progress.slices.first(where: { $0.id == "evt.future" }),
              let skippedSlice = progress.slices.first(where: { $0.id == "evt.skip" }),
              let eatenSlice = progress.slices.first(where: { $0.id == "evt.eaten" }) else {
            XCTFail("Missing slices")
            return
        }

        XCTAssertEqual(pastSlice.state, SliceState.overdue)
        XCTAssertEqual(futureSlice.state, SliceState.pending)
        XCTAssertEqual(skippedSlice.state, SliceState.skipped)
        XCTAssertEqual(skippedSlice.actualKcal, 0.0)
        XCTAssertEqual(eatenSlice.state, SliceState.eaten)
        XCTAssertEqual(eatenSlice.actualKcal, 550.0)

        XCTAssertEqual(progress.overdueCount, 1)
        XCTAssertEqual(progress.pendingCount, 1)
        XCTAssertEqual(progress.skippedCount, 1)
        XCTAssertEqual(progress.eatenCount, 1)
        XCTAssertEqual(progress.totalEatenKcal, 550.0)
    }

    func testAttachedSupplementsDoNotSkewMealSlices() {
        let date = Date()
        let meal = PlanItem(id: "lunch", type: .meal, title: "Lunch", anchor: .absolute(time: "13:00"), kcal: 600)
        let supp = PlanItem(id: "creatine", type: .supplement, title: "Creatine", anchor: .withItem(itemId: "lunch"), kcal: nil)

        let evtMeal = ScheduledEvent(id: "evt.lunch", itemId: meal.id, item: meal, date: date, resolvedTime: date, attachedItems: [supp])
        let evtSupp = ScheduledEvent(id: "evt.supp", itemId: supp.id, item: supp, date: date, resolvedTime: date, attachedToItemId: "lunch")

        let progress = AppleProgress.calculate(
            events: [evtMeal, evtSupp],
            logEntries: [],
            referenceDate: date.addingTimeInterval(-60)
        )

        // Only meals should generate slices in the hero apple
        XCTAssertEqual(progress.slices.count, 1)
        XCTAssertEqual(progress.slices[0].id, "evt.lunch")
        XCTAssertEqual(progress.totalPlannedKcal, 600)
    }
}
