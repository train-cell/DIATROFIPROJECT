import XCTest
#if canImport(OrchardDomain)
@testable import OrchardDomain
#endif
#if canImport(OrchardServices)
@testable import OrchardServices
#endif

final class CalorieEngineTests: XCTestCase {

    // MARK: - 1. Sign Convention (+ = Surplus, - = Deficit)

    func testSurplusDeficitSignConvention() {
        // Balance Now: consumed - outSoFar
        // Surplus: consumed > outSoFar -> positive (+)
        let surplusNow = CalorieEngine.balanceNow(consumed: 2500, outSoFar: 2000)
        XCTAssertEqual(surplusNow, 500.0, "Consumed > outSoFar must be positive (surplus)")
        XCTAssertGreaterThan(surplusNow, 0)

        // Deficit: consumed < outSoFar -> negative (-)
        let deficitNow = CalorieEngine.balanceNow(consumed: 1600, outSoFar: 2100)
        XCTAssertEqual(deficitNow, -500.0, "Consumed < outSoFar must be negative (deficit)")
        XCTAssertLessThan(deficitNow, 0)

        // Even: consumed == outSoFar -> zero
        let evenNow = CalorieEngine.balanceNow(consumed: 2000, outSoFar: 2000)
        XCTAssertEqual(evenNow, 0.0)

        // Projected Balance: plannedDay - projectedOut
        // Surplus: plannedDay > projectedOut -> positive (+)
        let projectedSurplus = CalorieEngine.projectedBalance(plannedDay: 2800, projectedOut: 2400)
        XCTAssertEqual(projectedSurplus, 400.0, "PlannedDay > projectedOut must be positive (surplus)")
        XCTAssertGreaterThan(projectedSurplus, 0)

        // Deficit: plannedDay < projectedOut -> negative (-)
        let projectedDeficit = CalorieEngine.projectedBalance(plannedDay: 2000, projectedOut: 2500)
        XCTAssertEqual(projectedDeficit, -500.0, "PlannedDay < projectedOut must be negative (deficit)")
        XCTAssertLessThan(projectedDeficit, 0)
    }

    // MARK: - 2. Consumed Calories & Macros (Done, Partial, Skipped, Swapped)

    func testConsumedKcalStatuses() {
        let baseKcal = 600.0
        let entryDone = LogEntry(eventKey: "e1", itemId: "i1", status: .done, kcal: nil)
        let entryDoneWithExplicitKcal = LogEntry(eventKey: "e2", itemId: "i2", status: .done, kcal: 650.0)
        let entryPartialHalf = LogEntry(eventKey: "e3", itemId: "i3", status: .partial(fraction: 0.5), kcal: baseKcal)
        let entryPartialQuarter = LogEntry(eventKey: "e4", itemId: "i4", status: .partial(fraction: 0.25), kcal: baseKcal)
        let entryPartialZero = LogEntry(eventKey: "e5", itemId: "i5", status: .partial(fraction: 0.0), kcal: baseKcal)
        let entrySkipped = LogEntry(eventKey: "e6", itemId: "i6", status: .skipped, kcal: baseKcal)
        let entrySwapped = LogEntry(eventKey: "e7", itemId: "i7", status: .swapped, kcal: 450.0)

        // .done = 100%
        XCTAssertEqual(CalorieEngine.consumedKcal(for: entryDone, baseKcal: baseKcal), 600.0)
        XCTAssertEqual(CalorieEngine.consumedKcal(for: entryDoneWithExplicitKcal, baseKcal: baseKcal), 650.0)

        // .partial = fraction
        XCTAssertEqual(CalorieEngine.consumedKcal(for: entryPartialHalf, baseKcal: baseKcal), 300.0)
        XCTAssertEqual(CalorieEngine.consumedKcal(for: entryPartialQuarter, baseKcal: baseKcal), 150.0)
        XCTAssertEqual(CalorieEngine.consumedKcal(for: entryPartialZero, baseKcal: baseKcal), 0.0)

        // .skipped = 0
        XCTAssertEqual(CalorieEngine.consumedKcal(for: entrySkipped, baseKcal: baseKcal), 0.0, "Skipped meals must contribute 0 kcal")

        // .swapped = actual
        XCTAssertEqual(CalorieEngine.consumedKcal(for: entrySwapped, baseKcal: baseKcal), 450.0)
    }

    func testConsumedMacrosCalculation() {
        let item = PlanItem(
            id: "meal_lunch",
            type: .meal,
            title: "Chicken & Rice",
            anchor: .absolute(time: "13:00"),
            kcal: 600,
            protein: 50,
            carbs: 60,
            fat: 15
        )

        // Partial 50%
        let partialEntry = LogEntry(eventKey: "e1", itemId: item.id, status: .partial(fraction: 0.5), timestamp: Date())
        let partialMacros = CalorieEngine.consumedMacros(for: partialEntry, baseItem: item)
        XCTAssertEqual(partialMacros.kcal, 300.0, accuracy: 0.01)
        XCTAssertEqual(partialMacros.protein, 25.0, accuracy: 0.01)
        XCTAssertEqual(partialMacros.carbs, 30.0, accuracy: 0.01)
        XCTAssertEqual(partialMacros.fat, 7.5, accuracy: 0.01)

        // Skipped
        let skippedEntry = LogEntry(eventKey: "e2", itemId: item.id, status: .skipped, timestamp: Date())
        let skippedMacros = CalorieEngine.consumedMacros(for: skippedEntry, baseItem: item)
        XCTAssertEqual(skippedMacros.kcal, 0.0)
        XCTAssertEqual(skippedMacros.protein, 0.0)
        XCTAssertEqual(skippedMacros.carbs, 0.0)
        XCTAssertEqual(skippedMacros.fat, 0.0)
    }

    func testConsumedKcalSumAcrossMultipleEntries() {
        let itemMap: [String: PlanItem] = [
            "breakfast": PlanItem(id: "breakfast", type: .meal, title: "Breakfast", anchor: .absolute(time: "08:00"), kcal: 400),
            "lunch": PlanItem(id: "lunch", type: .meal, title: "Lunch", anchor: .absolute(time: "13:00"), kcal: 700),
            "snack": PlanItem(id: "snack", type: .meal, title: "Snack", anchor: .absolute(time: "17:00"), kcal: 300),
            "dinner": PlanItem(id: "dinner", type: .meal, title: "Dinner", anchor: .absolute(time: "20:30"), kcal: 600)
        ]

        let entries: [LogEntry] = [
            LogEntry(eventKey: "e_b", itemId: "breakfast", status: .done),                    // 400
            LogEntry(eventKey: "e_l", itemId: "lunch", status: .partial(fraction: 0.5)),      // 350
            LogEntry(eventKey: "e_s", itemId: "snack", status: .skipped),                    // 0
            LogEntry(eventKey: "e_d", itemId: "dinner", status: .swapped, kcal: 500)         // 500
        ]

        let totalConsumed = CalorieEngine.consumedKcal(entries: entries, items: itemMap)
        XCTAssertEqual(totalConsumed, 1250.0) // 400 + 350 + 0 + 500
    }

    // MARK: - 3. Planned Day & Planned To Now

    func testPlannedDayAndPlannedToNowKcal() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 14, minute: 0))!
        let tMorning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 8, minute: 0))!
        let tNoon = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 13, minute: 0))!
        let tEvening = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 18, minute: 0))!
        let tLate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 21, minute: 0))!

        let item1 = PlanItem(id: "i1", type: .meal, title: "Breakfast", anchor: .absolute(time: "08:00"), kcal: 450)
        let item2 = PlanItem(id: "i2", type: .meal, title: "Lunch", anchor: .absolute(time: "13:00"), kcal: 650)
        let item3 = PlanItem(id: "i3", type: .meal, title: "Pre-Workout Snack", anchor: .absolute(time: "18:00"), kcal: 300)
        let item4 = PlanItem(id: "i4", type: .meal, title: "Dinner", anchor: .absolute(time: "21:00"), kcal: 500)

        let events: [ScheduledEvent] = [
            ScheduledEvent(id: "e1", itemId: item1.id, item: item1, date: tMorning, resolvedTime: tMorning),
            ScheduledEvent(id: "e2", itemId: item2.id, item: item2, date: tNoon, resolvedTime: tNoon),
            ScheduledEvent(id: "e3", itemId: item3.id, item: item3, date: tEvening, resolvedTime: tEvening),
            ScheduledEvent(id: "e4", itemId: item4.id, item: item4, date: tLate, resolvedTime: tLate)
        ]

        let plannedDay = CalorieEngine.plannedDayKcal(events: events)
        XCTAssertEqual(plannedDay, 1900.0, "Total planned calories for the day should be 450 + 650 + 300 + 500 = 1900")

        // At 14:00, breakfast (08:00) and lunch (13:00) have passed; snack (18:00) and dinner (21:00) are future
        let plannedToNow = CalorieEngine.plannedToNowKcal(events: events, now: now)
        XCTAssertEqual(plannedToNow, 1100.0, "Planned to 14:00 should be 450 + 650 = 1100")
    }

    // MARK: - 4. Edge Cases: Zero Burn, Missing Basal, Midnight/Start of Day

    func testZeroBurnEdgeCase() {
        let out = CalorieEngine.outSoFar(basalBurned: 0.0, activeBurned: 0.0)
        XCTAssertEqual(out, 0.0)

        let balance = CalorieEngine.balanceNow(consumed: 500.0, outSoFar: out)
        XCTAssertEqual(balance, 500.0)
    }

    func testProratedBasalAtMidnightDoesNotCrashOrDivideByZero() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Midnight exactly
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 0, minute: 0, second: 0))!

        // Zero basal, zero elapsed
        let remainingBasal = CalorieEngine.proratedRemainingBasal(
            now: midnight,
            dailyBasal: nil,
            basalSoFar: 0.0,
            calendar: calendar
        )
        XCTAssertEqual(remainingBasal, 0.0, "At midnight with no basal, remaining basal should safely be 0.0")

        // With explicit daily basal at midnight: 100% of day is remaining
        let fullDayBasal = CalorieEngine.proratedRemainingBasal(
            now: midnight,
            dailyBasal: 1800.0,
            basalSoFar: 0.0,
            calendar: calendar
        )
        XCTAssertEqual(fullDayBasal, 1800.0, accuracy: 1.0)
    }

    func testProratedBasalAtNoon() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Exactly 12:00 PM (halfway through the day)
        let noon = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12, minute: 0, second: 0))!

        let fractions = CalorieEngine.dayFractions(at: noon, calendar: calendar)
        XCTAssertEqual(fractions.elapsed, 0.5, accuracy: 0.01)
        XCTAssertEqual(fractions.remaining, 0.5, accuracy: 0.01)

        // If daily basal is 1600, at noon remaining basal is 800
        let remaining = CalorieEngine.proratedRemainingBasal(
            now: noon,
            dailyBasal: 1600.0,
            basalSoFar: 800.0,
            calendar: calendar
        )
        XCTAssertEqual(remaining, 800.0, accuracy: 5.0)

        // Extrapolating without dailyBasal: basalSoFar = 750 at noon -> projected remaining ~750
        let extrapolated = CalorieEngine.proratedRemainingBasal(
            now: noon,
            dailyBasal: nil,
            basalSoFar: 750.0,
            calendar: calendar
        )
        XCTAssertEqual(extrapolated, 750.0, accuracy: 10.0)
    }

    // MARK: - 5. Projected Out & Remaining Planned Training

    func testProjectedOutIncludesProratedBasalAndPlannedTraining() {
        // outSoFar = 1200 (600 basal + 600 active workout)
        // remainingBasal = 800
        // plannedTrainingEstKcal = 400
        let projectedOut = CalorieEngine.calculateProjectedOut(
            outSoFar: 1200.0,
            remainingBasal: 800.0,
            plannedTrainingEstKcal: 400.0
        )
        XCTAssertEqual(projectedOut, 2400.0)
    }

    func testRemainingPlannedTrainingIgnoresCompletedOrActualSessions() {
        let s1 = TrainingSession(id: "s1", start: "08:00", durationMinutes: 45, estKcal: 350, actualKcal: 360, isActual: true)
        let s2 = TrainingSession(id: "s2", start: "18:00", durationMinutes: 60, estKcal: 500, actualKcal: nil, isActual: false)
        let s3 = TrainingSession(id: "s3", start: "20:00", durationMinutes: 30, estKcal: 200, actualKcal: nil, isActual: false)

        // s1 is actual (already completed), s2 is marked completed via set
        let remaining = CalorieEngine.remainingPlannedTrainingKcal(
            sessions: [s1, s2, s3],
            completedSessionIds: ["s2"]
        )
        XCTAssertEqual(remaining, 200.0, "Only s3 should remain planned (200 kcal)")
    }

    // MARK: - 6. Fallback Heuristics (Without HealthKit)

    func testFallbackWithManualBurn() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12, minute: 0))!

        let summary = CalorieEngine.calculateBalance(
            now: now,
            entries: [LogEntry(eventKey: "e1", itemId: "i1", status: .done, kcal: 800)],
            healthEnergy: nil, // HealthKit disabled/unavailable
            fallbackHistoricalBurn: 2000.0,
            manualBurnKcal: 1100.0,
            calendar: calendar
        )

        XCTAssertTrue(summary.isFallback)
        XCTAssertEqual(summary.consumedKcal, 800.0)
        XCTAssertEqual(summary.outSoFar, 1100.0, "Manual burn should take precedence in fallback")
        XCTAssertEqual(summary.balanceNow, -300.0) // 800 - 1100 = -300 (deficit)
    }

    func testFallbackWithProratedHistoricalAverage() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        // 12:00 PM -> 50% of the day
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12, minute: 0))!

        let summary = CalorieEngine.calculateBalance(
            now: now,
            entries: [LogEntry(eventKey: "e1", itemId: "i1", status: .done, kcal: 1500)],
            healthEnergy: nil,
            fallbackHistoricalBurn: 2400.0,
            manualBurnKcal: nil,
            calendar: calendar
        )

        XCTAssertTrue(summary.isFallback)
        // 50% of 2400 = 1200
        XCTAssertEqual(summary.outSoFar, 1200.0, accuracy: 20.0)
        // balanceNow = 1500 - 1200 = +300 (surplus)
        XCTAssertGreaterThan(summary.balanceNow, 0)
        XCTAssertEqual(summary.balanceNow, 300.0, accuracy: 20.0)
    }

    // MARK: - 7. FakeHealthStore: Idempotency, Undo & Never Write Active Burned

    func testFakeHealthStoreIdempotentWrites() async throws {
        let store = FakeHealthStore()
        let entry = LogEntry(
            id: UUID(),
            eventKey: "evt.lunch.20261102",
            itemId: "lunch",
            status: .done,
            timestamp: Date(),
            kcal: 650,
            protein: 45,
            carbs: 70,
            fat: 15
        )

        // Write first time
        let syncId1 = try await store.writeDietaryLog(entry, item: nil)
        XCTAssertEqual(syncId1, "orchard.\(entry.id.uuidString)")
        XCTAssertEqual(store.savedSamples.count, 1)
        XCTAssertEqual(store.savedSamples.first?.kcal, 650.0)

        // Write second time with updated calories (idempotency check)
        var updatedEntry = entry
        updatedEntry.kcal = 700.0
        let syncId2 = try await store.writeDietaryLog(updatedEntry, item: nil)
        XCTAssertEqual(syncId2, syncId1)
        XCTAssertEqual(store.savedSamples.count, 1, "Must replace existing sample, not append a duplicate")
        XCTAssertEqual(store.savedSamples.first?.kcal, 700.0)
    }

    func testFakeHealthStoreUndoFunctionality() async throws {
        let store = FakeHealthStore()
        let entry1 = LogEntry(eventKey: "e1", itemId: "i1", status: .done, kcal: 500)
        let entry2 = LogEntry(eventKey: "e2", itemId: "i2", status: .done, kcal: 600)

        try await store.writeDietaryLog(entry1, item: nil)
        try await store.writeDietaryLog(entry2, item: nil)
        XCTAssertEqual(store.savedSamples.count, 2)

        // Undo entry1
        try await store.deleteDietaryLog(for: entry1.id)
        XCTAssertEqual(store.savedSamples.count, 1)
        XCTAssertEqual(store.savedSamples.first?.logEntryId, entry2.id)

        // Undo entry2
        try await store.deleteDietaryLog(syncIdentifier: "orchard.\(entry2.id.uuidString)")
        XCTAssertEqual(store.savedSamples.count, 0)
    }

    func testSkippedMealDoesNotSaveDietarySample() async throws {
        let store = FakeHealthStore()
        let entry = LogEntry(eventKey: "e1", itemId: "i1", status: .skipped, kcal: 500)

        try await store.writeDietaryLog(entry, item: nil)
        XCTAssertEqual(store.savedSamples.count, 0, "Skipped meals must not save dietary samples")
    }

    func testFakeHealthStoreAuthorizationFailure() async {
        let store = FakeHealthStore()
        store.shouldFailAuthorization = true

        do {
            _ = try await store.requestAuthorization()
            XCTFail("Should have thrown notAuthorized")
        } catch let error as HealthStoreError {
            XCTAssertEqual(error, HealthStoreError.notAuthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFakeHealthStoreMockWorkoutsAndEnergyRead() async throws {
        let store = FakeHealthStore()
        let now = Date()
        let session = TrainingSession(
            id: "workout_1",
            startDate: now.addingTimeInterval(-3600),
            endDate: now,
            durationMinutes: 60,
            estKcal: 550,
            actualKcal: 550,
            isActual: true,
            title: "Running"
        )
        store.mockWorkouts = [session]
        store.mockEnergyBurned = EnergyBurned(basalKcal: 1500, activeKcal: 600)

        let workouts = try await store.readWorkouts(from: now.addingTimeInterval(-7200), to: now.addingTimeInterval(3600))
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.actualKcal, 550.0)

        let energy = try await store.readEnergyBurned(from: now.addingTimeInterval(-86400), to: now)
        XCTAssertEqual(energy.basalKcal, 1500.0)
        XCTAssertEqual(energy.activeKcal, 600.0)
        XCTAssertEqual(energy.totalKcal, 2100.0)
    }
}
