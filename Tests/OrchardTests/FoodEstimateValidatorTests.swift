import XCTest
@testable import OrchardDomain

final class FoodEstimateValidatorTests: XCTestCase {

    func testValidEstimatePasses() {
        // 30g P (120), 50g C (200), 10g F (90) = 410 kcal -> stated 400 kcal (within 15%)
        let result = FoodEstimateValidator.validate(
            kcal: 400,
            protein: 30,
            carbs: 50,
            fat: 10
        )
        XCTAssertEqual(result, .valid)
        XCTAssertTrue(result.isValid)
    }

    func testMacroDiscrepancyGeneratesWarning() {
        // 10g P (40), 10g C (40), 0g F (0) = 80 kcal -> stated 300 kcal (huge discrepancy > 15%)
        let result = FoodEstimateValidator.validate(
            kcal: 300,
            protein: 10,
            carbs: 10,
            fat: 0
        )
        if case .warning(let reasons) = result {
            XCTAssertFalse(reasons.isEmpty)
        } else {
            XCTFail("Expected .warning for macro math mismatch, got \(result)")
        }
        XCTAssertTrue(result.isValid, "Warnings should still be treated as valid for user review")
    }

    func testNegativeNutritionalValuesAreInvalid() {
        let result = FoodEstimateValidator.validate(
            kcal: -100,
            protein: 20,
            carbs: 30,
            fat: 10
        )
        if case .invalid(let reasons) = result {
            XCTAssertFalse(reasons.isEmpty)
        } else {
            XCTFail("Expected .invalid for negative calories, got \(result)")
        }
        XCTAssertFalse(result.isValid)
    }

    func testExcessiveCaloriesAreInvalid() {
        // Over 3500 kcal
        let result = FoodEstimateValidator.validate(
            kcal: 4200,
            protein: 200,
            carbs: 400,
            fat: 150
        )
        if case .invalid(let reasons) = result {
            XCTAssertTrue(reasons.contains(where: { $0.contains("3500") }))
        } else {
            XCTFail("Expected .invalid for calories exceeding 3500 limit, got \(result)")
        }
        XCTAssertFalse(result.isValid)
    }

    func testZeroCaloriesAndMacrosPasses() {
        let result = FoodEstimateValidator.validate(
            kcal: 0,
            protein: 0,
            carbs: 0,
            fat: 0
        )
        XCTAssertEqual(result, .valid)
    }
}
