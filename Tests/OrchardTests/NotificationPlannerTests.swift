import XCTest
@testable import OrchardDomain

final class NotificationPlannerTests: XCTestCase {

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDate(year: Int = 2026, month: Int = 11, day: Int = 2, hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return utcCalendar.date(from: comps)!
    }

    func testMealNudgesAt0_15_30Minutes() {
        let mealDate = makeDate(hour: 12, minute: 0)
        let item = PlanItem(
            id: "lunch",
            type: .meal,
            title: "Lunch",
            anchor: .absolute(time: "12:00"),
            kcal: 600
        )
        let event = ScheduledEvent(
            id: "evt.lunch.20261102",
            itemId: "lunch",
            item: item,
            date: makeDate(hour: 0, minute: 0),
            resolvedTime: mealDate
        )

        let now = makeDate(hour: 11, minute: 0)
        let specs = NotificationPlanner.plan(
            events: [event],
            now: now,
            calendar: utcCalendar
        )

        // Meal should have 3 nudges: +0m, +15m, +30m
        XCTAssertEqual(specs.count, 3)

        XCTAssertEqual(specs[0].identifier, "evt.lunch.20261102.0")
        XCTAssertEqual(specs[0].fireDate, makeDate(hour: 12, minute: 0))
        XCTAssertEqual(specs[0].nudgeIndex, 0)
        XCTAssertEqual(specs[0].category, NotificationCategory.meal.rawValue)

        XCTAssertEqual(specs[1].identifier, "evt.lunch.20261102.1")
        XCTAssertEqual(specs[1].fireDate, makeDate(hour: 12, minute: 15))
        XCTAssertEqual(specs[1].nudgeIndex, 1)

        XCTAssertEqual(specs[2].identifier, "evt.lunch.20261102.2")
        XCTAssertEqual(specs[2].fireDate, makeDate(hour: 12, minute: 30))
        XCTAssertEqual(specs[2].nudgeIndex, 2)
    }

    func testSupplementNudgesAt0_20Minutes() {
        let suppDate = makeDate(hour: 9, minute: 0)
        let item = PlanItem(
            id: "omega3",
            type: .supplement,
            title: "Omega 3",
            anchor: .absolute(time: "09:00")
        )
        let event = ScheduledEvent(
            id: "evt.omega3.20261102",
            itemId: "omega3",
            item: item,
            date: makeDate(hour: 0, minute: 0),
            resolvedTime: suppDate
        )

        let now = makeDate(hour: 8, minute: 0)
        let specs = NotificationPlanner.plan(
            events: [event],
            now: now,
            calendar: utcCalendar
        )

        // Supplement should have 2 nudges: +0m, +20m
        XCTAssertEqual(specs.count, 2)

        XCTAssertEqual(specs[0].identifier, "evt.omega3.20261102.0")
        XCTAssertEqual(specs[0].fireDate, makeDate(hour: 9, minute: 0))
        XCTAssertEqual(specs[0].nudgeIndex, 0)
        XCTAssertEqual(specs[0].category, NotificationCategory.supplement.rawValue)

        XCTAssertEqual(specs[1].identifier, "evt.omega3.20261102.1")
        XCTAssertEqual(specs[1].fireDate, makeDate(hour: 9, minute: 20))
        XCTAssertEqual(specs[1].nudgeIndex, 1)
    }

    func testSuppressesAlreadyLoggedEvents() {
        let mealDate = makeDate(hour: 13, minute: 0)
        let item = PlanItem(
            id: "lunch",
            type: .meal,
            title: "Lunch",
            anchor: .absolute(time: "13:00")
        )
        let event = ScheduledEvent(
            id: "evt.lunch.20261102",
            itemId: "lunch",
            item: item,
            date: makeDate(hour: 0, minute: 0),
            resolvedTime: mealDate
        )

        // Log indicates meal was completed
        let log = LogEntry(
            eventKey: "lunch.20261102",
            itemId: "lunch",
            status: .done,
            timestamp: makeDate(hour: 12, minute: 55)
        )

        let now = makeDate(hour: 12, minute: 0)
        let specs = NotificationPlanner.plan(
            events: [event],
            logs: [log],
            now: now,
            calendar: utcCalendar
        )

        XCTAssertTrue(specs.isEmpty, "No notifications should be scheduled for completed meal")
    }

    func testPastNudgesAreNotScheduled() {
        let mealDate = makeDate(hour: 12, minute: 0)
        let item = PlanItem(
            id: "lunch",
            type: .meal,
            title: "Lunch",
            anchor: .absolute(time: "12:00")
        )
        let event = ScheduledEvent(
            id: "evt.lunch.20261102",
            itemId: "lunch",
            item: item,
            date: makeDate(hour: 0, minute: 0),
            resolvedTime: mealDate
        )

        // Now is 12:20 -> nudge 0 (12:00) and nudge 1 (12:15) are in the past
        let now = makeDate(hour: 12, minute: 20)
        let specs = NotificationPlanner.plan(
            events: [event],
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(specs.count, 1)
        XCTAssertEqual(specs.first?.identifier, "evt.lunch.20261102.2")
        XCTAssertEqual(specs.first?.fireDate, makeDate(hour: 12, minute: 30))
    }

    func testRespectsQuietHoursDuringSleep() {
        let settings = PlanSettings(wake: "07:30", bed: "23:00", minMealGapMinutes: 90)

        // Late event at 22:50 -> nudge 0 is 22:50, nudge 1 is 23:05, nudge 2 is 23:20
        let lateDate = makeDate(hour: 22, minute: 50)
        let item = PlanItem(id: "snack", type: .meal, title: "Snack", anchor: .absolute(time: "22:50"))
        let event = ScheduledEvent(
            id: "evt.snack.20261102",
            itemId: "snack",
            item: item,
            date: makeDate(hour: 0, minute: 0),
            resolvedTime: lateDate
        )

        let now = makeDate(hour: 22, minute: 0)
        let specs = NotificationPlanner.plan(
            events: [event],
            now: now,
            settings: settings,
            calendar: utcCalendar
        )

        // Nudges at 23:05 and 23:20 fall within quiet hours (>= 23:00) and must be suppressed
        let mealSpecs = specs.filter { $0.category == NotificationCategory.meal.rawValue }
        XCTAssertEqual(mealSpecs.count, 1)
        XCTAssertEqual(mealSpecs[0].identifier, "evt.snack.20261102.0")
    }

    func testMorningSleepRatingNotification() {
        let settings = PlanSettings(wake: "07:30", bed: "23:30", minMealGapMinutes: 90)
        let now = makeDate(hour: 6, minute: 0)

        let specs = NotificationPlanner.plan(
            events: [],
            now: now,
            windowDays: 2,
            settings: settings,
            calendar: utcCalendar
        )

        // Sleep rating should be scheduled for day 1 and day 2 at 07:30
        let sleepSpecs = specs.filter { $0.category == NotificationCategory.sleepRating.rawValue }
        XCTAssertEqual(sleepSpecs.count, 2)
        XCTAssertEqual(sleepSpecs[0].fireDate, makeDate(year: 2026, month: 11, day: 2, hour: 7, minute: 30))
        XCTAssertEqual(sleepSpecs[1].fireDate, makeDate(year: 2026, month: 11, day: 3, hour: 7, minute: 30))
    }

    func testCapsPendingNotificationsTo60WithSmartPruning() {
        // Create 25 meal events across 3 days (each generates 3 nudges = 75 nudges total)
        var events: [ScheduledEvent] = []
        let baseDate = makeDate(hour: 0, minute: 0)

        for day in 0..<3 {
            for mealIndex in 0..<8 {
                let hour = 8 + (mealIndex * 2)
                let item = PlanItem(
                    id: "meal_\(day)_\(mealIndex)",
                    type: .meal,
                    title: "Meal \(day)-\(mealIndex)",
                    anchor: .absolute(time: String(format: "%02d:00", hour))
                )
                let eventTime = makeDate(day: 2 + day, hour: hour, minute: 0)
                let event = ScheduledEvent(
                    id: "evt.meal_\(day)_\(mealIndex).2026110\(2+day)",
                    itemId: item.id,
                    item: item,
                    date: baseDate,
                    resolvedTime: eventTime
                )
                events.append(event)
            }
        }

        let now = makeDate(hour: 6, minute: 0)
        let specs = NotificationPlanner.plan(
            events: events,
            now: now,
            windowDays: 3,
            calendar: utcCalendar
        )

        // Strict hard limit of 60
        XCTAssertLessThanOrEqual(specs.count, NotificationPlanner.maxPendingNotifications)
        XCTAssertEqual(specs.count, 60)

        // First event (day 0, first meal) should preserve all its nudges (nudge 0, 1, 2)
        let day0Meal0Specs = specs.filter { $0.itemId == "meal_0_0" }
        XCTAssertEqual(day0Meal0Specs.count, 3)

        // Far event (day 2, last meal) should have lost its late nudges first
        let day2LastMealSpecs = specs.filter { $0.itemId == "meal_2_7" }
        XCTAssertTrue(day2LastMealSpecs.count < 3)
    }
}
