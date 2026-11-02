import XCTest
@testable import OrchardDomain

final class WeeklyReviewValidatorTests: XCTestCase {

    func testAccurateNarrativePassesValidation() {
        let stats = WeeklyStats(
            totalPlannedMeals: 21,
            completedMeals: 18,
            skippedMeals: 3,
            mealAdherencePercentage: 85.7,
            totalPlannedSupplements: 7,
            completedSupplements: 7,
            supplementAdherencePercentage: 100.0,
            averageDailyCalorieBalance: -150.0,
            trainingDaysSleepCount: 3,
            trainingDaysAverageSleepMinutes: 450,
            trainingDaysAverageRating: 4.2
        )

        let accurateText = """
        Great week! You completed 18 of 21 planned meals, giving an adherence rate of 85.7%.
        Your supplement adherence was 100%, and average deficit was -150 kcal.
        """

        let result = WeeklyReviewValidator.validate(narrative: accurateText, stats: stats)
        XCTAssertEqual(result, .valid)
    }

    func testHallucinatedNumbersGenerateWarning() {
        let stats = WeeklyStats(
            totalPlannedMeals: 21,
            completedMeals: 18,
            mealAdherencePercentage: 85.7
        )

        // Text mentions 98% and 25 meals which never happened
        let hallucinatedText = """
        You had an incredible 98% adherence rate, completing 25 meals!
        """

        let result = WeeklyReviewValidator.validate(narrative: hallucinatedText, stats: stats)
        if case .warning(let reasons) = result {
            XCTAssertFalse(reasons.isEmpty)
        } else {
            XCTFail("Expected .warning for hallucinated numbers, got \(result)")
        }
    }
}
