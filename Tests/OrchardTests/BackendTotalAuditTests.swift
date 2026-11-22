import XCTest
import Foundation
@testable import OrchardDomain
@testable import OrchardServices

#if !SWIFT_PACKAGE
@testable import Orchard
#endif

/// Comprehensive backend, domain, services, and AppContainer QA audit suite.
/// Covers Swift 6 strict concurrency, edge cases, macro sanity, schedule matrices, and idempotency contracts.
final class BackendTotalAuditTests: XCTestCase {

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

    private func loadPlanJsonData() throws -> Data {
        let paths = [
            "/Users/john_ak/antigarvity/Orchard/Resources/plan.json",
            "/Users/john_ak/antigarvity/Orchard/plan.json"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return try Data(contentsOf: URL(fileURLWithPath: path))
            }
        }
        XCTFail("plan.json not found in expected repository paths")
        throw CocoaError(.fileNoSuchFile)
    }

    private func loadRealPlan() throws -> Plan {
        let data = try loadPlanJsonData()
        return try JSONDecoder().decode(Plan.self, from: data)
    }

    // MARK: - 1. Plan Schema & Macro Sanity Audit

    func testResourcesPlanJsonAndRootPlanJsonAreByteIdentical() throws {
        let p1 = "/Users/john_ak/antigarvity/Orchard/Resources/plan.json"
        let p2 = "/Users/john_ak/antigarvity/Orchard/plan.json"
        guard FileManager.default.fileExists(atPath: p1), FileManager.default.fileExists(atPath: p2) else {
            XCTFail("Both plan.json and Resources/plan.json must exist")
            return
        }
        let d1 = try Data(contentsOf: URL(fileURLWithPath: p1))
        let d2 = try Data(contentsOf: URL(fileURLWithPath: p2))
        XCTAssertEqual(d1, d2, "Resources/plan.json and plan.json must be byte-for-byte identical")
    }

    func testAllTemplatesExistAndHaveValidSettings() throws {
        let plan = try loadRealPlan()
        XCTAssertEqual(plan.settings.targetWaterMl, 3000.0)
        XCTAssertEqual(plan.settings.minMealGapMinutes, 60)

        let requiredTemplates = ["training", "double_training", "pre_race", "race_day", "rest"]
        for tKey in requiredTemplates {
            XCTAssertNotNil(plan.templates[tKey], "Template '\(tKey)' must be present in plan.json")
        }
    }

    func testEveryItemAndOptionMacroMathConsistency() throws {
        let plan = try loadRealPlan()

        for (tKey, template) in plan.templates {
            for item in template.items {
                // Item level macros
                if let kcal = item.kcal, kcal > 0 {
                    let p = item.protein ?? 0
                    let c = item.carbs ?? 0
                    let f = item.fat ?? 0
                    let calcKcal = 4.0 * p + 4.0 * c + 9.0 * f
                    let diff = abs(calcKcal - kcal) / kcal
                    XCTAssertLessThanOrEqual(
                        diff,
                        0.25,
                        "Macro mismatch on template '\(tKey)', item '\(item.id)': declared \(kcal), calculated \(calcKcal) (P:\(p), C:\(c), F:\(f))"
                    )
                }

                // Options level macros
                if let options = item.options {
                    var optionIds = Set<String>()
                    for opt in options {
                        XCTAssertFalse(opt.id.isEmpty, "Option id must not be empty in item '\(item.id)'")
                        XCTAssertFalse(opt.title.isEmpty, "Option title must not be empty in item '\(item.id)'")
                        XCTAssertFalse(
                            optionIds.contains(opt.id),
                            "Duplicate option id '\(opt.id)' in item '\(item.id)' of template '\(tKey)'"
                        )
                        optionIds.insert(opt.id)

                        if let okcal = opt.kcal, okcal > 0 {
                            let op = opt.protein ?? 0
                            let oc = opt.carbs ?? 0
                            let of = opt.fat ?? 0
                            let calcOkcal = 4.0 * op + 4.0 * oc + 9.0 * of
                            let diff = abs(calcOkcal - okcal) / okcal
                            XCTAssertLessThanOrEqual(
                                diff,
                                0.25,
                                "Macro mismatch on template '\(tKey)', item '\(item.id)', option '\(opt.id)': declared \(okcal), calculated \(calcOkcal)"
                            )
                        }
                    }
                }
            }
        }
    }

    func testAllWithItemAnchorsPointToExistingParents() throws {
        let plan = try loadRealPlan()

        for (tKey, template) in plan.templates {
            let itemIds = Set(template.items.map { $0.id })
            for item in template.items {
                if case .withItem(let parentId) = item.anchor {
                    XCTAssertTrue(
                        itemIds.contains(parentId),
                        "Template '\(tKey)' item '\(item.id)' has dangling withItem parent '\(parentId)'"
                    )
                }
            }
        }
    }

    func testPlanDraftValidatorAcceptance() throws {
        let plan = try loadRealPlan()
        let result = PlanDraftValidator.validate(plan: plan)
        XCTAssertEqual(result, .valid, "Real plan must pass PlanDraftValidator with .valid")

        // Negative check: invalid targetWaterMl
        var invalidSettingsPlan = plan
        invalidSettingsPlan.settings.targetWaterMl = -100
        let invalidResult = PlanDraftValidator.validate(plan: invalidSettingsPlan)
        if case .invalid(let reasons) = invalidResult {
            XCTAssertTrue(reasons.contains { $0.contains("targetWaterMl") })
        } else {
            XCTFail("Negative targetWaterMl should produce .invalid validation result")
        }
    }

    // MARK: - 2. ScheduleResolver Full 7 Days × 5 Templates Matrix Audit

    func testFerroSanolOnlyOnWednesdayAndFridayAcrossAllTemplates() throws {
        let plan = try loadRealPlan()
        // Dates: Nov 2 = Mon, Nov 3 = Tue, Nov 4 = Wed, Nov 5 = Thu, Nov 6 = Fri, Nov 7 = Sat, Nov 8 = Sun
        let testDays: [(dayName: String, dayNum: Int, isFerroDay: Bool)] = [
            ("Monday", 2, false),
            ("Tuesday", 3, false),
            ("Wednesday", 4, true),
            ("Thursday", 5, false),
            ("Friday", 6, true),
            ("Saturday", 7, false),
            ("Sunday", 8, false)
        ]

        let templateKeys = ["training", "double_training", "pre_race", "race_day", "rest"]

        for tKey in templateKeys {
            for (dayName, dayNum, isFerroDay) in testDays {
                let testDate = makeDate(year: 2026, month: 11, day: dayNum, hour: 10, minute: 0)
                let events = ScheduleResolver.resolve(
                    date: testDate,
                    plan: plan,
                    selectedTemplateName: tKey,
                    calendar: calendar
                )

                let ferroEvents = events.filter {
                    $0.itemId.contains("ferro") || $0.item.title.contains("Ferro") || $0.item.title.contains("ferro")
                }

                if tKey == "race_day" {
                    // race_day has no ferro items planned at all
                    XCTAssertTrue(
                        ferroEvents.isEmpty,
                        "Race day should never have ferro sanol on \(dayName)"
                    )
                } else if isFerroDay {
                    XCTAssertFalse(
                        ferroEvents.isEmpty,
                        "Template '\(tKey)' must resolve ferro_sanol on \(dayName)"
                    )
                } else {
                    XCTAssertTrue(
                        ferroEvents.isEmpty,
                        "Template '\(tKey)' must NOT resolve ferro_sanol on \(dayName). Found: \(ferroEvents.map { $0.itemId })"
                    )
                }
            }
        }
    }

    func testZeroMealGapConflictsAcrossAllTemplatesAndAllWeekdays() throws {
        let plan = try loadRealPlan()
        let templateKeys = ["training", "double_training", "pre_race", "race_day", "rest"]

        for tKey in templateKeys {
            for dayNum in 2...8 {
                let testDate = makeDate(year: 2026, month: 11, day: dayNum, hour: 10, minute: 0)
                let events = ScheduleResolver.resolve(
                    date: testDate,
                    plan: plan,
                    selectedTemplateName: tKey,
                    calendar: calendar
                )

                let conflicts = events.filter { $0.hasConflict }
                XCTAssertTrue(
                    conflicts.isEmpty,
                    "Conflict detected in template '\(tKey)' on day \(dayNum): \(conflicts.map { "\($0.item.title): \($0.conflictReason ?? "")" })"
                )
            }
        }
    }

    func testDoubleTrainingSessionIndexAndShiftRipple() throws {
        let plan = try loadRealPlan()
        XCTAssertNotNil(plan.templates["double_training"], "double_training template required")

        // 1. Base resolution: session 0 (10:00-11:30), session 1 (16:30-18:00)
        let baseDate = makeDate(year: 2026, month: 11, day: 2, hour: 8, minute: 0)
        let baseEvents = ScheduleResolver.resolve(
            date: baseDate,
            plan: plan,
            selectedTemplateName: "double_training",
            calendar: calendar
        )

        let baseMornShake = baseEvents.first { $0.itemId == "dt_morn_post_shake" }
        let baseAftShake = baseEvents.first { $0.itemId == "dt_after_post_shake" }
        XCTAssertNotNil(baseMornShake)
        XCTAssertNotNil(baseAftShake)

        // 2. Custom actual trainings: shift session 0 from 08:30 to 07:30 (ends 09:00, 60 min earlier), session 1 stays 14:30 (ends 16:30)
        let shiftedSession0 = [
            TrainingSession(start: "07:30", durationMinutes: 90, estKcal: 650),
            TrainingSession(start: "14:30", durationMinutes: 120, estKcal: 850)
        ]

        let shiftedEvents = ScheduleResolver.resolve(
            date: baseDate,
            plan: plan,
            selectedTemplateName: "double_training",
            actualTrainings: shiftedSession0,
            calendar: calendar
        )

        let shiftedMornShake = shiftedEvents.first { $0.itemId == "dt_morn_post_shake" }
        let shiftedAftShake = shiftedEvents.first { $0.itemId == "dt_after_post_shake" }

        // Morning shake should have moved earlier by 60 minutes
        let mornTimeDiff = (baseMornShake?.resolvedTime.timeIntervalSince(shiftedMornShake?.resolvedTime ?? Date()) ?? 0)
        XCTAssertEqual(mornTimeDiff, 3600, accuracy: 1.0, "Morning shake must shift earlier with session 0")

        // Afternoon shake should NOT have moved
        let aftTimeDiff = abs(baseAftShake?.resolvedTime.timeIntervalSince(shiftedAftShake?.resolvedTime ?? Date()) ?? 0)
        XCTAssertEqual(aftTimeDiff, 0, accuracy: 1.0, "Afternoon shake must not shift when only session 0 moved")
    }

    func testMidnightBedtimeCrossover() {
        let plan = Plan(
            settings: PlanSettings(
                wake: "10:30",
                bed: "00:30", // Crossover past midnight
                minMealGapMinutes: 60,
                targetWaterMl: 3000.0
            ),
            weekly: ["mon": "training"],
            templates: [
                "training": DayTemplate(
                    title: "Training",
                    trainingSessions: [TrainingSession(start: "14:00", durationMinutes: 120)],
                    items: [
                        PlanItem(id: "bedtime_item", type: .supplement, title: "Magnesium", anchor: .beforeSleep(minutes: 60))
                    ]
                )
            ]
        )

        let date = makeDate(year: 2026, month: 11, day: 2, hour: 10, minute: 0)
        let events = ScheduleResolver.resolve(date: date, plan: plan, calendar: calendar)

        XCTAssertEqual(events.count, 1)
        let resolvedTime = events[0].resolvedTime
        let hour = calendar.component(.hour, from: resolvedTime)
        let minute = calendar.component(.minute, from: resolvedTime)

        // 00:30 next day minus 60 min is 23:30 of the base day
        XCTAssertEqual(hour, 23)
        XCTAssertEqual(minute, 30)
    }

    func testEmptyTrainingSessionsFallback() {
        let plan = Plan(
            settings: PlanSettings(wake: "08:00", bed: "23:00", minMealGapMinutes: 60, targetWaterMl: 3000.0),
            weekly: ["mon": "rest"],
            templates: [
                "rest": DayTemplate(
                    title: "Rest",
                    trainingSessions: [], // Empty sessions
                    items: [
                        PlanItem(
                            id: "fallback_item",
                            type: .meal,
                            title: "Lunch",
                            anchor: .beforeTraining(minutes: 120),
                            fallbackTime: "13:00"
                        )
                    ]
                )
            ]
        )

        let date = makeDate(year: 2026, month: 11, day: 2, hour: 8, minute: 0)
        let events = ScheduleResolver.resolve(date: date, plan: plan, calendar: calendar)

        XCTAssertEqual(events.count, 1)
        let hour = calendar.component(.hour, from: events[0].resolvedTime)
        let minute = calendar.component(.minute, from: events[0].resolvedTime)
        XCTAssertEqual(hour, 13)
        XCTAssertEqual(minute, 0)
    }

    // MARK: - 3. CalorieEngine & AppleProgress Consistency

    func testProteinShakeSupplementContributesToConsumedKcalAndMacros() {
        let shake = PlanItem(
            id: "protein_shake",
            type: .supplement,
            title: "500ml HIGH5 + 30g Protein AFTER",
            anchor: .afterTraining(minutes: 0),
            kcal: 120.0,
            protein: 30.0,
            carbs: 0.0,
            fat: 0.0,
            waterMl: 500.0
        )

        let logEntry = LogEntry(
            eventKey: "evt_shake",
            itemId: "protein_shake",
            status: .done,
            timestamp: Date(),
            kcal: 120.0,
            protein: 30.0,
            carbs: 0.0,
            fat: 0.0,
            source: .plan
        )

        let items = ["protein_shake": shake]
        let consumedKcal = CalorieEngine.consumedKcal(entries: [logEntry], items: items)
        let consumedMacros = CalorieEngine.consumedMacros(entries: [logEntry], items: items)

        XCTAssertEqual(consumedKcal, 120.0)
        XCTAssertEqual(consumedMacros.protein, 30.0)
        XCTAssertEqual(consumedMacros.kcal, 120.0)
    }

    func testAppleProgressOptionalItemsDoNotSkewMandatorySlices() {
        let mandatoryMeal = PlanItem(id: "main_meal", type: .meal, title: "Main Meal", anchor: .afterWake(minutes: 60), kcal: 700.0, isOptional: false)
        let optionalSide = PlanItem(id: "side_dish", type: .meal, title: "Side Dish", anchor: .afterWake(minutes: 60), kcal: 200.0, isOptional: true)

        let date = makeDate()
        let events = [
            ScheduledEvent(id: "e1", itemId: "main_meal", item: mandatoryMeal, date: date, resolvedTime: date),
            ScheduledEvent(id: "e2", itemId: "side_dish", item: optionalSide, date: date, resolvedTime: date)
        ]

        // 1. Unlogged: only mandatory meal is in slices
        let progressUnlogged = AppleProgress.calculate(events: events, logEntries: [], referenceDate: date)
        XCTAssertEqual(progressUnlogged.slices.count, 1)
        XCTAssertEqual(progressUnlogged.totalPlannedKcal, 700.0)

        // 2. Logged optional side: now enters slices and adds to eaten calories
        let logSide = LogEntry(eventKey: "e2", itemId: "side_dish", status: .done, kcal: 200.0)
        let progressLogged = AppleProgress.calculate(events: events, logEntries: [logSide], referenceDate: date)
        XCTAssertEqual(progressLogged.slices.count, 2)
        XCTAssertEqual(progressLogged.totalEatenKcal, 200.0)
    }

    func testSupplementProgressCalculationSixAndSevenCounts() throws {
        let plan = try loadRealPlan()

        // Monday (6 supplements)
        let monDate = makeDate(year: 2026, month: 11, day: 2, hour: 10, minute: 0)
        let monEvents = ScheduleResolver.resolve(date: monDate, plan: plan, calendar: calendar)
        let monSupps = AppleProgress.calculateSupplements(events: monEvents, logEntries: [])
        XCTAssertEqual(monSupps.total, 6)

        // Wednesday (7 supplements)
        let wedDate = makeDate(year: 2026, month: 11, day: 4, hour: 10, minute: 0)
        let wedEvents = ScheduleResolver.resolve(date: wedDate, plan: plan, calendar: calendar)
        let wedSupps = AppleProgress.calculateSupplements(events: wedEvents, logEntries: [])
        XCTAssertEqual(wedSupps.total, 7)
    }

    // MARK: - 4. Services Audit

    func testGeminiLLMProviderMetadataAndChain() {
        XCTAssertEqual(GeminiLLMProvider.defaultFreeModelChain.count, 12)
        XCTAssertTrue(GeminiLLMProvider.defaultFreeModelChain.contains("gemini-3.7-flash"))
        XCTAssertTrue(GeminiLLMProvider.defaultFreeModelChain.contains("gemini-2.5-flash"))
        XCTAssertTrue(GeminiLLMProvider.defaultFreeModelChain.contains("gemini-1.5-flash"))

        let metadata = GeminiLLMProvider.availableModelMetadata
        XCTAssertEqual(metadata.count, 12)
        for m in metadata {
            XCTAssertFalse(m.id.isEmpty)
            XCTAssertFalse(m.displayName.isEmpty)
            XCTAssertGreaterThan(m.rpmFree, 0)
        }
    }

    func testGeminiLLMProviderMissingKeyFailsGracefully() async throws {
        let provider = GeminiLLMProvider(apiKey: "")
        let result = try await provider.testConnection()
        XCTAssertFalse(result.isSuccess)
        XCTAssertTrue(result.message.contains("Keychain"))
    }

    func testLLMRouterProviderPriorityAndKillSwitch() async throws {
        let mock = MockLLMProvider()
        let router = LLMRouter(gemini: nil, appleOnDevice: nil, cloud: nil, mock: mock, isEnabled: true)
        let active = await router.activeProvider()
        XCTAssertEqual(active?.id, "mock")

        let disabledRouter = LLMRouter(gemini: nil, appleOnDevice: nil, cloud: nil, mock: mock, isEnabled: false)
        let disabledActive = await disabledRouter.activeProvider()
        XCTAssertNil(disabledActive)

        struct Echo: Codable, Sendable { let text: String }
        do {
            _ = try await disabledRouter.generate(prompt: "ping", schema: Echo.self)
            XCTFail("Should throw when AI is disabled")
        } catch {
            // Expected
        }
    }

    func testKeychainStoreInMemoryRoundTrip() {
        let store = KeychainStore(inMemory: true)
        XCTAssertNil(store.getAPIKey())
        store.saveAPIKey("AIzaSyTestKey123")
        XCTAssertEqual(store.getAPIKey(), "AIzaSyTestKey123")
        store.deleteAPIKey()
        XCTAssertNil(store.getAPIKey())
    }

    func testSigningGuardWarningLevels() {
        let now = Date()
        let guardNone = SigningGuard(customExpirationDate: now.addingTimeInterval(3 * 86400), referenceDate: now)
        XCTAssertEqual(guardNone.warningLevel, .none)

        let guardWarn24h = SigningGuard(customExpirationDate: now.addingTimeInterval(12 * 3600), referenceDate: now)
        XCTAssertEqual(guardWarn24h.warningLevel, .warn24h)

        let guardCritical2h = SigningGuard(customExpirationDate: now.addingTimeInterval(1 * 3600), referenceDate: now)
        XCTAssertEqual(guardCritical2h.warningLevel, .critical2h)

        let guardExpired = SigningGuard(customExpirationDate: now.addingTimeInterval(-100), referenceDate: now)
        XCTAssertEqual(guardExpired.warningLevel, .expired)
        XCTAssertTrue(guardExpired.isExpired)
    }

    func testSigningGuardNotificationSpecs() {
        let now = Date()
        let guardAlert = SigningGuard(customExpirationDate: now.addingTimeInterval(48 * 3600), referenceDate: now)
        let specs = guardAlert.makeExpiryAlertSpecs(now: now)
        XCTAssertEqual(specs.count, 2)
        XCTAssertTrue(specs.contains { $0.identifier == SigningGuard.alert24hIdentifier })
        XCTAssertTrue(specs.contains { $0.identifier == SigningGuard.alert2hIdentifier })
    }

    func testTelemetryServiceLoggingAndRotation() async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_telemetry_\(UUID().uuidString).jsonl")
        let telemetry = TelemetryService(fileURL: tempURL, maxEventCapacity: 5)

        for i in 1...8 {
            await telemetry.log(event: TelemetryEvent(type: "event_\(i)"))
        }

        let events = await telemetry.getRecentEvents(limit: 10)
        XCTAssertEqual(events.count, 5, "Should rotate to max 5 events")
        XCTAssertEqual(events.last?.type, "event_8")

        await telemetry.clearLogs()
        let cleared = await telemetry.getRecentEvents(limit: 10)
        XCTAssertTrue(cleared.isEmpty)
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testWidgetSnapshotStoreSaveAndLoad() {
        let store = WidgetSnapshotStore(userDefaults: .standard)
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
        XCTAssertEqual(loaded?.nextMealTitle, "Pre-workout Meal")
        XCTAssertEqual(loaded?.eatenKcal, 1300)
        XCTAssertEqual(loaded?.progressFraction, 0.65)
    }

    func testFakeHealthStoreIdempotentSync() async throws {
        let store = FakeHealthStore(isAuthorized: true)
        let item = PlanItem(id: "salmon", type: .meal, title: "Salmon", anchor: .afterWake(minutes: 60), kcal: 500, protein: 40)
        let entry = LogEntry(eventKey: "evt_salmon", itemId: "salmon", status: .done, kcal: 500, protein: 40)

        // First write
        let syncId1 = try await store.writeDietaryLog(entry, item: item)
        let samples1 = await store.savedSamples
        XCTAssertEqual(samples1.count, 1)
        XCTAssertEqual(samples1.first?.syncIdentifier, syncId1)

        // Second write with same entry: should replace, NOT duplicate
        let syncId2 = try await store.writeDietaryLog(entry, item: item)
        let samples2 = await store.savedSamples
        XCTAssertEqual(samples2.count, 1, "Duplicate write must replace existing sample (idempotent)")
        XCTAssertEqual(syncId1, syncId2)

        // Delete
        try await store.deleteDietaryLog(for: entry.id)
        let samplesAfterDelete = await store.savedSamples
        XCTAssertTrue(samplesAfterDelete.isEmpty)
    }

    func testReportExportEngineCSVAndCoachSummary() {
        let record = DailyReportRecord(
            dateString: "2026-11-02",
            templateKey: "training",
            kcalConsumed: 2350,
            kcalBurned: 2750,
            balanceKcal: -400,
            proteinGrams: 165.0,
            carbsGrams: 280.0,
            fatGrams: 65.0,
            waterMl: 3000,
            sleepHours: 7.5,
            sleepRecoveryScore: 88,
            adherencePercent: 95
        )

        let csv = ReportExportEngine.generateCSV(records: [record])
        XCTAssertTrue(csv.contains("Date,Template,Kcal_In,Kcal_Out"))
        XCTAssertTrue(csv.contains("2026-11-02,training,2350,2750,-400,165.0,280.0,65.0,3000,7.5,88%,95%"))

        let coachSummary = ReportExportEngine.generateCoachSummary(athleteName: "John Akrivos", records: [record])
        XCTAssertTrue(coachSummary.contains("John Akrivos"))
        XCTAssertTrue(coachSummary.contains("2350 kcal"))
        XCTAssertTrue(coachSummary.contains("165.0 g / ημέρα"))
    }

    // MARK: - 5. Phase 4 Live BYOK AI Nutrition Coach Domain & Services Tests

    func testNutritionContextBuilderUpdatedTitles() throws {
        let plan = try loadRealPlan()
        let mondayDate = makeDate(year: 2026, month: 11, day: 2, hour: 10, minute: 30)
        let resolvedEvents = ScheduleResolver.resolve(date: mondayDate, plan: plan, calendar: calendar)

        let snapshot = AICoachDailySnapshot(
            date: mondayDate,
            weekday: .mon,
            selectedTemplateKey: "training",
            resolvedEvents: resolvedEvents,
            logEntries: [],
            waterIntakeMl: 500.0,
            targetWaterMl: 3000.0,
            selectedOptionIds: [:]
        )

        let prompt = NutritionContextBuilder.buildSystemPrompt(plan: plan, snapshot: snapshot)

        // Updated titles verified
        XCTAssertTrue(prompt.contains("Ταπεράκι (Σχολή / Έξω)"), "Must contain updated Tupper title")
        XCTAssertTrue(prompt.contains("Μεσημεριανό / Κύριο Γεύμα"), "Must contain updated Main Meal title")
        XCTAssertTrue(prompt.contains("Βραδινό / Ελαφρύ Γεύμα"), "Must contain updated Light Meal title")
        XCTAssertTrue(prompt.contains("Δεκατιανό: Sandwich & Χυμός"), "Must contain updated Sandwich title")
    }

    func testAICoachServiceMissingAPIKeyThrows() async throws {
        let router = LLMRouter(gemini: nil, appleOnDevice: nil, cloud: nil, mock: nil, isEnabled: true)
        let service = AICoachService(router: router, requiresKey: true)

        let plan = try loadRealPlan()
        let snapshot = AICoachDailySnapshot(
            date: Date(),
            weekday: .mon,
            selectedTemplateKey: "training",
            waterIntakeMl: 0,
            targetWaterMl: 3000
        )

        do {
            _ = try await service.sendMessage("Έφαγα το μεσημεριανό", history: [], plan: plan, snapshot: snapshot)
            XCTFail("Must throw AICoachError.missingAPIKey when API key is missing (Zero Hallucination!)")
        } catch let error as AICoachError {
            XCTAssertEqual(error, AICoachError.missingAPIKey)
        } catch {
            XCTFail("Expected AICoachError.missingAPIKey but got \(error)")
        }
    }

    func testAICoachServiceAIDisabledThrows() async throws {
        let router = LLMRouter(gemini: nil, appleOnDevice: nil, cloud: nil, mock: nil, isEnabled: false)
        let service = AICoachService(router: router, requiresKey: false)

        let plan = try loadRealPlan()
        let snapshot = AICoachDailySnapshot(
            date: Date(),
            weekday: .mon,
            selectedTemplateKey: "training",
            waterIntakeMl: 0,
            targetWaterMl: 3000
        )

        do {
            _ = try await service.sendMessage("Πόσο νερό να πιω;", history: [], plan: plan, snapshot: snapshot)
            XCTFail("Must throw AICoachError.aiDisabled when AI is disabled")
        } catch let error as AICoachError {
            XCTAssertEqual(error, AICoachError.aiDisabled)
        } catch {
            XCTFail("Expected AICoachError.aiDisabled but got \(error)")
        }
    }

    func testAICoachResponseValidatorSanitizesNegativeMacros() throws {
        let plan = try loadRealPlan()
        let dirtyAction = AICoachLogAction(
            id: "act_negative",
            kind: .meal,
            title: "Negative Meal",
            kcal: -250,
            protein: -30,
            carbs: -40,
            fat: -10,
            waterMl: -500
        )
        let dirtyResponse = AICoachResponse(replyGreek: "", suggestedActions: [dirtyAction])

        let cleanResponse = AICoachResponseValidator.sanitizeAndHydrate(
            response: dirtyResponse,
            plan: plan,
            templateKey: "training"
        )

        XCTAssertFalse(cleanResponse.replyGreek.isEmpty, "Empty reply should receive fallback")
        XCTAssertEqual(cleanResponse.suggestedActions.count, 1)
        let a = cleanResponse.suggestedActions[0]
        XCTAssertEqual(a.kcal, 0.0)
        XCTAssertEqual(a.protein, 0.0)
        XCTAssertEqual(a.carbs, 0.0)
        XCTAssertEqual(a.fat, 0.0)
        XCTAssertEqual(a.waterMl, 0.0)
    }

    func testAICoachResponseValidatorHydratesPlanMacros() throws {
        let plan = try loadRealPlan()
        let action = AICoachLogAction(
            id: "act_tupper",
            kind: .meal,
            itemId: "tupper1",
            selectedOptionId: "tupper_3",
            title: "Ταπεράκι με Σολομό"
        )
        let rawResponse = AICoachResponse(replyGreek: "Καλή όρεξη!", suggestedActions: [action])

        let hydrated = AICoachResponseValidator.sanitizeAndHydrate(
            response: rawResponse,
            plan: plan,
            templateKey: "training"
        )

        XCTAssertEqual(hydrated.suggestedActions.count, 1)
        let hAction = hydrated.suggestedActions[0]
        XCTAssertNotNil(hAction.kcal)
        XCTAssertGreaterThan(hAction.kcal ?? 0, 0)
        XCTAssertNotNil(hAction.protein)
        XCTAssertGreaterThan(hAction.protein ?? 0, 0)
    }

    func testAICoachResponseValidatorSanitizesNaNAndInfinity() throws {
        let plan = try loadRealPlan()
        let nanAction = AICoachLogAction(
            id: "act_nan_inf",
            kind: .meal,
            title: "Corrupt LLM Action",
            kcal: Double.nan,
            protein: Double.infinity,
            carbs: -Double.infinity,
            fat: 12.0,
            waterMl: Double.nan
        )
        let rawResponse = AICoachResponse(replyGreek: "Test reply", suggestedActions: [nanAction])

        let sanitized = AICoachResponseValidator.sanitizeAndHydrate(
            response: rawResponse,
            plan: plan,
            templateKey: "training"
        )

        let a = sanitized.suggestedActions[0]
        XCTAssertEqual(a.kcal, 0.0, "NaN kcal must be clamped to 0.0")
        XCTAssertEqual(a.protein, 0.0, "+Infinity protein must be clamped to 0.0")
        XCTAssertEqual(a.carbs, 0.0, "-Infinity carbs must be clamped to 0.0")
        XCTAssertEqual(a.fat, 12.0)
        XCTAssertEqual(a.waterMl, 0.0, "NaN water must be clamped to 0.0")
    }
}

// MARK: - 5. AppContainer Integration Audit (Xcode Hosted Only)

#if !SWIFT_PACKAGE
extension BackendTotalAuditTests {

    @MainActor
    func testAppContainerFeatureTogglesPersistence() {
        let container = AppContainer(healthStore: FakeHealthStore())

        container.isFastingEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "orchard.fastingEnabled"))

        container.isFastingEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "orchard.fastingEnabled"))

        container.isGoalTrackingEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "orchard.goalTrackingEnabled"))

        container.isGoalTrackingEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "orchard.goalTrackingEnabled"))
    }

    @MainActor
    func testAppContainerSelectTemplateUpdatesTargetWater() {
        let container = AppContainer(healthStore: FakeHealthStore())

        container.selectTemplate(key: "training")
        XCTAssertEqual(container.targetWaterMl, 3000.0)

        container.selectTemplate(key: "double_training")
        XCTAssertEqual(container.targetWaterMl, 3500.0)

        container.selectTemplate(key: "rest")
        XCTAssertEqual(container.targetWaterMl, 2500.0)

        // Reset to training
        container.selectTemplate(key: "training")
    }

    @MainActor
    func testAppContainerOptionSelectionAndMealLogging() {
        let container = AppContainer(healthStore: FakeHealthStore())
        guard let lunchEvent = container.resolvedEvents.first(where: { $0.item.options?.count ?? 0 > 1 }) else {
            return
        }

        let options = lunchEvent.item.options!
        let chosenOption = options.last!
        container.selectOption(chosenOption, for: lunchEvent.item)

        let selected = container.selectedOption(for: lunchEvent.item)
        XCTAssertEqual(selected?.id, chosenOption.id)

        container.logMeal(event: lunchEvent, selectedOption: chosenOption)
        let loggedEntry = container.logEntries.first(where: { $0.itemId == lunchEvent.itemId })
        XCTAssertNotNil(loggedEntry)
        XCTAssertEqual(loggedEntry?.selectedOptionId, chosenOption.id)
        XCTAssertEqual(loggedEntry?.kcal, chosenOption.kcal)
    }

    @MainActor
    func testAppContainerLogSupplementAddsWaterAndUndoingSubtracts() {
        let container = AppContainer(healthStore: FakeHealthStore())
        container.resetWater()
        XCTAssertEqual(container.waterIntakeMl, 0.0)

        guard let suppWithWater = container.resolvedEvents.first(where: { ($0.item.waterMl ?? 0) > 0 }) else {
            XCTFail("Must find a supplement event with waterMl > 0")
            return
        }

        let expectedWater = suppWithWater.item.waterMl!
        container.logSupplement(event: suppWithWater)
        XCTAssertEqual(container.waterIntakeMl, expectedWater)

        container.undoLog(itemId: suppWithWater.itemId)
        XCTAssertEqual(container.waterIntakeMl, 0.0)
    }

    @MainActor
    func testAppContainerLogSupplementDoubleLoggingIdempotency() {
        let container = AppContainer(healthStore: FakeHealthStore())
        container.resetWater()
        XCTAssertEqual(container.waterIntakeMl, 0.0)

        guard let suppWithWater = container.resolvedEvents.first(where: { ($0.item.waterMl ?? 0) > 0 }) else {
            XCTFail("Must find a supplement event with waterMl > 0")
            return
        }

        let waterAmount = suppWithWater.item.waterMl!
        container.logSupplement(event: suppWithWater)
        XCTAssertEqual(container.waterIntakeMl, waterAmount)

        // Re-logging the same supplement must be idempotent and NOT double the water intake
        container.logSupplement(event: suppWithWater)
        XCTAssertEqual(
            container.waterIntakeMl,
            waterAmount,
            "Re-logging a supplement must NOT add duplicate waterMl (idempotency defect)"
        )

        // Undoing once should return water to 0
        container.undoLog(itemId: suppWithWater.itemId)
        XCTAssertEqual(container.waterIntakeMl, 0.0)
    }

    @MainActor
    func testAppContainerLogMealDoubleLoggingIdempotency() {
        let container = AppContainer(healthStore: FakeHealthStore())
        guard let mealEvent = container.resolvedEvents.first(where: { $0.item.type == .meal }) else {
            XCTFail("Must find a meal event")
            return
        }

        let startBite = container.biteCount
        container.logMeal(event: mealEvent)
        XCTAssertEqual(container.biteCount, startBite + 1)

        // Re-logging the same meal must NOT increment biteCount again
        container.logMeal(event: mealEvent)
        XCTAssertEqual(
            container.biteCount,
            startBite + 1,
            "Re-logging an already completed meal must NOT increment biteCount again"
        )

        container.undoLog(itemId: mealEvent.itemId)
        XCTAssertEqual(container.biteCount, startBite)
    }

    @MainActor
    func testAppContainerUndoSupplementDoesNotDecrementBiteCount() {
        let container = AppContainer(healthStore: FakeHealthStore())
        guard let mealEvent = container.resolvedEvents.first(where: { $0.item.type == .meal }),
              let suppEvent = container.resolvedEvents.first(where: { $0.item.type == .supplement }) else {
            XCTFail("Must find meal and supplement events")
            return
        }

        let initialBites = container.biteCount
        container.logMeal(event: mealEvent)
        XCTAssertEqual(container.biteCount, initialBites + 1)

        // Logging a supplement does not increase biteCount
        container.logSupplement(event: suppEvent)
        XCTAssertEqual(container.biteCount, initialBites + 1)

        // Undoing supplement must NOT decrement biteCount
        container.undoLog(itemId: suppEvent.itemId)
        XCTAssertEqual(
            container.biteCount,
            initialBites + 1,
            "Undoing a supplement must NOT decrement biteCount (only meals increment/decrement bites)"
        )

        container.undoLog(itemId: mealEvent.itemId)
        XCTAssertEqual(container.biteCount, initialBites)
    }

    @MainActor
    func testAppContainerExportCSVAndCoachSummary() {
        let container = AppContainer(healthStore: FakeHealthStore())
        let csv = container.exportCSV()
        XCTAssertFalse(csv.isEmpty)
        XCTAssertTrue(csv.contains("Date,Template,Kcal_In"))

        let coachSummary = container.exportCoachSummary()
        XCTAssertFalse(coachSummary.contains("4000 ml"))
        XCTAssertTrue(coachSummary.contains("John Akrivos"))
    }

    // MARK: - Phase 4 AI Nutrition Coach AppContainer Integration Tests

    @MainActor
    func testAppContainerAIAutoLogEnabledPersistence() {
        let container = AppContainer(healthStore: FakeHealthStore())

        container.aiAutoLogEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "orchard.ai.autoLogEnabled"))

        container.aiAutoLogEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "orchard.ai.autoLogEnabled"))
    }

    @MainActor
    func testAppContainerApplyAICoachActionMealWithOption() {
        let container = AppContainer(healthStore: FakeHealthStore())
        let initialBites = container.biteCount

        guard container.resolvedEvents.contains(where: { $0.itemId == "tupper1" }) else {
            XCTFail("Must have tupper1 in training template")
            return
        }

        let action = AICoachLogAction(
            id: "act_tupper_salmon",
            kind: .meal,
            itemId: "tupper1",
            selectedOptionId: "tupper_3",
            title: "Ταπεράκι με Σολομό",
            kcal: 600,
            protein: 45,
            carbs: 50,
            fat: 20
        )

        let appliedId = container.applyAICoachAction(action)
        XCTAssertEqual(appliedId, "tupper1")

        // 1. Logged entry check: must match Salmon option (tupper_opt_3), NEVER fallback to Chicken (tupper_opt_1)!
        let logged = container.logEntries.first(where: { $0.itemId == "tupper1" })
        XCTAssertNotNil(logged)
        XCTAssertEqual(logged?.selectedOptionId, "tupper_opt_3", "Must resolve tupper_3 to tupper_opt_3 (Salmon), never fall back to tupper_opt_1 (Chicken)")
        XCTAssertEqual(container.biteCount, initialBites + 1)

        // 2. Undo check
        container.undoAICoachAction(action, appliedLogId: appliedId)
        XCTAssertFalse(container.logEntries.contains { $0.itemId == "tupper1" })
        XCTAssertEqual(container.biteCount, initialBites)
    }

    @MainActor
    func testAppContainerApplyAICoachActionSupplementWithWater() {
        let container = AppContainer(healthStore: FakeHealthStore())
        container.resetWater()
        let initialBites = container.biteCount
        let initialWater = container.waterIntakeMl

        let action = AICoachLogAction(
            id: "act_shake",
            kind: .supplement,
            itemId: "post_workout_shake",
            title: "HIGH5 + 30g Πρωτεΐνη AFTER",
            waterMl: 500
        )

        let appliedId = container.applyAICoachAction(action)
        XCTAssertEqual(appliedId, "post_workout_shake")

        // Check supplement logged, water added, biteCount intact
        XCTAssertTrue(container.logEntries.contains { $0.itemId == "post_workout_shake" })
        XCTAssertEqual(container.waterIntakeMl, initialWater + 500.0)
        XCTAssertEqual(container.biteCount, initialBites, "Supplements must not increment biteCount")

        // Re-application idempotency
        container.applyAICoachAction(action)
        XCTAssertEqual(container.waterIntakeMl, initialWater + 500.0, "Re-applying supplement must not add duplicate water")

        // Undo check
        container.undoAICoachAction(action, appliedLogId: appliedId)
        XCTAssertFalse(container.logEntries.contains { $0.itemId == "post_workout_shake" })
        XCTAssertEqual(container.waterIntakeMl, initialWater)
        XCTAssertEqual(container.biteCount, initialBites)
    }

    @MainActor
    func testAppContainerApplyAICoachActionWater() {
        let container = AppContainer(healthStore: FakeHealthStore())
        container.resetWater()

        let action = AICoachLogAction(
            id: "act_water",
            kind: .water,
            title: "+500ml Νερό",
            waterMl: 500
        )

        container.applyAICoachAction(action)
        XCTAssertEqual(container.waterIntakeMl, 500.0)

        container.undoAICoachAction(action)
        XCTAssertEqual(container.waterIntakeMl, 0.0)
    }

    @MainActor
    func testAppContainerApplyAICoachActionManualFallback() {
        let container = AppContainer(healthStore: FakeHealthStore())
        let initialBites = container.biteCount

        let action = AICoachLogAction(
            id: "act_manual_soup",
            kind: .meal,
            itemId: nil, // Manual food item outside plan
            title: "Σπιτική Κοτόσουπα",
            kcal: 350,
            protein: 30,
            carbs: 25,
            fat: 10
        )

        let appliedId = container.applyAICoachAction(action)
        XCTAssertNotNil(appliedId)
        XCTAssertTrue(appliedId?.hasPrefix("manual_") == true)
        XCTAssertEqual(container.biteCount, initialBites + 1)

        let loggedManual = container.logEntries.first(where: { $0.itemId == appliedId })
        XCTAssertNotNil(loggedManual)
        XCTAssertEqual(loggedManual?.kcal, 350)
        XCTAssertEqual(loggedManual?.protein, 30)

        // Undo check
        container.undoAICoachAction(action, appliedLogId: appliedId)
        XCTAssertFalse(container.logEntries.contains { $0.itemId == appliedId })
        XCTAssertEqual(container.biteCount, initialBites)
    }

    @MainActor
    func testAppContainerAddManualLogWithAISourcePersistsToUserDefaults() {
        let container = AppContainer(healthStore: FakeHealthStore())
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let dateKey = f.string(from: container.selectedDate)

        let initialCount = container.logEntries.count
        let logId = container.addManualLog(
            title: "AI Logged Acai Bowl",
            type: .meal,
            kcal: 420.0,
            protein: 15.0,
            carbs: 65.0,
            fat: 8.0,
            notes: "Smart Logging from AILogSheet",
            source: .ai(provider: "gemini")
        )

        XCTAssertTrue(container.logEntries.count == initialCount + 1)
        let addedEntry = container.logEntries.first(where: { $0.itemId == logId })
        XCTAssertNotNil(addedEntry)
        XCTAssertEqual(addedEntry?.source, .ai(provider: "gemini"))

        // Verify persistence directly in UserDefaults
        guard let savedData = UserDefaults.standard.data(forKey: "orchard.logs.\(dateKey)"),
              let decodedLogs = try? JSONDecoder().decode([LogEntry].self, from: savedData) else {
            XCTFail("Must persist logs to UserDefaults under key orchard.logs.\(dateKey)")
            return
        }

        let persistedEntry = decodedLogs.first(where: { $0.itemId == logId })
        XCTAssertNotNil(persistedEntry, "Persisted logs must contain the newly added AI manual log entry")
        XCTAssertEqual(persistedEntry?.source, .ai(provider: "gemini"))

        // Cleanup
        if let uuid = addedEntry?.id {
            container.deleteLogEntry(id: uuid)
        }
    }

    @MainActor
    func testAppContainerChatMessageAppliedLogIdsTracksManualFoodUndo() {
        let container = AppContainer(healthStore: FakeHealthStore())
        let initialBites = container.biteCount

        let action = AICoachLogAction(
            id: "act_chat_salad",
            kind: .meal,
            itemId: nil, // Manual food item generated by AI
            title: "Ελληνική Σαλάτα",
            kcal: 280,
            protein: 8,
            carbs: 12,
            fat: 20
        )

        // 1. Simulate Chat Message with suggested action
        var chatMessage = AICoachChatMessage(
            isUser: false,
            text: "Προτείνω να καταγράψεις την Ελληνική Σαλάτα.",
            suggestedActions: [action]
        )

        // 2. User applies action from Chat UI (or auto-log)
        let generatedLogId = container.applyAICoachAction(action)
        XCTAssertNotNil(generatedLogId)
        chatMessage.appliedActionIds.insert(action.id)
        chatMessage.appliedLogIds[action.id] = generatedLogId!

        // Confirm state
        XCTAssertTrue(chatMessage.appliedLogIds.keys.contains(action.id))
        XCTAssertEqual(chatMessage.appliedLogIds[action.id], generatedLogId)
        XCTAssertEqual(container.biteCount, initialBites + 1)
        XCTAssertTrue(container.logEntries.contains { $0.itemId == generatedLogId })

        // 3. User taps «Αναίρεση» on that specific action in Chat UI
        let storedLogId = chatMessage.appliedLogIds[action.id]
        container.undoAICoachAction(action, appliedLogId: storedLogId)
        chatMessage.appliedActionIds.remove(action.id)
        chatMessage.appliedLogIds.removeValue(forKey: action.id)

        // 4. Confirm complete reversal
        XCTAssertFalse(chatMessage.appliedLogIds.keys.contains(action.id))
        XCTAssertFalse(container.logEntries.contains { $0.itemId == generatedLogId })
        XCTAssertEqual(container.biteCount, initialBites, "Bite count must be restored upon manual food undo")
    }
}
#endif
