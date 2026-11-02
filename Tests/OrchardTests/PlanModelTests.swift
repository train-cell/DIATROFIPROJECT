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
        XCTAssertEqual(plan.templates.count, 7, "User 7-day cyclical plan must contain exactly 7 templates")
        XCTAssertNotNil(plan.templates["day_1"])
        XCTAssertNotNil(plan.templates["day_7"])

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()

        // Verify schedule resolution for all 7 days
        for dayIndex in 1...7 {
            let templateName = "day_\(dayIndex)"
            let events = ScheduleResolver.resolve(date: now, plan: plan, selectedTemplateName: templateName, calendar: calendar)
            XCTAssertFalse(events.isEmpty, "Template \(templateName) must produce events")
            XCTAssertTrue(events.count >= 5, "Template \(templateName) should have at least 5 meals/slots")
        }
    }

    func testRealPlanAllSevenDaysNutritionAndDay7SpecialLayout() throws {
        let testFileUrl = URL(fileURLWithPath: #filePath)
        let rootDir = testFileUrl.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let realPlanUrl = rootDir.appendingPathComponent("plan.json")
        guard FileManager.default.fileExists(atPath: realPlanUrl.path) else { return }

        let plan = try PlanLoader.loadPlan(from: realPlanUrl)

        // 1. Structural validation via PlanDraftValidator
        let validationResult = PlanDraftValidator.validate(plan: plan)
        XCTAssertEqual(validationResult, .valid, "Real plan.json must pass PlanDraftValidator without errors")

        // 2. Calorie totals across all 7 days
        let expectedDailyKcal: [String: Double] = [
            "day_1": 1820.0,
            "day_2": 1770.0,
            "day_3": 2000.0,
            "day_4": 1840.0,
            "day_5": 1960.0,
            "day_6": 1720.0,
            "day_7": 2000.0
        ]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 8, minute: 0))!

        for (dayKey, expectedKcal) in expectedDailyKcal {
            guard let template = plan.templates[dayKey] else {
                XCTFail("Missing template \(dayKey)")
                continue
            }

            // CalorieEngine calculation
            let plannedKcal = CalorieEngine.plannedDayKcal(template: template)
            XCTAssertEqual(plannedKcal, expectedKcal, "Calorie mismatch for \(dayKey): expected \(expectedKcal), got \(plannedKcal)")

            // Anchor math and schedule resolution
            let events = ScheduleResolver.resolve(date: baseDate, plan: plan, selectedTemplateName: dayKey, calendar: calendar)
            XCTAssertEqual(events.count, template.items.count, "All items in \(dayKey) must resolve to events")

            for event in events {
                XCTAssertFalse(event.hasConflict, "Event \(event.itemId) in \(dayKey) should not have conflicts, but got: \(event.conflictReason ?? "")")
            }

            // Verify days 1-6 contain rice cakes snack (ρυζογκοφρέτες)
            if dayKey != "day_7" {
                let hasRiceCakes = template.items.contains { $0.title.contains("ρυζογκοφρέτες") }
                XCTAssertTrue(hasRiceCakes, "\(dayKey) should include midday rice cakes snack")
            }
        }

        // 3. Day 7 Special Layout In-Depth Verification
        let day7 = try XCTUnwrap(plan.templates["day_7"])
        XCTAssertEqual(day7.items.count, 5, "Day 7 has 5 items layout")

        // Day 7 training session: 12:30, 75 min -> ends at 13:45
        let training = try XCTUnwrap(day7.trainingSessions.first)
        XCTAssertEqual(training.start, "12:30")
        XCTAssertEqual(training.durationMinutes, 75)
        XCTAssertEqual(training.estKcal, 550)

        // Resolve Day 7
        let day7Events = ScheduleResolver.resolve(date: baseDate, plan: plan, selectedTemplateName: "day_7", calendar: calendar)

        // 3a. Breakfast: Porridge at 10:30 (360 kcal)
        let breakfast = try XCTUnwrap(day7Events.first { $0.itemId == "d7_breakfast" })
        XCTAssertTrue(breakfast.item.title.contains("Porridge"))
        XCTAssertEqual(breakfast.item.kcal, 360.0)
        XCTAssertEqual(calendar.component(.hour, from: breakfast.resolvedTime), 10)
        XCTAssertEqual(calendar.component(.minute, from: breakfast.resolvedTime), 30)

        // 3b. Morning snack: Fruit at 12:00 (100 kcal)
        let snack = try XCTUnwrap(day7Events.first { $0.itemId == "d7_morning_snack" })
        XCTAssertEqual(snack.item.kcal, 100.0)
        XCTAssertEqual(calendar.component(.hour, from: snack.resolvedTime), 12)
        XCTAssertEqual(calendar.component(.minute, from: snack.resolvedTime), 0)

        // 3c. Big post-workout steak meal: 14:30 (780 kcal, 65g P)
        // afterTraining 45 min -> 12:30 + 75m + 45m = 13:45 + 45m = 14:30
        let steakMeal = try XCTUnwrap(day7Events.first { $0.itemId == "d7_midday_postworkout_combo" })
        XCTAssertTrue(steakMeal.item.title.contains("μπριζόλα"))
        XCTAssertEqual(steakMeal.item.kcal, 780.0)
        XCTAssertEqual(steakMeal.item.protein, 65.0)
        XCTAssertEqual(calendar.component(.hour, from: steakMeal.resolvedTime), 14)
        XCTAssertEqual(calendar.component(.minute, from: steakMeal.resolvedTime), 30)

        // 3d. Verify NO rice cakes on Day 7
        let day7HasRiceCakes = day7.items.contains { $0.title.contains("ρυζογκοφρέτες") }
        XCTAssertFalse(day7HasRiceCakes, "Day 7 special layout should have NO rice cakes")

        // 3e. Evening yogurt: 20:30 (240 kcal, 20g P)
        let dinnerYogurt = try XCTUnwrap(day7Events.first { $0.itemId == "d7_dinner" })
        XCTAssertTrue(dinnerYogurt.item.title.contains("γιαούρτι"))
        XCTAssertEqual(dinnerYogurt.item.kcal, 240.0)
        XCTAssertEqual(dinnerYogurt.item.protein, 20.0)
        XCTAssertEqual(calendar.component(.hour, from: dinnerYogurt.resolvedTime), 20)
        XCTAssertEqual(calendar.component(.minute, from: dinnerYogurt.resolvedTime), 30)

        // 3f. Extra evening meal: 22:15 (520 kcal, 30g P)
        let extraMeal = try XCTUnwrap(day7Events.first { $0.itemId == "d7_extra" })
        XCTAssertEqual(extraMeal.item.kcal, 520.0)
        XCTAssertEqual(extraMeal.item.protein, 30.0)
        XCTAssertEqual(calendar.component(.hour, from: extraMeal.resolvedTime), 22)
        XCTAssertEqual(calendar.component(.minute, from: extraMeal.resolvedTime), 15)

        // 3g. Day 7 Calorie Total
        let totalDay7Kcal = day7Events.reduce(0.0) { $0 + ($1.item.kcal ?? 0.0) }
        XCTAssertEqual(totalDay7Kcal, 2000.0)
    }
}
