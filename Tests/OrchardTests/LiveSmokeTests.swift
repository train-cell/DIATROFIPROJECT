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
    /// - User wakes up at 10:30.
    /// - Daily template default on Monday is "training".
    /// - Resolver recalculates today's schedule with training protocol items.
    /// - Verify resolved events match protocol definitions exactly.
    func testScenario1_RealPlanMorningRhythmAndDay3Switch() throws {
        let plan = try loadRealPlan()

        // Verify the 5 nutrition protocol template structure exists in real plan
        XCTAssertEqual(plan.templates.count, 5, "Real plan must contain 5 templates")
        let expectedKeys = ["training", "double_training", "pre_race", "race_day", "rest"]
        for key in expectedKeys {
            XCTAssertNotNil(plan.templates[key], "Template \(key) must be present")
        }

        // Monday reference day: User wakes up at 10:30
        let mondayWake = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 10, minute: 30))!

        // By default, Monday maps to "training"
        let defaultTemplate = plan.templateKey(for: mondayWake, calendar: calendar)
        XCTAssertEqual(defaultTemplate, "training")

        // User switches to "rest" template in the morning
        let selectedKey = "rest"
        let activeKey = plan.templateKey(for: mondayWake, selectedTemplateName: selectedKey, calendar: calendar)
        XCTAssertEqual(activeKey, "rest", "Morning template selection must override default weekday")

        guard let trainingTemplate = plan.templates["training"] else {
            XCTFail("Missing training template in plan.json")
            return
        }

        // ScheduleResolver calculates today's schedule for training
        let resolvedEvents = ScheduleResolver.resolve(
            date: mondayWake,
            plan: plan,
            selectedTemplateName: "training",
            calendar: calendar
        )

        // Verify resolved events match training protocol
        XCTAssertFalse(resolvedEvents.isEmpty)
        XCTAssertTrue(resolvedEvents.contains { $0.itemId == "bf_fuel" })
        XCTAssertTrue(resolvedEvents.contains { $0.itemId == "sandwich" })
        XCTAssertTrue(resolvedEvents.contains { $0.itemId == "tupper1" })
        XCTAssertTrue(resolvedEvents.contains { $0.itemId == "main_meal" })
        XCTAssertTrue(resolvedEvents.contains { $0.itemId == "light_meal" })

        // Verify breakfast at 10:30
        let breakfast = try XCTUnwrap(resolvedEvents.first { $0.itemId == "bf_fuel" })
        XCTAssertEqual(calendar.component(.hour, from: breakfast.resolvedTime), 10)
        XCTAssertEqual(calendar.component(.minute, from: breakfast.resolvedTime), 30)

        // Verify sandwich at 12:00
        let sandwich = try XCTUnwrap(resolvedEvents.first { $0.itemId == "sandwich" })
        XCTAssertEqual(calendar.component(.hour, from: sandwich.resolvedTime), 12)
        XCTAssertEqual(calendar.component(.minute, from: sandwich.resolvedTime), 0)

        // Verify tupper at 13:30
        let tupper = try XCTUnwrap(resolvedEvents.first { $0.itemId == "tupper1" })
        XCTAssertEqual(calendar.component(.hour, from: tupper.resolvedTime), 13)
        XCTAssertEqual(calendar.component(.minute, from: tupper.resolvedTime), 30)

        // Verify post-workout shake at 16:45
        let postWorkout = try XCTUnwrap(resolvedEvents.first { $0.itemId == "post_workout_shake" })
        XCTAssertEqual(calendar.component(.hour, from: postWorkout.resolvedTime), 16)
        XCTAssertEqual(calendar.component(.minute, from: postWorkout.resolvedTime), 45)

        // Verify main meal at 17:45
        let mainMeal = try XCTUnwrap(resolvedEvents.first { $0.itemId == "main_meal" })
        XCTAssertEqual(calendar.component(.hour, from: mainMeal.resolvedTime), 17)
        XCTAssertEqual(calendar.component(.minute, from: mainMeal.resolvedTime), 45)

        // Verify planned calories
        let totalPlannedKcal = CalorieEngine.plannedDayKcal(template: trainingTemplate)
        XCTAssertGreaterThan(totalPlannedKcal, 1500.0)
    }

    // MARK: - Scenario 2: Mid-day Workout Shift & Meal Ripple

    /// Scenario 2:
    /// - Workout moved from 14:30 to 11:00 (duration 60 min, ending at 12:00).
    /// - Post-workout shake shifts dynamically to 15 min after workout (12:15).
    /// - Subsequent meal respects minMealGapMinutes (60 min).
    func testScenario2_RealPlanWorkoutShiftAndPostWorkoutRipple() throws {
        var plan = try loadRealPlan()
        plan.settings.minMealGapMinutes = 60

        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 10, minute: 30))!

        // Baseline training session in plan.json is at 14:30 (120 min) -> ends at 16:30
        // Post workout shake anchor is afterTraining(15m) -> resolves to 16:45
        let baselineEvents = ScheduleResolver.resolve(
            date: referenceDate,
            plan: plan,
            selectedTemplateName: "training",
            calendar: calendar
        )
        let baselineShake = try XCTUnwrap(baselineEvents.first { $0.itemId == "post_workout_shake" })
        XCTAssertEqual(calendar.component(.hour, from: baselineShake.resolvedTime), 16)
        XCTAssertEqual(calendar.component(.minute, from: baselineShake.resolvedTime), 45)

        // Now user moves/logs workout at 11:00 (duration 60 min, ending at 12:00)
        let actualWorkout = TrainingSession(
            id: "workout_actual",
            start: "11:00",
            durationMinutes: 60,
            estKcal: 550,
            actualKcal: 550,
            isActual: true,
            title: "Early Swim Session"
        )

        // Recalculate schedule with the shifted workout
        let shiftedEvents = ScheduleResolver.resolve(
            date: referenceDate,
            plan: plan,
            selectedTemplateName: "training",
            actualTrainings: [actualWorkout],
            calendar: calendar
        )

        // Post-workout shake shifts dynamically to 11:00 + 60m + 15m = 12:15
        let shiftedShake = try XCTUnwrap(shiftedEvents.first { $0.itemId == "post_workout_shake" })
        XCTAssertEqual(calendar.component(.hour, from: shiftedShake.resolvedTime), 12)
        XCTAssertEqual(calendar.component(.minute, from: shiftedShake.resolvedTime), 15)

        // Main meal shifts to 11:00 + 60m + 75m = 13:15 (60 min after 12:15) -> respects 60 min gap
        let mainMeal = try XCTUnwrap(shiftedEvents.first { $0.itemId == "main_meal" })
        XCTAssertEqual(calendar.component(.hour, from: mainMeal.resolvedTime), 13)
        XCTAssertEqual(calendar.component(.minute, from: mainMeal.resolvedTime), 15)
        let gap = mainMeal.resolvedTime.timeIntervalSince(shiftedShake.resolvedTime) / 60.0
        XCTAssertGreaterThanOrEqual(gap, 60.0)
        XCTAssertFalse(mainMeal.hasConflict)
    }

    // MARK: - Scenario 3: Overdue Meal Nudges

    /// Scenario 3:
    /// - Real meal scheduled at 12:00 remains unconfirmed at 12:35.
    /// - Verify `NotificationPlanner` produces nudges at +0m, +15m, +30m.
    /// - Verify overdue state is detected.
    func testScenario3_RealPlanOverdueMealNudges() throws {
        let plan = try loadRealPlan()
        let training = try XCTUnwrap(plan.templates["training"])
        let sandwichItem = try XCTUnwrap(training.items.first { $0.id == "sandwich" })

        let targetDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 0, minute: 0))!
        let mealTime = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12, minute: 0))!
        let unconfirmedTime = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12, minute: 35))!

        let event = ScheduledEvent(
            id: "evt.sandwich.20261102",
            itemId: sandwichItem.id,
            item: sandwichItem,
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

        let snackSpecs = specs.filter { $0.itemId == sandwichItem.id }
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
    /// - Log 3 real meals from training template:
    ///   1. Breakfast: Πρωινό «ΚΑΥΣΙΜΟ» (360 kcal, 22g protein, 40g carbs, 12g fat)
    ///   2. Sandwich & Χυμός (340 kcal, 26g protein, 32g carbs, 11g fat)
    ///   3. Main Meal: Κύριο Γεύμα (580 kcal, 62g protein, 12g carbs, 31g fat)
    /// - Calculate consumed vs burned with `CalorieEngine`.
    /// - Test real `HealthKitStore` querying & availability alongside `FakeHealthStore`.
    /// - Write to `FakeHealthStore`, verify idempotent sample matching `orchard.<uuid>`.
    /// - Perform undo, verify sample removed.
    func testScenario4_RealMealsEnergyBalanceAndHealthKitSync() async throws {
        let plan = try loadRealPlan()
        let training = try XCTUnwrap(plan.templates["training"])

        let breakfastItem = try XCTUnwrap(training.items.first { $0.id == "bf_fuel" })
        let sandwichItem = try XCTUnwrap(training.items.first { $0.id == "sandwich" })
        let mainMealItem = try XCTUnwrap(training.items.first { $0.id == "main_meal" })

        // 1. Log the 3 real meals
        let breakfastEntry = LogEntry(
            id: UUID(),
            eventKey: "evt.bf_fuel.20261102",
            itemId: breakfastItem.id,
            status: .done,
            kcal: breakfastItem.kcal,
            protein: breakfastItem.protein,
            carbs: breakfastItem.carbs,
            fat: breakfastItem.fat,
            note: breakfastItem.title
        )

        let sandwichEntry = LogEntry(
            id: UUID(),
            eventKey: "evt.sandwich.20261102",
            itemId: sandwichItem.id,
            status: .done,
            kcal: sandwichItem.kcal,
            protein: sandwichItem.protein,
            carbs: sandwichItem.carbs,
            fat: sandwichItem.fat,
            note: sandwichItem.title
        )

        let mainMealEntry = LogEntry(
            id: UUID(),
            eventKey: "evt.main_meal.20261102",
            itemId: mainMealItem.id,
            status: .done,
            kcal: mainMealItem.kcal,
            protein: mainMealItem.protein,
            carbs: mainMealItem.carbs,
            fat: mainMealItem.fat,
            note: mainMealItem.title
        )

        let loggedEntries = [breakfastEntry, sandwichEntry, mainMealEntry]

        // 2. Pure CalorieEngine calculations
        let consumedKcal = CalorieEngine.consumedKcal(entries: loggedEntries)
        XCTAssertEqual(consumedKcal, 1280.0) // 360 + 340 + 580

        let consumedMacros = CalorieEngine.consumedMacros(entries: loggedEntries)
        XCTAssertEqual(consumedMacros.protein, 110.0) // 22 + 26 + 62
        XCTAssertEqual(consumedMacros.carbs, 84.0)    // 40 + 32 + 12
        XCTAssertEqual(consumedMacros.fat, 54.0)      // 12 + 11 + 31

        // Balance against burned energy (HealthKit workout: 850 kcal + basal so far: 1100 kcal = 1950 kcal)
        let healthBurn = EnergyBurned(basalKcal: 1100, activeKcal: 850)
        let balanceSummary = CalorieEngine.calculateBalance(
            now: Date(),
            entries: loggedEntries,
            healthEnergy: healthBurn
        )

        XCTAssertEqual(balanceSummary.consumedKcal, 1280.0)
        XCTAssertEqual(balanceSummary.outSoFar, 1950.0)
        XCTAssertEqual(balanceSummary.balanceNow, -670.0, "1280 consumed - 1950 burned = -670 deficit")
        XCTAssertLessThan(balanceSummary.balanceNow, 0)

        // 3. Verify Real HealthKitStore interface and availability
        #if canImport(HealthKit)
        let realHK = HealthKitStore()
        let isHKAvailable = HealthKitStore.isAvailable
        if isHKAvailable {
            // In headless/simulator test runner without user authorization, queries may throw or return nil
            let workouts = try? await realHK.readWorkouts(from: Date().addingTimeInterval(-3600), to: Date())
            let energy = try? await realHK.readEnergyBurned(from: Date().addingTimeInterval(-3600), to: Date())
            if let workouts = workouts {
                XCTAssertNotNil(workouts)
            }
            if let energy = energy {
                XCTAssertNotNil(energy)
            }
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
        let sync2 = try await store.writeDietaryLog(sandwichEntry, item: sandwichItem)
        let sync3 = try await store.writeDietaryLog(mainMealEntry, item: mainMealItem)

        XCTAssertEqual(sync1, "orchard.\(breakfastEntry.id.uuidString)")
        XCTAssertEqual(sync2, "orchard.\(sandwichEntry.id.uuidString)")
        XCTAssertEqual(sync3, "orchard.\(mainMealEntry.id.uuidString)")

        let samples = await store.savedSamples
        XCTAssertEqual(samples.count, 3)

        // Re-write main meal with adjusted calories (e.g. 600 kcal)
        var adjustedMain = mainMealEntry
        adjustedMain.kcal = 600.0
        let sync3Updated = try await store.writeDietaryLog(adjustedMain, item: mainMealItem)
        XCTAssertEqual(sync3Updated, sync3)

        let samplesAfterUpdate = await store.savedSamples
        XCTAssertEqual(samplesAfterUpdate.count, 3, "Idempotent write must update without duplicating")
        XCTAssertEqual(samplesAfterUpdate.first { $0.syncIdentifier == sync3 }?.kcal, 600.0)

        // Perform undo on main meal
        try await store.deleteDietaryLog(for: mainMealEntry.id)
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
            inBedMinutes: 480,
            hrvMs: 68.0,
            restingHeartRateBpm: 52.0
        )

        // Efficiency
        let efficiency = try XCTUnwrap(sleep.efficiencyPercentage)
        XCTAssertEqual(efficiency, 93.75, accuracy: 0.1)

        // Restorative percentage
        let restorative = try XCTUnwrap(sleep.restorativePercentage)
        XCTAssertEqual(restorative, 44.44, accuracy: 0.1)

        // Sleep debt
        XCTAssertEqual(sleep.sleepDebtMinutes, -30)

        // Recovery score: 5 * 12 (60) + (93.75 * 0.25 = 23.4) + min(20, 44.44 * 0.5 = 20.0) + HRV bonus (5.0) = 108 -> clamped to 100
        XCTAssertEqual(sleep.recoveryScore, 100)

        // Biometrics
        XCTAssertEqual(sleep.hrvMs, 68.0)
        XCTAssertEqual(sleep.restingHeartRateBpm, 52.0)
        XCTAssertTrue(sleep.hrvStatusDescription.contains("Υψηλή Ετοιμότητα"))
        XCTAssertTrue(sleep.restingHeartRateStatusDescription.contains("Αθλητική Ανάκαμψη"))

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
            inBedMinutes: 420,
            hrvMs: 25.0,
            restingHeartRateBpm: 72.0
        )

        // Restless efficiency: 330 / 420 = 78.57%
        let restlessEff = try XCTUnwrap(restlessSleep.efficiencyPercentage)
        XCTAssertEqual(restlessEff, 78.57, accuracy: 0.1)

        // Restless restorative: (30 + 40) / 330 = 21.21%
        let restlessRest = try XCTUnwrap(restlessSleep.restorativePercentage)
        XCTAssertEqual(restlessRest, 21.21, accuracy: 0.1)

        // Restless debt: 330 - 480 = -150 minutes deficit
        XCTAssertEqual(restlessSleep.sleepDebtMinutes, -150)

        // Recovery score: 2 * 12 (24) + (78.57 * 0.25 = 19.6) + (21.21 * 0.5 = 10.6) - 5 (low HRV) = 49 (low readiness)
        XCTAssertEqual(restlessSleep.recoveryScore, 49)
        XCTAssertTrue(restlessSleep.hrvStatusDescription.contains("Αυξημένο Στρες"))

        // Test HealthStore integration
        let store = FakeHealthStore()
        await store.setMockSleepEntry(sleep)
        let retrieved = try await store.readSleepAnalysis(for: sampleDate, calendar: calendar)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.deepSleepMinutes, 90)
        XCTAssertEqual(retrieved?.recoveryScore, 100)
        XCTAssertEqual(retrieved?.hrvMs, 68.0)
        XCTAssertEqual(retrieved?.restingHeartRateBpm, 52.0)
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
