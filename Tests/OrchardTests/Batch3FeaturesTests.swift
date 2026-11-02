import XCTest
@testable import OrchardDomain

final class Batch3FeaturesTests: XCTestCase {

    private var calendar: Calendar {
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
        return calendar.date(from: comps)!
    }

    // MARK: - 9. Digestive Wellness Journal Tests
    func testDigestiveWellnessScoreCalculation() {
        // Optimal digestion meal
        let logOptimal = DigestiveLog(
            mealEventId: "m1",
            satiety: .pleasantlySatisfied,
            energy: .steady,
            symptoms: [.optimal]
        )
        XCTAssertEqual(logOptimal.wellnessScore, 100)

        // Heavy meal with symptoms
        let logHeavy = DigestiveLog(
            mealEventId: "m2",
            satiety: .stuffed,
            energy: .foodComa,
            symptoms: [.heavyStomach, .acidReflux]
        )
        // 100 - 25 (heavy) - 30 (acidReflux) - 20 (foodComa) - 15 (stuffed) = 10
        XCTAssertEqual(logHeavy.wellnessScore, 10)
    }

    // MARK: - 10. Workout Strain vs Carbs Fueling Engine Tests
    func testWorkoutFuelingScoreEvaluation() {
        // 600 kcal workout -> Glycogen: 600 * 0.65 = 390 kcal -> 390 / 4 = ~98g carbs required
        // Case 1: Underfueled (only 30g carbs)
        let underfueled = WorkoutFuelEngine.evaluateFueling(workoutBurnKcal: 600, periWorkoutCarbsConsumedGrams: 30)
        XCTAssertEqual(underfueled.status, .underfueled)
        XCTAssertTrue(underfueled.fuelingScore < 40)
        XCTAssertTrue(underfueled.adviceGreek.contains("Χαμηλή πρόσληψη υδατανθράκων"))

        // Case 2: Optimal fueling (100g carbs consumed)
        let optimal = WorkoutFuelEngine.evaluateFueling(workoutBurnKcal: 600, periWorkoutCarbsConsumedGrams: 100)
        XCTAssertEqual(optimal.status, .optimal)
        XCTAssertEqual(optimal.fuelingScore, 100)
        XCTAssertTrue(optimal.adviceGreek.contains("Άριστος ενεργειακός ανεφοδιασμός"))
    }

    // MARK: - 11. Weight Projection Timeline Tests
    func testWeightProjectionTrajectory() {
        let start = 82.0
        let target = 79.0 // 3.0 kg cut
        let dailyDeficit = -500.0 // 500 kcal deficit / day
        let startDate = makeDate(day: 1)

        let result = WeightProjectionEngine.projectTrajectory(
            startWeightKg: start,
            targetWeightKg: target,
            dailyKcalDelta: dailyDeficit,
            startDate: startDate,
            calendar: calendar
        )

        // 3.0 kg * 7700 kcal / 500 kcal = 46.2 days -> 47 days needed
        XCTAssertEqual(result.totalDaysNeeded, 47)
        XCTAssertFalse(result.isAggressiveCut, "500 kcal deficit on 82kg bodyweight is safe (~0.55 kg/week = 0.67%)")
        XCTAssertEqual(result.milestones.first?.projectedWeightKg, 82.0)
        XCTAssertEqual(result.milestones.last?.projectedWeightKg, 79.0)
    }

    // MARK: - 12. Coach Report & CSV Exporter Tests
    func testReportCSVAndCoachSummaryGeneration() {
        let records = [
            DailyReportRecord(
                dateString: "2026-11-01",
                templateKey: "day_1",
                kcalConsumed: 2350,
                kcalBurned: 2700,
                balanceKcal: -350,
                proteinGrams: 195.0,
                carbsGrams: 230.0,
                fatGrams: 55.0,
                waterMl: 4000,
                sleepHours: 7.8,
                sleepRecoveryScore: 88,
                adherencePercent: 100
            ),
            DailyReportRecord(
                dateString: "2026-11-02",
                templateKey: "day_2",
                kcalConsumed: 2200,
                kcalBurned: 2650,
                balanceKcal: -450,
                proteinGrams: 200.0,
                carbsGrams: 210.0,
                fatGrams: 50.0,
                waterMl: 4250,
                sleepHours: 8.0,
                sleepRecoveryScore: 92,
                adherencePercent: 100
            )
        ]

        // CSV
        let csv = ReportExportEngine.generateCSV(records: records)
        XCTAssertTrue(csv.contains("Date,Template,Kcal_In,Kcal_Out"))
        XCTAssertTrue(csv.contains("2026-11-01,day_1,2350,2700,-350,195.0,230.0,55.0,4000,7.8,88%,100%"))

        // Coach summary
        let summary = ReportExportEngine.generateCoachSummary(athleteName: "John Akrivos", records: records)
        XCTAssertTrue(summary.contains("Αθλητής: John Akrivos"))
        XCTAssertTrue(summary.contains("Μέση Ημερήσια Πρόσληψη: 2275 kcal"))
        XCTAssertTrue(summary.contains("Μέση Ενυδάτωση: 4125 ml / 4000 ml"))
        XCTAssertTrue(summary.contains("Συνολική Συμμόρφωση Γευμάτων: 100%"))
    }
}
