import XCTest
@testable import OrchardDomain

final class PlanDraftValidatorTests: XCTestCase {

    func testValidPlanPasses() {
        let plan = Plan(
            version: 1,
            settings: PlanSettings(wake: "07:30", bed: "23:30", minMealGapMinutes: 90),
            weekly: ["mon": "training"],
            templates: [
                "training": DayTemplate(
                    trainingSessions: [TrainingSession(start: "18:00", durationMinutes: 90)],
                    items: [
                        PlanItem(id: "breakfast", type: .meal, title: "Breakfast", anchor: .afterWake(minutes: 30), fallbackTime: "08:00"),
                        PlanItem(id: "supp1", type: .supplement, title: "Vitamins", anchor: .withItem(itemId: "breakfast"))
                    ],
                    rules: []
                )
            ]
        )

        let result = PlanDraftValidator.validate(plan: plan)
        XCTAssertEqual(result, .valid)
    }

    func testMissingWithItemReferenceIsInvalid() {
        let plan = Plan(
            version: 1,
            settings: PlanSettings(wake: "07:30", bed: "23:30"),
            weekly: ["mon": "training"],
            templates: [
                "training": DayTemplate(
                    trainingSessions: [],
                    items: [
                        PlanItem(id: "supp1", type: .supplement, title: "Vitamins", anchor: .withItem(itemId: "non_existent_meal"))
                    ]
                )
            ]
        )

        let result = PlanDraftValidator.validate(plan: plan)
        if case .invalid(let reasons) = result {
            XCTAssertTrue(reasons.contains(where: { $0.contains("non_existent_meal") }))
        } else {
            XCTFail("Expected .invalid for dangling withItem reference, got \(result)")
        }
    }

    func testInvalidTimeFormatIsInvalid() {
        let plan = Plan(
            version: 1,
            settings: PlanSettings(wake: "25:70", bed: "23:30"), // Invalid wake time
            weekly: ["mon": "training"],
            templates: [
                "training": DayTemplate(
                    trainingSessions: [],
                    items: [
                        PlanItem(id: "breakfast", type: .meal, title: "Breakfast", anchor: .absolute(time: "99:99"))
                    ]
                )
            ]
        )

        let result = PlanDraftValidator.validate(plan: plan)
        if case .invalid(let reasons) = result {
            XCTAssertFalse(reasons.isEmpty)
        } else {
            XCTFail("Expected .invalid for invalid time strings, got \(result)")
        }
    }

    func testDuplicateItemIDsAreInvalid() {
        let plan = Plan(
            version: 1,
            settings: PlanSettings(wake: "07:30", bed: "23:30"),
            weekly: ["mon": "training"],
            templates: [
                "training": DayTemplate(
                    trainingSessions: [],
                    items: [
                        PlanItem(id: "meal1", type: .meal, title: "Lunch", anchor: .absolute(time: "13:00")),
                        PlanItem(id: "meal1", type: .meal, title: "Dinner", anchor: .absolute(time: "20:00")) // duplicate ID
                    ]
                )
            ]
        )

        let result = PlanDraftValidator.validate(plan: plan)
        if case .invalid(let reasons) = result {
            XCTAssertTrue(reasons.contains(where: { $0.contains("duplicate") }))
        } else {
            XCTFail("Expected .invalid for duplicate item IDs, got \(result)")
        }
    }
}
