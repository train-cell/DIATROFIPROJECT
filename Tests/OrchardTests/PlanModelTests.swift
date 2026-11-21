import XCTest
@testable import OrchardDomain

final class PlanModelTests: XCTestCase {

    private func getSamplePlanUrl() -> URL {
        let testFileUrl = URL(fileURLWithPath: #filePath)
        let rootDir = testFileUrl.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return rootDir.appendingPathComponent("Resources/plan.sample.json")
    }

    func testSamplePlanDecodesSuccessfully() throws {
        let planUrl = getSamplePlanUrl()
        let plan = try PlanLoader.loadPlan(from: planUrl)

        // Version & Settings
        XCTAssertEqual(plan.version, 1)
        XCTAssertEqual(plan.settings.wake, "07:30")
        XCTAssertEqual(plan.settings.bed, "23:30")
        XCTAssertEqual(plan.settings.minMealGapMinutes, 90)

        // Weekly schedule
        XCTAssertEqual(plan.weekly["mon"], "training")
        XCTAssertEqual(plan.weekly["tue"], "rest")
        XCTAssertEqual(plan.weekly["wed"], "training")
        XCTAssertEqual(plan.weekly["thu"], "rest")
        XCTAssertEqual(plan.weekly["fri"], "training")
        XCTAssertEqual(plan.weekly["sat"], "competition")
        XCTAssertEqual(plan.weekly["sun"], "rest")

        // Overrides
        XCTAssertEqual(plan.overrides?["2026-12-24"], "rest")

        // Templates
        XCTAssertNotNil(plan.templates["training"])
        XCTAssertNotNil(plan.templates["rest"])
        XCTAssertNotNil(plan.templates["competition"])

        let trainingTemplate = try XCTUnwrap(plan.templates["training"])
        XCTAssertEqual(trainingTemplate.trainingSessions.count, 1)
        XCTAssertEqual(trainingTemplate.trainingSessions.first?.start, "18:00")
        XCTAssertEqual(trainingTemplate.trainingSessions.first?.durationMinutes, 90)
        XCTAssertEqual(trainingTemplate.trainingSessions.first?.estKcal, 700)

        // Items in training template
        XCTAssertEqual(trainingTemplate.items.count, 4)

        let breakfast = try XCTUnwrap(trainingTemplate.items.first(where: { $0.id == "breakfast" }))
        XCTAssertEqual(breakfast.type, .meal)
        XCTAssertEqual(breakfast.title, "Breakfast")
        XCTAssertEqual(breakfast.anchor, .afterWake(minutes: 30))
        XCTAssertEqual(breakfast.kcal, 500)
        XCTAssertEqual(breakfast.protein, 30)
        XCTAssertEqual(breakfast.carbs, 60)
        XCTAssertEqual(breakfast.fat, 15)
        XCTAssertEqual(breakfast.fallbackTime, "08:00")

        let pre = try XCTUnwrap(trainingTemplate.items.first(where: { $0.id == "pre" }))
        XCTAssertEqual(pre.type, .meal)
        XCTAssertEqual(pre.anchor, .beforeTraining(minutes: 90))
        XCTAssertEqual(pre.fallbackTime, "16:30")

        let supp = try XCTUnwrap(trainingTemplate.items.first(where: { $0.id == "supp-a" }))
        XCTAssertEqual(supp.type, .supplement)
        XCTAssertEqual(supp.anchor, .withItem(itemId: "breakfast"))

        let post = try XCTUnwrap(trainingTemplate.items.first(where: { $0.id == "post" }))
        XCTAssertEqual(post.type, .meal)
        XCTAssertEqual(post.anchor, .afterTraining(minutes: 30))
        XCTAssertEqual(post.fallbackTime, "20:00")

        // Rules
        XCTAssertEqual(trainingTemplate.rules.count, 2)
        XCTAssertEqual(trainingTemplate.rules[0].type, .avoid)
        XCTAssertEqual(trainingTemplate.rules[1].type, .prefer)
    }

    func testTemplateLookupForWeekdayAndOverrides() throws {
        let planUrl = getSamplePlanUrl()
        let plan = try PlanLoader.loadPlan(from: planUrl)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Monday 2026-11-02 -> weekly: training
        var mondayComps = DateComponents()
        mondayComps.year = 2026
        mondayComps.month = 11
        mondayComps.day = 2
        let monday = try XCTUnwrap(calendar.date(from: mondayComps))
        XCTAssertEqual(plan.templateKey(for: monday, calendar: calendar), "training")

        // Tuesday 2026-11-03 -> weekly: rest
        var tuesdayComps = DateComponents()
        tuesdayComps.year = 2026
        tuesdayComps.month = 11
        tuesdayComps.day = 3
        let tuesday = try XCTUnwrap(calendar.date(from: tuesdayComps))
        XCTAssertEqual(plan.templateKey(for: tuesday, calendar: calendar), "rest")

        // Saturday 2026-11-07 -> weekly: competition
        var satComps = DateComponents()
        satComps.year = 2026
        satComps.month = 11
        satComps.day = 7
        let saturday = try XCTUnwrap(calendar.date(from: satComps))
        XCTAssertEqual(plan.templateKey(for: saturday, calendar: calendar), "competition")

        // 2026-12-24 is a Thursday (weekly is "rest"), but has explicit override: "rest"
        var overrideComps = DateComponents()
        overrideComps.year = 2026
        overrideComps.month = 12
        overrideComps.day = 24
        let overrideDate = try XCTUnwrap(calendar.date(from: overrideComps))
        XCTAssertEqual(plan.templateKey(for: overrideDate, calendar: calendar), "rest")
    }

    func testAnchorEncodingAndDecoding() throws {
        let anchors: [Anchor] = [
            .absolute(time: "12:30"),
            .afterWake(minutes: 45),
            .beforeSleep(minutes: 60),
            .beforeTraining(minutes: 90),
            .afterTraining(minutes: 30),
            .withItem(itemId: "breakfast")
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for anchor in anchors {
            let data = try encoder.encode(anchor)
            let decoded = try decoder.decode(Anchor.self, from: data)
            XCTAssertEqual(decoded, anchor)
        }
    }

    func testLogEntryAndSleepEntrySerialization() throws {
        let log = LogEntry(
            id: UUID(),
            eventKey: "breakfast.20261102",
            itemId: "breakfast",
            status: .done,
            timestamp: Date(timeIntervalSince1970: 1700000000),
            kcal: 510,
            protein: 32,
            carbs: 58,
            fat: 16,
            source: .plan,
            healthSyncId: "orchard.12345",
            note: "Delicious oatmeal"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let logData = try encoder.encode(log)
        let decodedLog = try decoder.decode(LogEntry.self, from: logData)
        XCTAssertEqual(decodedLog, log)

        let sleep = SleepEntry(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1700000000),
            rating: 4,
            tags: ["recovery", "deep"],
            note: "Felt rested",
            asleepMinutes: 465
        )

        let sleepData = try encoder.encode(sleep)
        let decodedSleep = try decoder.decode(SleepEntry.self, from: sleepData)
        XCTAssertEqual(decodedSleep, sleep)
    }

    func testPlanLoaderFailsOnInvalidData() {
        let invalidData = "invalid json".data(using: .utf8)!
        XCTAssertThrowsError(try PlanLoader.loadPlan(from: invalidData))
    }

    func testRealPlanJsonIfPresent() throws {
        let testFileUrl = URL(fileURLWithPath: #filePath)
        let rootDir = testFileUrl.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let realPlanUrl = rootDir.appendingPathComponent("plan.json")
        guard FileManager.default.fileExists(atPath: realPlanUrl.path) else { return }

        let plan = try PlanLoader.loadPlan(from: realPlanUrl)
        XCTAssertEqual(plan.version, 2, "Real plan.json must be version 2")
        XCTAssertEqual(plan.settings.wake, "10:30")
        XCTAssertEqual(plan.settings.bed, "23:30")
        XCTAssertEqual(plan.settings.minMealGapMinutes, 60)
        XCTAssertEqual(plan.settings.targetWaterMl, 3000.0)
        XCTAssertEqual(plan.settings.minWaterMl, 2500.0)
        XCTAssertEqual(plan.settings.sport, "Τεχνική Κολύμβηση")
        XCTAssertEqual(plan.settings.planLabel, "Πρόγραμμα #1 (11.11.26)")

        // Verify the 5 templates
        XCTAssertEqual(plan.templates.count, 5, "Nutrition protocol plan must contain exactly 5 templates")
        let expectedTemplateKeys = ["training", "double_training", "pre_race", "race_day", "rest"]
        for key in expectedTemplateKeys {
            XCTAssertNotNil(plan.templates[key], "Template '\(key)' must be present")
        }

        // Structural validation via PlanDraftValidator
        let validationResult = PlanDraftValidator.validate(plan: plan)
        XCTAssertEqual(validationResult, .valid, "Real plan.json must pass PlanDraftValidator without errors")
    }

    func testRealPlanTemplatesResolutionAndNutritionProtocol() throws {
        let testFileUrl = URL(fileURLWithPath: #filePath)
        let rootDir = testFileUrl.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let realPlanUrl = rootDir.appendingPathComponent("plan.json")
        guard FileManager.default.fileExists(atPath: realPlanUrl.path) else { return }

        let plan = try PlanLoader.loadPlan(from: realPlanUrl)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Monday (2026-11-02) -> training
        let monday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 10, minute: 30))!
        let trainingEvents = ScheduleResolver.resolve(date: monday, plan: plan, calendar: calendar)

        // On Monday, FERRO SANOL is NOT scheduled (active only wed, fri)
        XCTAssertFalse(trainingEvents.contains { $0.itemId == "ferro_sanol" })
        XCTAssertTrue(trainingEvents.contains { $0.itemId == "vit_c" })
        XCTAssertTrue(trainingEvents.contains { $0.itemId == "bf_fuel" })
        XCTAssertTrue(trainingEvents.contains { $0.itemId == "v2000" })
        XCTAssertTrue(trainingEvents.contains { $0.itemId == "sandwich" })
        XCTAssertTrue(trainingEvents.contains { $0.itemId == "tupper1" })
        XCTAssertTrue(trainingEvents.contains { $0.itemId == "main_meal" })
        XCTAssertTrue(trainingEvents.contains { $0.itemId == "garnish" })

        // Check sandwich at 12:00 (afterWake 90 from 10:30)
        let sandwich = try XCTUnwrap(trainingEvents.first { $0.itemId == "sandwich" })
        XCTAssertEqual(calendar.component(.hour, from: sandwich.resolvedTime), 12)
        XCTAssertEqual(calendar.component(.minute, from: sandwich.resolvedTime), 0)

        // Check tupper1 at 13:30 (afterWake 180 from 10:30)
        let tupper = try XCTUnwrap(trainingEvents.first { $0.itemId == "tupper1" })
        XCTAssertEqual(calendar.component(.hour, from: tupper.resolvedTime), 13)
        XCTAssertEqual(calendar.component(.minute, from: tupper.resolvedTime), 30)

        // Wednesday (2026-11-04) -> training with FERRO SANOL included
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 10, minute: 30))!
        let wedEvents = ScheduleResolver.resolve(date: wednesday, plan: plan, calendar: calendar)
        XCTAssertTrue(wedEvents.contains { $0.itemId == "ferro_sanol" }, "Wednesday must include FERRO SANOL")

        // Sunday (2026-11-08) -> rest
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 10, minute: 30))!
        XCTAssertEqual(plan.templateKey(for: sunday, calendar: calendar), "rest")
        let restEvents = ScheduleResolver.resolve(date: sunday, plan: plan, calendar: calendar)
        XCTAssertFalse(restEvents.isEmpty)

        // Verify options count on key meals in training template
        let trainingTemplate = plan.templates["training"]!
        let bfItem = trainingTemplate.items.first { $0.id == "bf_fuel" }!
        XCTAssertEqual(bfItem.options?.count, 8)

        let swItem = trainingTemplate.items.first { $0.id == "sandwich" }!
        XCTAssertEqual(swItem.options?.count, 11)

        let tupperItem = trainingTemplate.items.first { $0.id == "tupper1" }!
        XCTAssertEqual(tupperItem.options?.count, 6)

        let mainItem = trainingTemplate.items.first { $0.id == "main_meal" }!
        XCTAssertEqual(mainItem.options?.count, 7)

        let garnishItem = trainingTemplate.items.first { $0.id == "garnish" }!
        XCTAssertEqual(garnishItem.options?.count, 8)
        XCTAssertEqual(garnishItem.isOptional, true)
    }
}
