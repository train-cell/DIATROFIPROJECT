import XCTest
@testable import OrchardDomain

final class ScheduleResolverTests: XCTestCase {

    private func createTestPlan() -> Plan {
        let settings = PlanSettings(wake: "07:30", bed: "23:30", minMealGapMinutes: 90)

        let trainingTemplate = DayTemplate(
            trainingSessions: [
                TrainingSession(start: "18:00", durationMinutes: 90, estKcal: 700)
            ],
            items: [
                PlanItem(
                    id: "breakfast",
                    type: .meal,
                    title: "Breakfast",
                    anchor: .afterWake(minutes: 30),
                    kcal: 500,
                    protein: 30,
                    carbs: 60,
                    fat: 15,
                    fallbackTime: "08:00"
                ),
                PlanItem(
                    id: "pre",
                    type: .meal,
                    title: "Pre-training meal",
                    anchor: .beforeTraining(minutes: 90),
                    kcal: 400,
                    protein: 20,
                    carbs: 70,
                    fat: 5,
                    fallbackTime: "16:30"
                ),
                PlanItem(
                    id: "supp-a",
                    type: .supplement,
                    title: "Supplement A",
                    anchor: .withItem(itemId: "breakfast")
                ),
                PlanItem(
                    id: "post",
                    type: .meal,
                    title: "Post-training meal",
                    anchor: .afterTraining(minutes: 30),
                    kcal: 600,
                    protein: 40,
                    carbs: 70,
                    fat: 15,
                    fallbackTime: "20:00"
                )
            ],
            rules: [
                Rule(type: .avoid, text: "Nothing heavy within 2h of training")
            ]
        )

        let restTemplate = DayTemplate(
            trainingSessions: [],
            items: [
                PlanItem(
                    id: "rest-breakfast",
                    type: .meal,
                    title: "Rest Breakfast",
                    anchor: .afterWake(minutes: 60),
                    kcal: 450,
                    protein: 25,
                    carbs: 50,
                    fat: 15
                ),
                PlanItem(
                    id: "rest-lunch",
                    type: .meal,
                    title: "Rest Lunch",
                    anchor: .absolute(time: "13:30"),
                    kcal: 600,
                    protein: 35,
                    carbs: 60,
                    fat: 20
                ),
                PlanItem(
                    id: "rest-dinner",
                    type: .meal,
                    title: "Rest Dinner",
                    anchor: .beforeSleep(minutes: 120),
                    kcal: 500,
                    protein: 30,
                    carbs: 40,
                    fat: 15
                )
            ],
            rules: []
        )

        let dayATemplate = DayTemplate(
            trainingSessions: [],
            items: [
                PlanItem(id: "day_a_breakfast", type: .meal, title: "Day A Breakfast (Oats)", anchor: .afterWake(minutes: 30), kcal: 550),
                PlanItem(id: "day_a_lunch", type: .meal, title: "Day A Lunch (Chicken Rice)", anchor: .absolute(time: "14:00"), kcal: 700),
                PlanItem(id: "day_a_snack", type: .meal, title: "Day A Snack (Apple & Whey)", anchor: .absolute(time: "17:30"), kcal: 300),
                PlanItem(id: "day_a_dinner", type: .meal, title: "Day A Dinner (Salmon)", anchor: .beforeSleep(minutes: 90), kcal: 650)
            ],
            rules: []
        )

        let dayBTemplate = DayTemplate(
            trainingSessions: [],
            items: [
                PlanItem(id: "day_b_breakfast", type: .meal, title: "Day B Breakfast (Eggs)", anchor: .afterWake(minutes: 45), kcal: 500),
                PlanItem(id: "day_b_lunch", type: .meal, title: "Day B Lunch (Beef Pasta)", anchor: .absolute(time: "13:30"), kcal: 750),
                PlanItem(id: "day_b_dinner", type: .meal, title: "Day B Dinner (Yogurt)", anchor: .beforeSleep(minutes: 60), kcal: 400)
            ],
            rules: []
        )

        return Plan(
            version: 1,
            settings: settings,
            weekly: [
                "mon": "training",
                "tue": "rest",
                "wed": "training",
                "thu": "rest",
                "fri": "training",
                "sat": "competition",
                "sun": "rest"
            ],
            templates: [
                "training": trainingTemplate,
                "rest": restTemplate,
                "competition": restTemplate,
                "day_a": dayATemplate,
                "day_b": dayBTemplate
            ],
            overrides: [
                "2026-12-24": "rest"
            ]
        )
    }

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return utcCalendar.date(from: comps)!
    }

    // MARK: - Tests

    func testTrainingDayResolutionWithAnchors() {
        let plan = createTestPlan()
        // 2026-11-02 is Monday -> "training" template
        let monday = makeDate(year: 2026, month: 11, day: 2)

        let events = ScheduleResolver.resolve(date: monday, plan: plan, calendar: utcCalendar)

        XCTAssertEqual(events.count, 4)

        // 1. Breakfast: afterWake 30m -> wake 07:30 + 30m = 08:00
        let breakfast = try? XCTUnwrap(events.first(where: { $0.itemId == "breakfast" }))
        let expectedBreakfastTime = makeDate(year: 2026, month: 11, day: 2, hour: 8, minute: 0)
        XCTAssertEqual(breakfast?.resolvedTime, expectedBreakfastTime)

        // 2. Pre-training: beforeTraining 90m -> training starts 18:00 - 90m = 16:30
        let pre = try? XCTUnwrap(events.first(where: { $0.itemId == "pre" }))
        let expectedPreTime = makeDate(year: 2026, month: 11, day: 2, hour: 16, minute: 30)
        XCTAssertEqual(pre?.resolvedTime, expectedPreTime)

        // 3. Post-training: afterTraining 30m -> training ends 18:00 + 90m = 19:30 + 30m = 20:00
        let post = try? XCTUnwrap(events.first(where: { $0.itemId == "post" }))
        let expectedPostTime = makeDate(year: 2026, month: 11, day: 2, hour: 20, minute: 0)
        XCTAssertEqual(post?.resolvedTime, expectedPostTime)

        // 4. Supplement: withItem "breakfast" -> 08:00
        let supp = try? XCTUnwrap(events.first(where: { $0.itemId == "supp-a" }))
        XCTAssertEqual(supp?.resolvedTime, expectedBreakfastTime)

        // Breakfast event should also reference attachedItems
        XCTAssertTrue(breakfast?.attachedItems.contains(where: { $0.id == "supp-a" }) ?? false)
    }

    func testRestDayResolutionUsingFallbackTime() {
        // Create a template with no training session but items that anchor to beforeTraining/afterTraining
        let settings = PlanSettings(wake: "07:30", bed: "23:30", minMealGapMinutes: 90)
        let itemWithFallback = PlanItem(
            id: "snack",
            type: .meal,
            title: "Snack",
            anchor: .beforeTraining(minutes: 60),
            fallbackTime: "15:00"
        )
        let plan = Plan(
            version: 1,
            settings: settings,
            weekly: ["tue": "rest"],
            templates: ["rest": DayTemplate(trainingSessions: [], items: [itemWithFallback], rules: [])]
        )

        // 2026-11-03 is Tuesday -> "rest"
        let tuesday = makeDate(year: 2026, month: 11, day: 3)
        let events = ScheduleResolver.resolve(date: tuesday, plan: plan, calendar: utcCalendar)

        XCTAssertEqual(events.count, 1)
        let snack = try? XCTUnwrap(events.first(where: { $0.itemId == "snack" }))
        let expectedSnackTime = makeDate(year: 2026, month: 11, day: 3, hour: 15, minute: 0)
        XCTAssertEqual(snack?.resolvedTime, expectedSnackTime)
    }

    func testActualTrainingOverridesTemplateTraining() {
        let plan = createTestPlan()
        let monday = makeDate(year: 2026, month: 11, day: 2)

        // Actual workout took place earlier: 14:00 to 15:30
        let actualWorkout = TrainingSession(
            start: "14:00",
            durationMinutes: 90,
            estKcal: 650,
            isActual: true
        )

        let events = ScheduleResolver.resolve(
            date: monday,
            plan: plan,
            actualTrainings: [actualWorkout],
            calendar: utcCalendar
        )

        // Pre: 14:00 - 90m = 12:30
        let pre = try? XCTUnwrap(events.first(where: { $0.itemId == "pre" }))
        let expectedPreTime = makeDate(year: 2026, month: 11, day: 2, hour: 12, minute: 30)
        XCTAssertEqual(pre?.resolvedTime, expectedPreTime)

        // Post: 15:30 + 30m = 16:00
        let post = try? XCTUnwrap(events.first(where: { $0.itemId == "post" }))
        let expectedPostTime = makeDate(year: 2026, month: 11, day: 2, hour: 16, minute: 0)
        XCTAssertEqual(post?.resolvedTime, expectedPostTime)
    }

    func testUserSelectableTemplateOverrideInMorning() {
        let plan = createTestPlan()
        // 2026-11-04 is Wednesday (normally "training" in weekly schedule)
        let wednesday = makeDate(year: 2026, month: 11, day: 4)

        // User explicitly selects "day_a" in the morning
        let events = ScheduleResolver.resolve(
            date: wednesday,
            plan: plan,
            selectedTemplateName: "day_a",
            calendar: utcCalendar
        )

        XCTAssertEqual(events.count, 4)
        let itemIds = events.map(\.itemId)
        XCTAssertEqual(itemIds, ["day_a_breakfast", "day_a_lunch", "day_a_snack", "day_a_dinner"])

        // Day A breakfast (afterWake 30m -> 08:00)
        let breakfast = try? XCTUnwrap(events.first(where: { $0.itemId == "day_a_breakfast" }))
        XCTAssertEqual(breakfast?.resolvedTime, makeDate(year: 2026, month: 11, day: 4, hour: 8, minute: 0))

        // Day A lunch (absolute 14:00)
        let lunch = try? XCTUnwrap(events.first(where: { $0.itemId == "day_a_lunch" }))
        XCTAssertEqual(lunch?.resolvedTime, makeDate(year: 2026, month: 11, day: 4, hour: 14, minute: 0))

        // Day A dinner (beforeSleep 90m -> bed 23:30 - 90m = 22:00)
        let dinner = try? XCTUnwrap(events.first(where: { $0.itemId == "day_a_dinner" }))
        XCTAssertEqual(dinner?.resolvedTime, makeDate(year: 2026, month: 11, day: 4, hour: 22, minute: 0))
    }

    func testMinMealGapConflictDetection() {
        let settings = PlanSettings(wake: "07:30", bed: "23:30", minMealGapMinutes: 90)

        // Two meals only 60 minutes apart (12:00 and 13:00)
        let meal1 = PlanItem(id: "meal1", type: .meal, title: "Meal 1", anchor: .absolute(time: "12:00"))
        let meal2 = PlanItem(id: "meal2", type: .meal, title: "Meal 2", anchor: .absolute(time: "13:00"))
        // Supplement at 13:00 should NOT trigger meal gap conflict
        let supp = PlanItem(id: "supp", type: .supplement, title: "Vitamins", anchor: .absolute(time: "13:00"))

        let plan = Plan(
            version: 1,
            settings: settings,
            weekly: ["mon": "test"],
            templates: ["test": DayTemplate(trainingSessions: [], items: [meal1, meal2, supp], rules: [])]
        )

        let monday = makeDate(year: 2026, month: 11, day: 2)
        let events = ScheduleResolver.resolve(date: monday, plan: plan, calendar: utcCalendar)

        let _ = try? XCTUnwrap(events.first(where: { $0.itemId == "meal1" }))
        let event2 = try? XCTUnwrap(events.first(where: { $0.itemId == "meal2" }))
        let suppEvent = try? XCTUnwrap(events.first(where: { $0.itemId == "supp" }))

        // Meal 2 is only 60 mins after Meal 1, which violates the 90 min minimum
        XCTAssertEqual(event2?.hasConflict, true)
        XCTAssertNotNil(event2?.conflictReason)

        // Supplement should not conflict
        XCTAssertEqual(suppEvent?.hasConflict, false)
    }

    func testOvernightBedtimeEdgeCase() {
        // Bed is past midnight, e.g. 00:30
        let settings = PlanSettings(wake: "08:00", bed: "00:30", minMealGapMinutes: 60)
        let item = PlanItem(
            id: "night-shake",
            type: .meal,
            title: "Night Shake",
            anchor: .beforeSleep(minutes: 60) // 1 hour before 00:30 is 23:30 on the target day
        )

        let plan = Plan(
            version: 1,
            settings: settings,
            weekly: ["mon": "night"],
            templates: ["night": DayTemplate(trainingSessions: [], items: [item], rules: [])]
        )

        let monday = makeDate(year: 2026, month: 11, day: 2)
        let events = ScheduleResolver.resolve(date: monday, plan: plan, calendar: utcCalendar)

        let event = try? XCTUnwrap(events.first(where: { $0.itemId == "night-shake" }))
        // Bed is 2026-11-03 00:30. 60m before is 2026-11-02 23:30.
        let expectedTime = makeDate(year: 2026, month: 11, day: 2, hour: 23, minute: 30)
        XCTAssertEqual(event?.resolvedTime, expectedTime)
    }

    func testEventsAreSortedChronologically() {
        let plan = createTestPlan()
        let monday = makeDate(year: 2026, month: 11, day: 2)
        let events = ScheduleResolver.resolve(date: monday, plan: plan, calendar: utcCalendar)

        for i in 1..<events.count {
            XCTAssertLessThanOrEqual(events[i-1].resolvedTime, events[i].resolvedTime)
        }
    }
}
