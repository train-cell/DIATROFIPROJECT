import XCTest
@testable import OrchardDomain

final class NewNutritionProtocolTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDate(year: Int = 2026, month: Int = 11, day: Int = 2, hour: Int = 12, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }

    // MARK: - 1. PlanOption & PlanItem Menu-Picker Schema

    func testPlanOptionModelPropertiesAndDecoding() throws {
        let json = """
        {
            "id": "opt_tuna",
            "title": "Τόνος σε νερό με μαρούλι",
            "category": "High Protein",
            "details": "1 μεγάλη κονσέρβα τόνου σε νερό + μαρούλι + 1 κ.σ. λάδι",
            "kcal": 280.0,
            "protein": 35.0,
            "carbs": 5.0,
            "fat": 12.0,
            "isEstimatedMacros": false
        }
        """.data(using: .utf8)!

        let option = try JSONDecoder().decode(PlanOption.self, from: json)
        XCTAssertEqual(option.id, "opt_tuna")
        XCTAssertEqual(option.title, "Τόνος σε νερό με μαρούλι")
        XCTAssertEqual(option.category, "High Protein")
        XCTAssertEqual(option.details, "1 μεγάλη κονσέρβα τόνου σε νερό + μαρούλι + 1 κ.σ. λάδι")
        XCTAssertEqual(option.kcal, 280.0)
        XCTAssertEqual(option.protein, 35.0)
        XCTAssertEqual(option.carbs, 5.0)
        XCTAssertEqual(option.fat, 12.0)
        XCTAssertFalse(option.isEstimatedMacros)
    }

    func testPlanOptionDefaultEstimatedMacrosTrue() throws {
        let json = """
        {
            "id": "opt_basic",
            "title": "Βασική Επιλογή"
        }
        """.data(using: .utf8)!

        let option = try JSONDecoder().decode(PlanOption.self, from: json)
        XCTAssertEqual(option.id, "opt_basic")
        XCTAssertTrue(option.isEstimatedMacros, "Missing isEstimatedMacros should default to true")
        XCTAssertNil(option.kcal)
    }

    func testPlanItemOptionHelpersAndEffectiveMacros() {
        let opt1 = PlanOption(
            id: "opt_1",
            title: "Option 1 (Chicken)",
            category: "Protein",
            details: "Grilled chicken",
            kcal: 450.0,
            protein: 40.0,
            carbs: 30.0,
            fat: 10.0,
            isEstimatedMacros: false
        )
        let opt2 = PlanOption(
            id: "opt_2",
            title: "Option 2 (Salmon)",
            category: "Fish",
            details: "Baked salmon",
            kcal: 550.0,
            protein: 38.0,
            carbs: 25.0,
            fat: 22.0,
            isEstimatedMacros: false
        )

        let item = PlanItem(
            id: "lunch",
            type: .meal,
            title: "Μεσημεριανό",
            anchor: .absolute(time: "14:00"),
            kcal: 400.0,
            protein: 30.0,
            carbs: 40.0,
            fat: 10.0,
            options: [opt1, opt2],
            activeWeekdays: [.mon, .wed, .fri],
            sessionIndex: 0,
            waterMl: 500.0,
            isOptional: true
        )

        // Field checks
        XCTAssertEqual(item.options?.count, 2)
        XCTAssertEqual(item.activeWeekdays, [.mon, .wed, .fri])
        XCTAssertEqual(item.sessionIndex, 0)
        XCTAssertEqual(item.waterMl, 500.0)
        XCTAssertEqual(item.isOptional, true)

        // option(for:) helper
        XCTAssertEqual(item.option(for: "opt_1"), opt1)
        XCTAssertEqual(item.option(for: "opt_2"), opt2)
        XCTAssertNil(item.option(for: "non_existent"))
        XCTAssertNil(item.option(for: nil))

        // effectiveMacros helper
        let macrosOpt1 = item.effectiveMacros(selectedOptionId: "opt_1")
        XCTAssertEqual(macrosOpt1.kcal, 450.0)
        XCTAssertEqual(macrosOpt1.protein, 40.0)
        XCTAssertEqual(macrosOpt1.carbs, 30.0)
        XCTAssertEqual(macrosOpt1.fat, 10.0)

        let macrosOpt2 = item.effectiveMacros(selectedOptionId: "opt_2")
        XCTAssertEqual(macrosOpt2.kcal, 550.0)
        XCTAssertEqual(macrosOpt2.protein, 38.0)

        // Fallback to base item macros when no option selected
        let defaultMacros = item.effectiveMacros(selectedOptionId: nil)
        XCTAssertEqual(defaultMacros.kcal, 400.0)
        XCTAssertEqual(defaultMacros.protein, 30.0)
    }

    // MARK: - 2. DayTemplate New Optional Metadata

    func testDayTemplateNewOptionalFields() throws {
        let json = """
        {
            "title": "Ημέρα Προπόνησης",
            "subtitle": "Τεχνική Κολύμβηση 120'",
            "icon": "figure.pool.swim",
            "targetWaterMl": 3000.0,
            "order": 0,
            "trainingSessions": [],
            "items": [],
            "rules": []
        }
        """.data(using: .utf8)!

        let template = try JSONDecoder().decode(DayTemplate.self, from: json)
        XCTAssertEqual(template.title, "Ημέρα Προπόνησης")
        XCTAssertEqual(template.subtitle, "Τεχνική Κολύμβηση 120'")
        XCTAssertEqual(template.icon, "figure.pool.swim")
        XCTAssertEqual(template.targetWaterMl, 3000.0)
        XCTAssertEqual(template.order, 0)
    }

    // MARK: - 3. PlanSettings Backward-Compatibility & New Fields

    func testPlanSettingsBackwardCompatibilityAndDefaults() throws {
        // Legacy JSON without targetWaterMl, minWaterMl, sport, planLabel
        let legacyJson = """
        {
            "wake": "07:30",
            "bed": "23:30",
            "minMealGapMinutes": 90
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(PlanSettings.self, from: legacyJson)
        XCTAssertEqual(settings.wake, "07:30")
        XCTAssertEqual(settings.bed, "23:30")
        XCTAssertEqual(settings.minMealGapMinutes, 90)
        XCTAssertEqual(settings.targetWaterMl, 3000.0, "Missing targetWaterMl must default to 3000.0")
        XCTAssertNil(settings.minWaterMl)
        XCTAssertNil(settings.sport)
        XCTAssertNil(settings.planLabel)

        // New JSON with all fields
        let newJson = """
        {
            "wake": "10:30",
            "bed": "23:30",
            "minMealGapMinutes": 60,
            "targetWaterMl": 3000,
            "minWaterMl": 2500,
            "sport": "Τεχνική Κολύμβηση",
            "planLabel": "Πρόγραμμα #1 (11.11.26)"
        }
        """.data(using: .utf8)!

        let newSettings = try JSONDecoder().decode(PlanSettings.self, from: newJson)
        XCTAssertEqual(newSettings.wake, "10:30")
        XCTAssertEqual(newSettings.targetWaterMl, 3000.0)
        XCTAssertEqual(newSettings.minWaterMl, 2500.0)
        XCTAssertEqual(newSettings.sport, "Τεχνική Κολύμβηση")
        XCTAssertEqual(newSettings.planLabel, "Πρόγραμμα #1 (11.11.26)")
    }

    // MARK: - 4. LogEntry Menu Selection Tracking

    func testLogEntryWithOptionSelection() throws {
        let entry = LogEntry(
            eventKey: "evt.lunch.20261102",
            itemId: "lunch",
            status: .done,
            kcal: 450.0,
            protein: 40.0,
            selectedOptionId: "opt_1",
            selectedOptionTitle: "Option 1 (Chicken)"
        )
        XCTAssertEqual(entry.selectedOptionId, "opt_1")
        XCTAssertEqual(entry.selectedOptionTitle, "Option 1 (Chicken)")

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(LogEntry.self, from: data)
        XCTAssertEqual(decoded.selectedOptionId, "opt_1")
        XCTAssertEqual(decoded.selectedOptionTitle, "Option 1 (Chicken)")
    }

    // MARK: - 5. HydrationDay & ReportExportEngine 3000ml Target

    func testHydrationDayDefaultTarget3000ml() {
        let hydration = HydrationDay()
        XCTAssertEqual(hydration.targetMl, 3000.0, "Default target must be 3000 ml")
        XCTAssertEqual(hydration.remainingMl, 3000.0)
        XCTAssertEqual(hydration.litersTarget, 3.0)
    }

    func testReportExportEngineTargetWaterMlParameter() {
        let record = DailyReportRecord(
            dateString: "2026-11-02",
            templateKey: "training",
            kcalConsumed: 2200,
            kcalBurned: 2600,
            balanceKcal: -400,
            proteinGrams: 160.0,
            carbsGrams: 220.0,
            fatGrams: 50.0,
            waterMl: 3000,
            sleepHours: 8.0,
            sleepRecoveryScore: 90,
            adherencePercent: 100
        )

        let summary = ReportExportEngine.generateCoachSummary(records: [record], targetWaterMl: 3000.0)
        XCTAssertTrue(summary.contains("3000 ml / 3000 ml"), "Summary must reflect targetWaterMl parameter")
    }

    // MARK: - 6. ScheduleResolver: Day-of-Week Filter, Multi-Session & Deterministic Sort

    func testScheduleResolverDayOfWeekFilter() {
        let plan = Plan(
            settings: PlanSettings(wake: "10:30", bed: "23:30"),
            weekly: ["mon": "training", "wed": "training"],
            templates: [
                "training": DayTemplate(
                    trainingSessions: [TrainingSession(start: "14:30", durationMinutes: 120)],
                    items: [
                        PlanItem(
                            id: "daily_meal",
                            type: .meal,
                            title: "Daily Meal",
                            anchor: .afterWake(minutes: 0)
                        ),
                        PlanItem(
                            id: "wed_fri_iron",
                            type: .supplement,
                            title: "Ferro Sanol (Wed/Fri only)",
                            anchor: .afterTraining(minutes: 45),
                            activeWeekdays: [.wed, .fri]
                        ),
                        PlanItem(
                            id: "attached_to_iron",
                            type: .supplement,
                            title: "Vitamin C with Iron",
                            anchor: .withItem(itemId: "wed_fri_iron")
                        )
                    ]
                )
            ]
        )

        // Monday (2026-11-02) -> wed_fri_iron should be excluded, and attached_to_iron should be excluded!
        let monday = makeDate(day: 2) // Monday
        XCTAssertEqual(Weekday.from(date: monday, calendar: calendar), .mon)

        let mondayEvents = ScheduleResolver.resolve(date: monday, plan: plan, calendar: calendar)
        XCTAssertEqual(mondayEvents.count, 1)
        XCTAssertEqual(mondayEvents.first?.itemId, "daily_meal")

        // Wednesday (2026-11-04) -> wed_fri_iron included, attached_to_iron included!
        let wednesday = makeDate(day: 4) // Wednesday
        XCTAssertEqual(Weekday.from(date: wednesday, calendar: calendar), .wed)

        let wedEvents = ScheduleResolver.resolve(date: wednesday, plan: plan, calendar: calendar)
        XCTAssertEqual(wedEvents.count, 3)
        let itemIds = wedEvents.map { $0.itemId }
        XCTAssertTrue(itemIds.contains("wed_fri_iron"))
        XCTAssertTrue(itemIds.contains("attached_to_iron"))
    }

    func testScheduleResolverMultiSessionDoubleTraining() {
        let sessionMorning = TrainingSession(start: "08:30", durationMinutes: 90, title: "Morning Swim")
        let sessionAfternoon = TrainingSession(start: "14:30", durationMinutes: 120, title: "Afternoon Swim")

        let plan = Plan(
            settings: PlanSettings(wake: "07:00", bed: "23:30"),
            weekly: ["mon": "double_training"],
            templates: [
                "double_training": DayTemplate(
                    trainingSessions: [sessionMorning, sessionAfternoon],
                    items: [
                        PlanItem(
                            id: "pre_morning",
                            type: .meal,
                            title: "Pre Morning",
                            anchor: .beforeTraining(minutes: 30),
                            sessionIndex: 0
                        ),
                        PlanItem(
                            id: "post_morning",
                            type: .meal,
                            title: "Post Morning",
                            anchor: .afterTraining(minutes: 15),
                            sessionIndex: 0
                        ),
                        PlanItem(
                            id: "pre_afternoon",
                            type: .meal,
                            title: "Pre Afternoon",
                            anchor: .beforeTraining(minutes: 30),
                            sessionIndex: 1
                        ),
                        PlanItem(
                            id: "post_afternoon",
                            type: .meal,
                            title: "Post Afternoon",
                            anchor: .afterTraining(minutes: 15),
                            sessionIndex: 1
                        )
                    ]
                )
            ]
        )

        let monday = makeDate(day: 2)
        let events = ScheduleResolver.resolve(date: monday, plan: plan, calendar: calendar)

        let preM = try! XCTUnwrap(events.first { $0.itemId == "pre_morning" })
        XCTAssertEqual(calendar.component(.hour, from: preM.resolvedTime), 8)
        XCTAssertEqual(calendar.component(.minute, from: preM.resolvedTime), 0) // 08:30 - 30m = 08:00

        let postM = try! XCTUnwrap(events.first { $0.itemId == "post_morning" })
        XCTAssertEqual(calendar.component(.hour, from: postM.resolvedTime), 10)
        XCTAssertEqual(calendar.component(.minute, from: postM.resolvedTime), 15) // 08:30 + 90m + 15m = 10:15

        let preA = try! XCTUnwrap(events.first { $0.itemId == "pre_afternoon" })
        XCTAssertEqual(calendar.component(.hour, from: preA.resolvedTime), 14)
        XCTAssertEqual(calendar.component(.minute, from: preA.resolvedTime), 0) // 14:30 - 30m = 14:00

        let postA = try! XCTUnwrap(events.first { $0.itemId == "post_afternoon" })
        XCTAssertEqual(calendar.component(.hour, from: postA.resolvedTime), 16)
        XCTAssertEqual(calendar.component(.minute, from: postA.resolvedTime), 45) // 14:30 + 120m + 15m = 16:45
    }

    func testScheduleResolverConflictCheckingIgnoresOptionalItems() {
        let plan = Plan(
            settings: PlanSettings(wake: "10:30", bed: "23:30", minMealGapMinutes: 60),
            weekly: ["mon": "test_optional"],
            templates: [
                "test_optional": DayTemplate(
                    items: [
                        PlanItem(id: "meal_1", type: .meal, title: "Meal 1", anchor: .absolute(time: "12:00")),
                        PlanItem(id: "optional_snack", type: .meal, title: "Optional Garnish", anchor: .absolute(time: "12:15"), isOptional: true),
                        PlanItem(id: "meal_2", type: .meal, title: "Meal 2", anchor: .absolute(time: "13:00"))
                    ]
                )
            ]
        )

        let monday = makeDate(day: 2)
        let events = ScheduleResolver.resolve(date: monday, plan: plan, calendar: calendar)

        let optEvent = try! XCTUnwrap(events.first { $0.itemId == "optional_snack" })
        XCTAssertFalse(optEvent.hasConflict, "Optional items must never trigger conflict")

        let meal2 = try! XCTUnwrap(events.first { $0.itemId == "meal_2" })
        XCTAssertFalse(meal2.hasConflict, "Meal 2 is 60 min after Meal 1 (ignoring optional snack at 12:15), so no conflict")
    }

    // MARK: - 7. AppleProgress: Optional Items & SupplementProgress

    func testAppleProgressExcludesUnloggedOptionalMeals() {
        let now = makeDate(hour: 15) // 15:00

        let itemMandatory = PlanItem(id: "m_mand", type: .meal, title: "Mandatory Meal", anchor: .absolute(time: "12:00"), kcal: 500)
        let itemOptional = PlanItem(id: "m_opt", type: .meal, title: "Optional Snack", anchor: .absolute(time: "13:00"), kcal: 300, isOptional: true)

        let eventMandatory = ScheduledEvent(id: "evt.1", itemId: "m_mand", item: itemMandatory, date: now, resolvedTime: makeDate(hour: 12))
        let eventOptional = ScheduledEvent(id: "evt.2", itemId: "m_opt", item: itemOptional, date: now, resolvedTime: makeDate(hour: 13))

        // Case 1: Optional meal unlogged -> MUST NOT be in slices or overdue
        let progressUnlogged = AppleProgress.calculate(
            events: [eventMandatory, eventOptional],
            logEntries: [],
            referenceDate: now
        )
        XCTAssertEqual(progressUnlogged.slices.count, 1)
        XCTAssertEqual(progressUnlogged.slices.first?.itemId, "m_mand")
        XCTAssertEqual(progressUnlogged.overdueCount, 1)
        XCTAssertEqual(progressUnlogged.totalPlannedKcal, 500.0)

        // Case 2: Optional meal logged -> counted in eaten calories
        let optLog = LogEntry(eventKey: "evt.2", itemId: "m_opt", status: .done, kcal: 300.0)
        let progressLogged = AppleProgress.calculate(
            events: [eventMandatory, eventOptional],
            logEntries: [optLog],
            referenceDate: now
        )
        XCTAssertEqual(progressLogged.totalEatenKcal, 300.0)
    }

    func testSupplementProgressCalculation() {
        let suppMandatory1 = PlanItem(id: "s1", type: .supplement, title: "V2000", anchor: .afterWake(minutes: 0))
        let suppMandatory2 = PlanItem(id: "s2", type: .supplement, title: "Solumag", anchor: .beforeSleep(minutes: 30))
        let suppOptional = PlanItem(id: "s_opt", type: .supplement, title: "Optional Supp", anchor: .afterWake(minutes: 10), isOptional: true)

        let ev1 = ScheduledEvent(id: "evt.s1", itemId: "s1", item: suppMandatory1, date: Date(), resolvedTime: Date())
        let ev2 = ScheduledEvent(id: "evt.s2", itemId: "s2", item: suppMandatory2, date: Date(), resolvedTime: Date())
        let evOpt = ScheduledEvent(id: "evt.s_opt", itemId: "s_opt", item: suppOptional, date: Date(), resolvedTime: Date())

        let events = [ev1, ev2, evOpt]

        // 0 of 2 completed
        let prog0 = AppleProgress.calculateSupplements(events: events, logEntries: [])
        XCTAssertEqual(prog0.total, 2, "Only mandatory supplements counted")
        XCTAssertEqual(prog0.completed, 0)
        XCTAssertFalse(prog0.isCompleted)

        // 1 of 2 completed
        let log1 = LogEntry(eventKey: "evt.s1", itemId: "s1", status: .done)
        let prog1 = AppleProgress.calculateSupplements(events: events, logEntries: [log1])
        XCTAssertEqual(prog1.completed, 1)
        XCTAssertFalse(prog1.isCompleted)

        // 2 of 2 completed
        let log2 = LogEntry(eventKey: "evt.s2", itemId: "s2", status: .done)
        let prog2 = AppleProgress.calculateSupplements(events: events, logEntries: [log1, log2])
        XCTAssertEqual(prog2.completed, 2)
        XCTAssertTrue(prog2.isCompleted)
    }

    // MARK: - 8. PlanDraftValidator New Checks

    func testPlanDraftValidatorTargetWaterAndOptionsChecks() {
        let plan = Plan(
            settings: PlanSettings(wake: "10:30", bed: "23:30", targetWaterMl: 0), // Invalid water target <= 0
            weekly: ["mon": "t1"],
            templates: [
                "t1": DayTemplate(
                    items: [
                        PlanItem(
                            id: "item1",
                            type: .meal,
                            title: "Meal",
                            anchor: .afterWake(minutes: 0),
                            options: [
                                PlanOption(id: "opt_dup", title: "Option A"),
                                PlanOption(id: "opt_dup", title: "Option B") // Duplicate ID!
                            ]
                        )
                    ]
                )
            ]
        )

        let result = PlanDraftValidator.validate(plan: plan)
        XCTAssertFalse(result.isValid)
        if case .invalid(let reasons) = result {
            XCTAssertTrue(reasons.contains { $0.contains("targetWaterMl") || $0.contains("water") })
            XCTAssertTrue(reasons.contains { $0.contains("opt_dup") })
        } else {
            XCTFail("Expected validation failure")
        }
    }

    // MARK: - 9. PeriWorkoutEngine Protocol Texts

    func testPeriWorkoutEngineProtocolTexts() {
        let intraText = PeriWorkoutPhase.intraWorkoutHydration.nutrientFocusGreek
        XCTAssertTrue(intraText.contains("500ml νερό + 1 κοφτή μεζούρα HIGH5 ηλεκτρολύτες + υγρά BCAA (1-2 καπάκια)"), "Intra-workout hydration must match protocol text")

        let postAnabolicText = PeriWorkoutPhase.postWorkoutAnabolic.nutrientFocusGreek
        XCTAssertTrue(postAnabolicText.contains("2ο 500άρι HIGH5 + BCAA, 30g Πρωτεΐνη AFTER + 1 μεζούρα γλουταμίνη"), "Post-workout anabolic window must match protocol text")
    }

    // MARK: - 10. StapleFoodLibrary Extended Items

    func testStapleFoodLibraryNewAthleticItems() {
        XCTAssertGreaterThanOrEqual(StapleFoodLibrary.items.count, 26, "Must contain 15 legacy + 11 new staples = 26 items")

        let expectedNames = [
            "Κινόα", "Πίτουρο Βρώμης", "Τυρί Cottage", "Ανθότυρο", "Φέτα",
            "Ψητή Γαλοπούλα", "Ταχίνι", "Κρέμα Αμυγδάλου", "Μπιφτέκι Μοσχαρίσιο",
            "Πρωτεΐνη AFTER", "Ομελέτα Βρώμης"
        ]

        for expected in expectedNames {
            let found = StapleFoodLibrary.search(query: expected)
            XCTAssertFalse(found.isEmpty, "Missing staple food item in library: \(expected)")
        }
    }

    // MARK: - 11. Shakes Type & Supplement Ring Integrity (Coordinator Defect A & B)

    private func loadRealPlan() throws -> Plan {
        let currentFileUrl = URL(fileURLWithPath: #filePath)
        let rootDir = currentFileUrl.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let realPlanUrl = rootDir.appendingPathComponent("plan.json")
        let data = try Data(contentsOf: realPlanUrl)
        return try JSONDecoder().decode(Plan.self, from: data)
    }

    func testTrainingShakesAreSupplementsWithProteinAndWater() throws {
        let plan = try loadRealPlan()

        guard let training = plan.templates["training"] else {
            XCTFail("Missing training template")
            return
        }

        guard let morningHydration = training.items.first(where: { $0.id == "morning_hydration" }) else {
            XCTFail("Missing morning_hydration item")
            return
        }
        XCTAssertEqual(morningHydration.type, PlanItemType.supplement, "morning_hydration must be .supplement (suppl. ΕΝΑΡΞΗΣ), not .meal")
        XCTAssertEqual(morningHydration.waterMl, 500.0)
        XCTAssertGreaterThan(morningHydration.protein ?? 0, 15.0, "morning_hydration contains 20g AFTER protein")

        guard let postWorkoutShake = training.items.first(where: { $0.id == "post_workout_shake" }) else {
            XCTFail("Missing post_workout_shake item")
            return
        }
        XCTAssertEqual(postWorkoutShake.type, PlanItemType.supplement, "post_workout_shake must be .supplement, not .meal")
        XCTAssertEqual(postWorkoutShake.waterMl, 500.0)
        XCTAssertGreaterThan(postWorkoutShake.protein ?? 0, 25.0, "post_workout_shake contains 30g AFTER protein")

        if let doubleTraining = plan.templates["double_training"] {
            let dtShake = doubleTraining.items.first { $0.id == "dt_morn_post_shake" }
            XCTAssertEqual(dtShake?.type, PlanItemType.supplement, "dt_morn_post_shake must be .supplement")
        }

        if let raceDay = plan.templates["race_day"] {
            let rdShake = raceDay.items.first { $0.id == "rd_post_race_shake" }
            XCTAssertEqual(rdShake?.type, PlanItemType.supplement, "rd_post_race_shake must be .supplement")
        }
    }

    func testTrainingScheduleHasZeroMealGapConflictsIncludingSandwich() throws {
        let plan = try loadRealPlan()

        // Test Monday (no ferro_sanol)
        let mondayDate = makeDate(year: 2026, month: 11, day: 2, hour: 10, minute: 0) // Monday
        let mondayEvents = ScheduleResolver.resolve(
            date: mondayDate,
            plan: plan,
            calendar: calendar
        )

        let mondayConflicts = mondayEvents.filter { $0.conflictReason != nil }
        XCTAssertTrue(mondayConflicts.isEmpty, "Schedule must have 0 conflicts. Found: \(mondayConflicts.map { "\($0.item.title): \($0.conflictReason ?? "")" })")

        // Test Wednesday (with ferro_sanol)
        let wednesdayDate = makeDate(year: 2026, month: 11, day: 4, hour: 10, minute: 0) // Wednesday
        let wednesdayEvents = ScheduleResolver.resolve(
            date: wednesdayDate,
            plan: plan,
            calendar: calendar
        )

        let wednesdayConflicts = wednesdayEvents.filter { $0.conflictReason != nil }
        XCTAssertTrue(wednesdayConflicts.isEmpty, "Wednesday schedule must have 0 conflicts. Found: \(wednesdayConflicts.map { "\($0.item.title): \($0.conflictReason ?? "")" })")
    }

    func testSupplementProgressCountReturnsSixAndSevenOnFerroDays() throws {
        let plan = try loadRealPlan()

        // Monday (non-Wed/Fri): 6 supplements
        let mondayDate = makeDate(year: 2026, month: 11, day: 2, hour: 10, minute: 0)
        let mondayEvents = ScheduleResolver.resolve(
            date: mondayDate,
            plan: plan,
            calendar: calendar
        )

        let mondaySuppProgress = AppleProgress.calculateSupplements(
            events: mondayEvents,
            logEntries: []
        )
        XCTAssertEqual(mondaySuppProgress.total, 6, "Monday must have 6 total supplements (v2000, morning_hydration, pre_workout_supp, post_workout_shake, vit_c, bedtime_magnesium)")

        // Wednesday (Wed/Fri): 7 supplements (includes ferro_sanol)
        let wednesdayDate = makeDate(year: 2026, month: 11, day: 4, hour: 10, minute: 0)
        let wednesdayEvents = ScheduleResolver.resolve(
            date: wednesdayDate,
            plan: plan,
            calendar: calendar
        )

        let wednesdaySuppProgress = AppleProgress.calculateSupplements(
            events: wednesdayEvents,
            logEntries: []
        )
        XCTAssertEqual(wednesdaySuppProgress.total, 7, "Wednesday must have 7 total supplements (+ ferro_sanol)")
    }
}
