import XCTest
#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(OrchardDomain)
@testable import OrchardDomain
#endif
#if canImport(OrchardServices)
@testable import OrchardServices
#endif

/// End-to-end integration and live smoke tests simulating core user journeys in Orchard
/// using the REAL cyclical 7-day meal plan (`plan.json`) and real services.
final class LiveSmokeTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    // MARK: - Helper to Load Real Plan

    private func loadRealPlan() throws -> Plan {
        let planPaths = [
            "/Users/john_ak/antigarvity/Orchard/plan.json",
            "/Users/john_ak/antigarvity/Orchard/Resources/plan.json"
        ]
        for path in planPaths {
            if FileManager.default.fileExists(atPath: path),
               let plan = try? PlanLoader.loadPlan(fromFilePath: path) {
                return plan
            }
        }
        if let sampleUrl = Bundle.main.url(forResource: "plan.sample", withExtension: "json"),
           let plan = try? PlanLoader.loadPlan(from: sampleUrl) {
            return plan
        }
        throw XCTSkip("Real plan.json not accessible from current test bundle")
    }

    // MARK: - Scenario 1: Morning Rhythm & Template Switch

    /// Scenario 1:
    /// - User wakes up at 07:30.
    /// - Daily template switches to Day 3 (from the real 7-day cyclical plan).
    /// - Resolver recalculates today's schedule with Day 3 meals (breakfast, snack, etc.).
    /// - Verify all resolved events match Day 3 definitions exactly.
    func testScenario1_RealPlanMorningRhythmAndDay3Switch() throws {
        let plan = try loadRealPlan()

        // Verify the 7-day cyclical template structure exists in real plan
        XCTAssertEqual(plan.templates.count, 7, "Real plan must contain 7 day templates (day_1 to day_7)")
        for dayNum in 1...7 {
            XCTAssertNotNil(plan.templates["day_\(dayNum)"], "Template day_\(dayNum) must be present")
        }

        // Monday reference day: User wakes up at 07:30
        let mondayWake = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 7, minute: 30))!

        // By default, Monday maps to "day_1"
        let defaultTemplate = plan.templateKey(for: mondayWake, calendar: calendar)
        XCTAssertEqual(defaultTemplate, "day_1")

        // User switches to Day 3 template in the morning
        let selectedKey = "day_3"
        let activeKey = plan.templateKey(for: mondayWake, selectedTemplateName: selectedKey, calendar: calendar)
        XCTAssertEqual(activeKey, "day_3", "Morning template selection must override default weekday")

        guard let day3Template = plan.templates["day_3"] else {
            XCTFail("Missing day_3 template in plan.json")
            return
        }

        // ScheduleResolver calculates today's schedule
        let resolvedEvents = ScheduleResolver.resolve(
            date: mondayWake,
            plan: plan,
            selectedTemplateName: selectedKey,
            calendar: calendar
        )

        // Verify all 6 Day 3 items are resolved
        XCTAssertEqual(resolvedEvents.count, 6)

        let expectedIds = ["d3_breakfast", "d3_morning_snack", "d3_midday_snack", "d3_post_workout", "d3_dinner", "d3_extra"]
        XCTAssertEqual(resolvedEvents.map { $0.itemId }, expectedIds)

        // Verify Day 3 breakfast: "Πρωινό: 1 φλ. γάλα 1.5% χωρίς λακτόζη, 2 φέτες ψωμί ολικής, 2 κ.γλ. ταχίνι με κακάο, 1 μεγάλο φρούτο"
        let breakfast = try XCTUnwrap(resolvedEvents.first { $0.itemId == "d3_breakfast" })
        XCTAssertTrue(breakfast.item.title.contains("ταχίνι με κακάο"))
        XCTAssertEqual(breakfast.item.kcal, 440.0)
        XCTAssertEqual(calendar.component(.hour, from: breakfast.resolvedTime), 10)
        XCTAssertEqual(calendar.component(.minute, from: breakfast.resolvedTime), 30)

        // Verify Day 3 morning snack: 12:00
        let morningSnack = try XCTUnwrap(resolvedEvents.first { $0.itemId == "d3_morning_snack" })
        XCTAssertTrue(morningSnack.item.title.contains("Δεκατιανό"))
        XCTAssertEqual(morningSnack.item.kcal, 340.0)
        XCTAssertEqual(calendar.component(.hour, from: morningSnack.resolvedTime), 12)
        XCTAssertEqual(calendar.component(.minute, from: morningSnack.resolvedTime), 0)

        // Verify Day 3 post-workout shake: "Μεταπροπονητικό: 1 φλ. γάλα 1.5% (+260ml νερό, + Pro)"
        let postWorkout = try XCTUnwrap(resolvedEvents.first { $0.itemId == "d3_post_workout" })
        XCTAssertTrue(postWorkout.item.title.contains("γάλα 1.5%"))
        XCTAssertTrue(postWorkout.item.title.contains("+ Pro"))
        XCTAssertEqual(postWorkout.item.kcal, 240.0)

        // Verify Day 3 dinner: 20:30
        let dinner = try XCTUnwrap(resolvedEvents.first { $0.itemId == "d3_dinner" })
        XCTAssertTrue(dinner.item.title.contains("Κυρίως"))
        XCTAssertEqual(dinner.item.kcal, 690.0)
        XCTAssertEqual(calendar.component(.hour, from: dinner.resolvedTime), 20)
        XCTAssertEqual(calendar.component(.minute, from: dinner.resolvedTime), 30)

        // Verify total Day 3 planned calories
        let totalPlannedKcal = CalorieEngine.plannedDayKcal(template: day3Template)
        XCTAssertEqual(totalPlannedKcal, 2000.0) // 440 + 340 + 130 + 240 + 690 + 160
    }

    // MARK: - Scenario 2: Mid-day Workout Shift & Meal Ripple

    /// Scenario 2:
    /// - Workout moved from 18:00 to 14:00 (duration 60 min, ending at 15:00).
    /// - Post-workout meal (γάλα 1,5% + Pro) shifts dynamically to 30 min after workout (15:30).
    /// - Subsequent meal respects `minMealGapMinutes` (90 min).
    func testScenario2_RealPlanWorkoutShiftAndPostWorkoutRipple() throws {
        var plan = try loadRealPlan()
        plan.settings.minMealGapMinutes = 90 // Test with 90 minute minimum meal gap

        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 8, minute: 0))!

        // Baseline Day 1 planned workout in plan.json is at 17:30 (90 min) -> ends at 19:00
        // Post workout shake anchor is afterTraining(30m) -> resolves to 19:30
        let baselineEvents = ScheduleResolver.resolve(
            date: referenceDate,
            plan: plan,
            selectedTemplateName: "day_1",
            calendar: calendar
        )
        let baselineShake = try XCTUnwrap(baselineEvents.first { $0.itemId == "d1_post_workout" })
        XCTAssertEqual(calendar.component(.hour, from: baselineShake.resolvedTime), 19)
        XCTAssertEqual(calendar.component(.minute, from: baselineShake.resolvedTime), 30)

        // Now user moves/logs workout at 14:00 (duration 60 min, ending at 15:00)
        let actualWorkout = TrainingSession(
            id: "workout_d1_actual",
            start: "14:00",
            durationMinutes: 60,
            estKcal: 550,
            actualKcal: 550,
            isActual: true,
            title: "Strength Training"
        )

        // Recalculate schedule with the shifted workout
        let shiftedEvents = ScheduleResolver.resolve(
            date: referenceDate,
            plan: plan,
            selectedTemplateName: "day_1",
            actualTrainings: [actualWorkout],
            calendar: calendar
        )

        // Post-workout shake ("γάλα 1,5% + Pro") shifts dynamically to 14:00 + 60m + 30m = 15:30
        let shiftedShake = try XCTUnwrap(shiftedEvents.first { $0.itemId == "d1_post_workout" })
        XCTAssertEqual(calendar.component(.hour, from: shiftedShake.resolvedTime), 15)
        XCTAssertEqual(calendar.component(.minute, from: shiftedShake.resolvedTime), 30)

        // Subsequent meal in Day 1 is dinner at 20:30 (300 min after 15:30) -> respects 90 min gap
        let dinner = try XCTUnwrap(shiftedEvents.first { $0.itemId == "d1_dinner" })
        let dinnerGap = dinner.resolvedTime.timeIntervalSince(shiftedShake.resolvedTime) / 60.0
        XCTAssertGreaterThanOrEqual(dinnerGap, 90.0)
        XCTAssertFalse(dinner.hasConflict)

        // Verify minMealGapMinutes conflict detection if an intermediate meal were at 16:30 (60 min < 90 min)
        var customTemplate = plan.templates["day_1"]!
        customTemplate.items.append(
            PlanItem(id: "intermediate_snack", type: .meal, title: "Quick Snack", anchor: .absolute(time: "16:30"), kcal: 150)
        )
        plan.templates["day_1_custom"] = customTemplate

        let tightEvents = ScheduleResolver.resolve(
            date: referenceDate,
            plan: plan,
            selectedTemplateName: "day_1_custom",
            actualTrainings: [actualWorkout],
            calendar: calendar
        )
        let tightSnack = try XCTUnwrap(tightEvents.first { $0.itemId == "intermediate_snack" })
        XCTAssertTrue(tightSnack.hasConflict, "60 min gap between 15:30 and 16:30 violates minMealGapMinutes 90")
        XCTAssertTrue(tightSnack.conflictReason?.contains("Gap between meals (60 min)") ?? false)
    }

    // MARK: - Scenario 3: Overdue Meal Nudges

    /// Scenario 3:
    /// - Real meal scheduled at 12:00 remains unconfirmed at 12:35.
    /// - Verify `NotificationPlanner` produces nudges at +0m, +15m, +30m.
    /// - Verify overdue state is detected.
    func testScenario3_RealPlanOverdueMealNudges() throws {
        let plan = try loadRealPlan()
        let day1 = try XCTUnwrap(plan.templates["day_1"])
        let morningSnackItem = try XCTUnwrap(day1.items.first { $0.id == "d1_morning_snack" })

        // In real plan, d1_morning_snack is at 12:00 (260 kcal)
        if case .absolute(let time) = morningSnackItem.anchor {
            XCTAssertEqual(time, "12:00")
        } else {
            XCTFail("Expected .absolute anchor for d1_morning_snack")
        }
        XCTAssertEqual(morningSnackItem.kcal, 260.0)

        let targetDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 0, minute: 0))!
        let mealTime = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12, minute: 0))!
        let unconfirmedTime = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12, minute: 35))!

        let event = ScheduledEvent(
            id: "evt.d1_morning_snack.20261102",
            itemId: morningSnackItem.id,
            item: morningSnackItem,
            date: targetDate,
            resolvedTime: mealTime
        )

        // Morning planning at 08:00
        let morningPlanningTime = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 8, minute: 0))!
        let specs = NotificationPlanner.plan(
            events: [event],
            logs: [],
            now: morningPlanningTime,
            calendar: calendar
        )

        let snackSpecs = specs.filter { $0.itemId == morningSnackItem.id }
        XCTAssertEqual(snackSpecs.count, 3, "Meals must have 3 nudges (+0m, +15m, +30m)")

        // +0m at 12:00
        XCTAssertEqual(snackSpecs[0].fireDate, mealTime)
        XCTAssertEqual(snackSpecs[0].nudgeIndex, 0)
        XCTAssertTrue(snackSpecs[0].isTimeSensitive)

        // +15m at 12:15
        XCTAssertEqual(snackSpecs[1].fireDate, mealTime.addingTimeInterval(15 * 60))
        XCTAssertEqual(snackSpecs[1].nudgeIndex, 1)

        // +30m at 12:30
        XCTAssertEqual(snackSpecs[2].fireDate, mealTime.addingTimeInterval(30 * 60))
        XCTAssertEqual(snackSpecs[2].nudgeIndex, 2)

        // At 12:35, the meal is unconfirmed: AppleProgress marks it overdue
        let progress = AppleProgress.calculate(
            events: [event],
            logEntries: [],
            referenceDate: unconfirmedTime,
            overdueGraceMinutes: 0
        )

        XCTAssertEqual(progress.slices.count, 1)
        let slice = try XCTUnwrap(progress.slices.first)
        XCTAssertEqual(slice.state, .overdue, "Unconfirmed meal past scheduled time must be .overdue")
        XCTAssertEqual(progress.overdueCount, 1)
        XCTAssertEqual(progress.pendingCount, 0)
        XCTAssertEqual(progress.eatenCount, 0)
    }

    // MARK: - Scenario 4: Energy Balance & HealthKit Idempotent Sync

    /// Scenario 4:
    /// - Log 3 real meals from Day 1:
    ///   1. Breakfast: 1 αραβική ολικής, γάλα 1.5%, τυρί (380 kcal, 26g protein, 45g carbs, 10g fat)
    ///   2. Post-workout: γάλα 1.5% + Pro (240 kcal, 32g protein, 14g carbs, 4g fat)
    ///   3. Dinner: 3 καλαμάκια κοτόπουλο, πίτα ολικής (650 kcal, 55g protein, 40g carbs, 28g fat)
    /// - Calculate consumed vs burned with `CalorieEngine`.
    /// - Test real `HealthKitStore` querying & availability alongside `FakeHealthStore`.
    /// - Write to `FakeHealthStore`, verify idempotent sample matching `orchard.<uuid>`.
    /// - Perform undo, verify sample removed.
    func testScenario4_RealMealsEnergyBalanceAndHealthKitSync() async throws {
        let plan = try loadRealPlan()
        let day1 = try XCTUnwrap(plan.templates["day_1"])

        let breakfastItem = try XCTUnwrap(day1.items.first { $0.id == "d1_breakfast" })
        let postWorkoutItem = try XCTUnwrap(day1.items.first { $0.id == "d1_post_workout" })
        let dinnerItem = try XCTUnwrap(day1.items.first { $0.id == "d1_dinner" })

        // 1. Log the 3 real meals
        let breakfastEntry = LogEntry(
            id: UUID(),
            eventKey: "evt.d1_breakfast.20261102",
            itemId: breakfastItem.id,
            status: .done,
            kcal: breakfastItem.kcal,
            protein: breakfastItem.protein,
            carbs: breakfastItem.carbs,
            fat: breakfastItem.fat,
            note: breakfastItem.title
        )

        let postWorkoutEntry = LogEntry(
            id: UUID(),
            eventKey: "evt.d1_post_workout.20261102",
            itemId: postWorkoutItem.id,
            status: .done,
            kcal: postWorkoutItem.kcal,
            protein: postWorkoutItem.protein,
            carbs: postWorkoutItem.carbs,
            fat: postWorkoutItem.fat,
            note: postWorkoutItem.title
        )

        let dinnerEntry = LogEntry(
            id: UUID(),
            eventKey: "evt.d1_dinner.20261102",
            itemId: dinnerItem.id,
            status: .done,
            kcal: dinnerItem.kcal,
            protein: dinnerItem.protein,
            carbs: dinnerItem.carbs,
            fat: dinnerItem.fat,
            note: dinnerItem.title
        )

        let loggedEntries = [breakfastEntry, postWorkoutEntry, dinnerEntry]

        // 2. Pure CalorieEngine calculations
        let consumedKcal = CalorieEngine.consumedKcal(entries: loggedEntries)
        XCTAssertEqual(consumedKcal, 1270.0) // 380 + 240 + 650

        let consumedMacros = CalorieEngine.consumedMacros(entries: loggedEntries)
        XCTAssertEqual(consumedMacros.protein, 113.0) // 26 + 32 + 55
        XCTAssertEqual(consumedMacros.carbs, 99.0)    // 45 + 14 + 40
        XCTAssertEqual(consumedMacros.fat, 42.0)      // 10 + 4 + 28

        // Balance against burned energy (HealthKit workout: 650 kcal + basal so far: 1100 kcal = 1750 kcal)
        let healthBurn = EnergyBurned(basalKcal: 1100, activeKcal: 650)
        let balanceSummary = CalorieEngine.calculateBalance(
            now: Date(),
            entries: loggedEntries,
            healthEnergy: healthBurn
        )

        XCTAssertEqual(balanceSummary.consumedKcal, 1270.0)
        XCTAssertEqual(balanceSummary.outSoFar, 1750.0)
        XCTAssertEqual(balanceSummary.balanceNow, -480.0, "1270 consumed - 1750 burned = -480 deficit")
        XCTAssertLessThan(balanceSummary.balanceNow, 0)

        // 3. Verify Real HealthKitStore interface and availability
        #if canImport(HealthKit)
        let realHK = HealthKitStore()
        let isHKAvailable = HealthKitStore.isAvailable
        if isHKAvailable {
            let workouts = try? await realHK.readWorkouts(from: Date().addingTimeInterval(-3600), to: Date())
            let energy = try? await realHK.readEnergyBurned(from: Date().addingTimeInterval(-3600), to: Date())
            XCTAssertNotNil(workouts)
            XCTAssertNotNil(energy)
        } else {
            let workouts = try await realHK.readWorkouts(from: Date().addingTimeInterval(-3600), to: Date())
            XCTAssertTrue(workouts.isEmpty)
            let energy = try await realHK.readEnergyBurned(from: Date().addingTimeInterval(-3600), to: Date())
            XCTAssertEqual(energy.totalKcal, 0.0)
        }
        #endif

        // 4. Test FakeHealthStore sync, idempotent writes, and undo
        let store = FakeHealthStore()
        let sync1 = try await store.writeDietaryLog(breakfastEntry, item: breakfastItem)
        let sync2 = try await store.writeDietaryLog(postWorkoutEntry, item: postWorkoutItem)
        let sync3 = try await store.writeDietaryLog(dinnerEntry, item: dinnerItem)

        XCTAssertEqual(sync1, "orchard.\(breakfastEntry.id.uuidString)")
        XCTAssertEqual(sync2, "orchard.\(postWorkoutEntry.id.uuidString)")
        XCTAssertEqual(sync3, "orchard.\(dinnerEntry.id.uuidString)")

        let samples = await store.savedSamples
        XCTAssertEqual(samples.count, 3)

        // Re-write dinner with adjusted calories (e.g. 700 kcal)
        var adjustedDinner = dinnerEntry
        adjustedDinner.kcal = 700.0
        let sync3Updated = try await store.writeDietaryLog(adjustedDinner, item: dinnerItem)
        XCTAssertEqual(sync3Updated, sync3)

        let samplesAfterUpdate = await store.savedSamples
        XCTAssertEqual(samplesAfterUpdate.count, 3, "Idempotent write must update without duplicating")
        XCTAssertEqual(samplesAfterUpdate.first { $0.syncIdentifier == sync3 }?.kcal, 700.0)

        // Perform undo on dinner
        try await store.deleteDietaryLog(for: dinnerEntry.id)
        let samplesAfterUndo = await store.savedSamples
        XCTAssertEqual(samplesAfterUndo.count, 2)
        XCTAssertNil(samplesAfterUndo.first { $0.syncIdentifier == sync3 })
    }

    // MARK: - Scenario 5: 7-Day Signing Expiry Guard

    /// Scenario 5:
    /// - Verify warning alert generated when expiration is within 24h (`warn24h`).
    /// - Verify critical alert generated when expiration is within 2h (`critical2h`).
    /// - Verify alerts suppressed when already expired.
    func testScenario5_SevenDaySigningExpiryGuard() {
        let now = Date(timeIntervalSince1970: 1700000000)

        // 1. Generation of 24h and 2h alert specifications when certificate is active (48h remaining)
        let expiry48h = now.addingTimeInterval(48 * 3600)
        let guardActive = SigningGuard(customExpirationDate: expiry48h, referenceDate: now)
        let activeAlerts = guardActive.makeExpiryAlertSpecs(now: now)
        XCTAssertEqual(activeAlerts.count, 2)
        XCTAssertEqual(activeAlerts[0].identifier, SigningGuard.alert24hIdentifier)
        XCTAssertEqual(activeAlerts[1].identifier, SigningGuard.alert2hIdentifier)

        // 2. Expiration within 24h (18 hours remaining) -> .warn24h
        let expiry18h = now.addingTimeInterval(18 * 3600)
        let guard24h = SigningGuard(customExpirationDate: expiry18h, referenceDate: now)
        XCTAssertEqual(guard24h.warningLevel, .warn24h, "18 hours remaining must be classified as .warn24h")
        XCTAssertFalse(guard24h.isExpired)
        XCTAssertEqual(guard24h.hoursRemaining, 18)

        // For 18h remaining, T-24h is already past, so only T-2h alert remains pending
        let specs18h = guard24h.makeExpiryAlertSpecs(now: now)
        XCTAssertEqual(specs18h.count, 1)
        XCTAssertEqual(specs18h[0].identifier, SigningGuard.alert2hIdentifier)

        // 3. Expiration within 2h (90 minutes remaining) -> .critical2h
        let expiry90m = now.addingTimeInterval(90 * 60)
        let guard2h = SigningGuard(customExpirationDate: expiry90m, referenceDate: now)
        XCTAssertEqual(guard2h.warningLevel, .critical2h, "90 minutes remaining must be classified as .critical2h")
        XCTAssertFalse(guard2h.isExpired)
        XCTAssertEqual(guard2h.hoursRemaining, 1)

        // 4. Already expired -> .expired and alerts suppressed
        let expiredTime = now.addingTimeInterval(-3600)
        let guardExpired = SigningGuard(customExpirationDate: expiredTime, referenceDate: now)
        XCTAssertEqual(guardExpired.warningLevel, .expired, "Past expiration must be classified as .expired")
        XCTAssertTrue(guardExpired.isExpired)

        let expiredAlerts = guardExpired.makeExpiryAlertSpecs(now: now)
        XCTAssertTrue(expiredAlerts.isEmpty, "Expiry alerts must be suppressed when certificate is already expired")
    }

    // MARK: - Scenario 6: AutoSleep & Bevel Sleep Architecture & Apple Watch Ultra 3

    /// Scenario 6:
    /// - User sleeps with Apple Watch Ultra 3.
    /// - HealthStore captures 450 min total asleep: 90m deep sleep, 110m REM, 250m core, 30m awake (480m in bed).
    /// - Verify sleep efficiency calculation: 450 / 480 = 93.75%.
    /// - Verify restorative sleep calculation: (90 + 110) / 450 = 44.44% (in the ideal 35-45% band).
    /// - Verify sleep debt relative to 8-hour target: 450 - 480 = -30m deficit.
    /// - Verify Recovery Readiness Score: high subjective rating (5/5) + high efficiency + high restorative sleep yields >= 85 (optimal readiness).
    func testScenario6_AutoSleepBevelHealthKitSleepMetrics() async throws {
        let sampleDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 7, minute: 30))!
        let sleep = SleepEntry(
            date: sampleDate,
            rating: 5,
            tags: ["Ξεκούραστος", "Βαθύς Ύπνος", "Apple Watch Ultra 3"],
            asleepMinutes: 450,
            deepSleepMinutes: 90,
            remSleepMinutes: 110,
            coreSleepMinutes: 250,
            awakeMinutes: 30,
            inBedMinutes: 480
        )

        // Efficiency
        let efficiency = try XCTUnwrap(sleep.efficiencyPercentage)
        XCTAssertEqual(efficiency, 93.75, accuracy: 0.1)

        // Restorative percentage
        let restorative = try XCTUnwrap(sleep.restorativePercentage)
        XCTAssertEqual(restorative, 44.44, accuracy: 0.1)

        // Sleep debt
        XCTAssertEqual(sleep.sleepDebtMinutes, -30)

        // Recovery score: 5 * 12 (60) + (93.75 * 0.25 = 23.4) + min(20, 44.44 * 0.5 = 20.0) = 103 -> clamped to 100
        XCTAssertEqual(sleep.recoveryScore, 100)

        // Simulate a restless night: rating 2, 330 min asleep, 30m deep, 40m REM, 90m awake, 420m in bed
        let restlessSleep = SleepEntry(
            date: sampleDate,
            rating: 2,
            tags: ["Καφεΐνη αργά", "Στρες"],
            asleepMinutes: 330,
            deepSleepMinutes: 30,
            remSleepMinutes: 40,
            coreSleepMinutes: 260,
            awakeMinutes: 90,
            inBedMinutes: 420
        )

        // Restless efficiency: 330 / 420 = 78.57%
        let restlessEff = try XCTUnwrap(restlessSleep.efficiencyPercentage)
        XCTAssertEqual(restlessEff, 78.57, accuracy: 0.1)

        // Restless restorative: (30 + 40) / 330 = 21.21%
        let restlessRest = try XCTUnwrap(restlessSleep.restorativePercentage)
        XCTAssertEqual(restlessRest, 21.21, accuracy: 0.1)

        // Restless debt: 330 - 480 = -150 minutes deficit
        XCTAssertEqual(restlessSleep.sleepDebtMinutes, -150)

        // Recovery score: 2 * 12 (24) + (78.57 * 0.25 = 19.6) + (21.21 * 0.5 = 10.6) = 54 (low readiness)
        XCTAssertEqual(restlessSleep.recoveryScore, 54)

        // Test HealthStore integration
        let store = FakeHealthStore()
        await store.setMockSleepEntry(sleep)
        let retrieved = try await store.readSleepAnalysis(for: sampleDate, calendar: calendar)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.deepSleepMinutes, 90)
        XCTAssertEqual(retrieved?.recoveryScore, 100)
    }

    // MARK: - Scenario 7: Athletic Supplements & Zero-Mock Gemini BYOK Router Pipeline

    /// Scenario 7:
    /// - Log athletic supplements: Creatine (5g), Whey Protein (30g), Multivitamins, Electrolytes.
    /// - Verify calorie and macro behavior: Creatine/Multivitamins/Electrolytes = 0 kcal, Whey = 120 kcal (25g P, 2g C, 1g F).
    /// - Verify LLMRouter hierarchy: Gemini provider has top priority, mock is completely absent in production.
    func testScenario7_AthleticSupplementsAndGeminiZeroMock() async throws {
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 9, minute: 0))!

        // 1. Athletic supplements logging
        let creatine = LogEntry(
            eventKey: "manual_creatine",
            itemId: "manual_creatine",
            status: .done,
            timestamp: referenceDate,
            kcal: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            source: .manual,
            note: "Κρεατίνη (5g)"
        )

        let whey = LogEntry(
            eventKey: "manual_whey",
            itemId: "manual_whey",
            status: .done,
            timestamp: referenceDate,
            kcal: 120,
            protein: 25,
            carbs: 2,
            fat: 1,
            source: .manual,
            note: "Πρωτεΐνη Whey (30g)"
        )

        let electrolytes = LogEntry(
            eventKey: "manual_electrolytes",
            itemId: "manual_electrolytes",
            status: .done,
            timestamp: referenceDate,
            kcal: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            source: .manual,
            note: "Ηλεκτρολύτες"
        )

        let suppEntries = [creatine, whey, electrolytes]
        let totalKcal = CalorieEngine.consumedKcal(entries: suppEntries)
        let macros = CalorieEngine.consumedMacros(entries: suppEntries)

        XCTAssertEqual(totalKcal, 120.0)
        XCTAssertEqual(macros.protein, 25.0)
        XCTAssertEqual(macros.carbs, 2.0)
        XCTAssertEqual(macros.fat, 1.0)

        // 2. Verify Zero-Mock production LLMRouter contract
        let productionRouter = LLMRouter()
        // In production, mock provider is nil by default
        let defaultActive = await productionRouter.activeProvider()
        // If no Gemini key or on-device model is available, activeProvider returns nil (strictly no fake fallback)
        if defaultActive != nil {
            XCTAssertNotEqual(defaultActive?.id, "mock", "Production router must NEVER fall back to mock provider")
        }

        // Test Gemini provider presence in priority hierarchy
        let keychain = KeychainStore(inMemory: true)
        keychain.saveAPIKey("TEST_GEMINI_API_KEY_12345")
        let geminiProvider = GeminiLLMProvider(apiKey: "TEST_GEMINI_API_KEY_12345")
        let geminiAvailable = await geminiProvider.isAvailable()
        XCTAssertTrue(geminiAvailable)
        XCTAssertEqual(geminiProvider.id, "gemini")

        let customRouter = LLMRouter(gemini: geminiProvider)
        let active = await customRouter.activeProvider()
        XCTAssertEqual(active?.id, "gemini")
    }
}
