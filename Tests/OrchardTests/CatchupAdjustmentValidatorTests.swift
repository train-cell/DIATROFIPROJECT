import XCTest
@testable import OrchardDomain

final class CatchupAdjustmentValidatorTests: XCTestCase {

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDate(hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = 2
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return utcCalendar.date(from: comps)!
    }

    func testMoveProposalInPastIsInvalid() {
        let now = makeDate(hour: 14, minute: 0)
        let pastTime = makeDate(hour: 13, minute: 0)

        let proposal = CatchupAdjustmentProposal.move(itemId: "lunch", newTime: pastTime)
        let result = CatchupAdjustmentValidator.validate(
            proposal: proposal,
            existingEvents: [],
            settings: PlanSettings(wake: "07:30", bed: "23:30"),
            now: now,
            calendar: utcCalendar
        )

        if case .invalid(let reasons) = result {
            XCTAssertTrue(reasons.contains(where: { $0.contains("past") }))
        } else {
            XCTFail("Expected .invalid for moving into the past, got \(result)")
        }
    }

    func testMoveViolatingMealGapIsInvalid() {
        let now = makeDate(hour: 12, minute: 0)
        let existingDinner = ScheduledEvent(
            id: "evt.dinner",
            itemId: "dinner",
            item: PlanItem(id: "dinner", type: .meal, title: "Dinner", anchor: .absolute(time: "19:00")),
            date: makeDate(hour: 0, minute: 0),
            resolvedTime: makeDate(hour: 19, minute: 0)
        )

        // Proposed lunch at 18:00 (only 60 mins before dinner, min gap is 90 mins)
        let proposedLunchTime = makeDate(hour: 18, minute: 0)
        let proposal = CatchupAdjustmentProposal.move(itemId: "lunch", newTime: proposedLunchTime)

        let result = CatchupAdjustmentValidator.validate(
            proposal: proposal,
            existingEvents: [existingDinner],
            settings: PlanSettings(wake: "07:30", bed: "23:30", minMealGapMinutes: 90),
            now: now,
            calendar: utcCalendar
        )

        if case .invalid(let reasons) = result {
            XCTAssertTrue(reasons.contains(where: { $0.contains("gap") }))
        } else {
            XCTFail("Expected .invalid for minMealGap violation, got \(result)")
        }
    }

    func testValidMovePasses() {
        let now = makeDate(hour: 12, minute: 0)
        let existingDinner = ScheduledEvent(
            id: "evt.dinner",
            itemId: "dinner",
            item: PlanItem(id: "dinner", type: .meal, title: "Dinner", anchor: .absolute(time: "20:00")),
            date: makeDate(hour: 0, minute: 0),
            resolvedTime: makeDate(hour: 20, minute: 0)
        )

        // Proposed lunch at 15:00 (5 hours before dinner, after now)
        let proposedTime = makeDate(hour: 15, minute: 0)
        let proposal = CatchupAdjustmentProposal.move(itemId: "lunch", newTime: proposedTime)

        let result = CatchupAdjustmentValidator.validate(
            proposal: proposal,
            existingEvents: [existingDinner],
            settings: PlanSettings(wake: "07:30", bed: "23:30", minMealGapMinutes: 90),
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(result, .valid)
    }

    func testSkipProposalIsValid() {
        let proposal = CatchupAdjustmentProposal.skip(itemId: "lunch")
        let result = CatchupAdjustmentValidator.validate(
            proposal: proposal,
            existingEvents: [],
            settings: PlanSettings(wake: "07:30", bed: "23:30"),
            now: Date(),
            calendar: utcCalendar
        )
        XCTAssertEqual(result, .valid)
    }
}
