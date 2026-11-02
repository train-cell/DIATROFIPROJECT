import XCTest
@testable import OrchardDomain

final class WeeklyStatsTests: XCTestCase {

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDate(day: Int, hour: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = day
        comps.hour = hour
        comps.minute = 0
        comps.second = 0
        return utcCalendar.date(from: comps)!
    }

    func testMealAndSupplementAdherenceCalculation() {
        let meal1 = PlanItem(id: "m1", type: .meal, title: "Breakfast", anchor: .absolute(time: "08:00"), kcal: 500)
        let meal2 = PlanItem(id: "m2", type: .meal, title: "Lunch", anchor: .absolute(time: "13:00"), kcal: 700)
        let meal3 = PlanItem(id: "m3", type: .meal, title: "Dinner", anchor: .absolute(time: "20:00"), kcal: 600)
        let supp1 = PlanItem(id: "s1", type: .supplement, title: "Vitamins", anchor: .absolute(time: "08:00"))
        let supp2 = PlanItem(id: "s2", type: .supplement, title: "Magnesium", anchor: .absolute(time: "22:00"))

        let dayDate = makeDate(day: 2, hour: 0)

        let events: [ScheduledEvent] = [
            ScheduledEvent(id: "evt.m1.20261102", itemId: "m1", item: meal1, date: dayDate, resolvedTime: makeDate(day: 2, hour: 8)),
            ScheduledEvent(id: "evt.m2.20261102", itemId: "m2", item: meal2, date: dayDate, resolvedTime: makeDate(day: 2, hour: 13)),
            ScheduledEvent(id: "evt.m3.20261102", itemId: "m3", item: meal3, date: dayDate, resolvedTime: makeDate(day: 2, hour: 20)),
            ScheduledEvent(id: "evt.s1.20261102", itemId: "s1", item: supp1, date: dayDate, resolvedTime: makeDate(day: 2, hour: 8)),
            ScheduledEvent(id: "evt.s2.20261102", itemId: "s2", item: supp2, date: dayDate, resolvedTime: makeDate(day: 2, hour: 22))
        ]

        // User completed m1 and m2, skipped m3. Completed s1, missed s2.
        let logs: [LogEntry] = [
            LogEntry(eventKey: "m1.20261102", itemId: "m1", status: .done, timestamp: makeDate(day: 2, hour: 8)),
            LogEntry(eventKey: "m2.20261102", itemId: "m2", status: .done, timestamp: makeDate(day: 2, hour: 13)),
            LogEntry(eventKey: "m3.20261102", itemId: "m3", status: .skipped, timestamp: makeDate(day: 2, hour: 20)),
            LogEntry(eventKey: "s1.20261102", itemId: "s1", status: .done, timestamp: makeDate(day: 2, hour: 8))
        ]

        let stats = WeeklyStatsCalculator.calculate(
            events: events,
            logs: logs,
            now: makeDate(day: 2, hour: 23),
            calendar: utcCalendar
        )

        // Meals: 3 planned, 2 completed, 1 skipped -> 2/3 = 66.67%
        XCTAssertEqual(stats.totalPlannedMeals, 3)
        XCTAssertEqual(stats.completedMeals, 2)
        XCTAssertEqual(stats.skippedMeals, 1)
        XCTAssertEqual(stats.overdueMeals, 0)
        XCTAssertEqual(stats.mealAdherencePercentage, 66.67, accuracy: 0.1)

        // Supplements: 2 planned, 1 completed -> 1/2 = 50.0%
        XCTAssertEqual(stats.totalPlannedSupplements, 2)
        XCTAssertEqual(stats.completedSupplements, 1)
        XCTAssertEqual(stats.supplementAdherencePercentage, 50.0, accuracy: 0.1)
    }

    func testSleepCorrelationBetweenTrainingAndRestDays() {
        // Nov 2: Training Day. Nov 3: Training Day.
        // Nov 4: Rest Day. Nov 5: Rest Day.
        let trainingDays: Set<String> = ["2026-11-02", "2026-11-03"]

        let sleepEntries: [SleepEntry] = [
            // Training days sleep:
            SleepEntry(date: makeDate(day: 2), rating: 5, asleepMinutes: 480),
            SleepEntry(date: makeDate(day: 3), rating: 4, asleepMinutes: 450),
            // Rest days sleep:
            SleepEntry(date: makeDate(day: 4), rating: 3, asleepMinutes: 420),
            SleepEntry(date: makeDate(day: 5), rating: 3, asleepMinutes: 390)
        ]

        let stats = WeeklyStatsCalculator.calculate(
            events: [],
            logs: [],
            sleepEntries: sleepEntries,
            trainingDays: trainingDays,
            calendar: utcCalendar
        )

        // Training days: (480 + 450)/2 = 465 mins, rating (5 + 4)/2 = 4.5
        XCTAssertEqual(stats.trainingDaysSleepCount, 2)
        XCTAssertEqual(stats.trainingDaysAverageSleepMinutes, 465.0, accuracy: 0.01)
        XCTAssertEqual(stats.trainingDaysAverageRating, 4.5, accuracy: 0.01)

        // Rest days: (420 + 390)/2 = 405 mins, rating (3 + 3)/2 = 3.0
        XCTAssertEqual(stats.restDaysSleepCount, 2)
        XCTAssertEqual(stats.restDaysAverageSleepMinutes, 405.0, accuracy: 0.01)
        XCTAssertEqual(stats.restDaysAverageRating, 3.0, accuracy: 0.01)

        // Overall: (465 * 2 + 405 * 2) / 4 = 435 mins, rating (4.5 * 2 + 3.0 * 2) / 4 = 3.75
        XCTAssertEqual(stats.overallAverageSleepMinutes, 435.0, accuracy: 0.01)
        XCTAssertEqual(stats.overallAverageRating, 3.75, accuracy: 0.01)
    }

    func testAverageDailyCalorieBalance() {
        let dailyBalances = [-200.0, 100.0, -50.0] // sum = -150, avg = -50.0

        let stats = WeeklyStatsCalculator.calculate(
            events: [],
            logs: [],
            dailyBalances: dailyBalances,
            calendar: utcCalendar
        )

        XCTAssertEqual(stats.averageDailyCalorieBalance, -50.0, accuracy: 0.01)
    }

    func testZeroPlannedMealsEdgeCase() {
        let stats = WeeklyStatsCalculator.calculate(
            events: [],
            logs: [],
            calendar: utcCalendar
        )

        XCTAssertEqual(stats.totalPlannedMeals, 0)
        XCTAssertEqual(stats.completedMeals, 0)
        XCTAssertEqual(stats.mealAdherencePercentage, 100.0)
        XCTAssertEqual(stats.totalPlannedSupplements, 0)
        XCTAssertEqual(stats.supplementAdherencePercentage, 100.0)
    }
}
