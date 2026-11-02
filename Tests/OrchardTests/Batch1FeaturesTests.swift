import XCTest
@testable import OrchardDomain

final class Batch1FeaturesTests: XCTestCase {

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

    // MARK: - 1. Dynamic TDEE Expenditure Engine Tests
    func testExpenditureTrendWeightAndTdeeCalculation() {
        // Simulating a 14-day steady cut:
        // Weight drops from 82.0 to 81.0 (-1.0 kg in 14 days = ~ -0.5 kg/week)
        // Average intake is 2200 kcal/day.
        // Expected TDEE = intake - dailyKcalDelta = 2200 - (-1.0/13 * 7700) = 2200 + 592 = ~2792 kcal.
        var logs: [DailyWeightLog] = []
        for d in 1...14 {
            let weight = 82.0 - (Double(d - 1) / 13.0) * 1.0
            logs.append(DailyWeightLog(date: makeDate(day: d), weightKg: weight, intakeKcal: 2200))
        }

        let result = ExpenditureEngine.estimateExpenditure(logs: logs)
        XCTAssertEqual(result.confidenceScore, 1.0, "14 days of logs should give maximum 1.0 confidence")
        XCTAssertTrue(result.estimatedTdeeKcal > 2600 && result.estimatedTdeeKcal < 2900, "Calculated TDEE should be ~2700-2850 kcal")
        XCTAssertTrue(result.weightChangePerWeekKg < -0.45 && result.weightChangePerWeekKg > -0.60)
        XCTAssertTrue(result.dailySurplusDeficit < -400, "User should be in a solid caloric deficit")
    }

    func testExpenditureGracefulFallbackWithFewerThanThreeLogs() {
        let logs = [
            DailyWeightLog(date: makeDate(day: 1), weightKg: 85.0, intakeKcal: 2500),
            DailyWeightLog(date: makeDate(day: 2), weightKg: 84.8, intakeKcal: 2400)
        ]
        let result = ExpenditureEngine.estimateExpenditure(logs: logs, baselineTdee: 2600.0)
        XCTAssertEqual(result.estimatedTdeeKcal, 2600.0)
        XCTAssertEqual(result.currentTrendWeightKg, 84.8)
    }

    // MARK: - 2. Micronutrient & Electrolyte Engine Tests
    func testMicronutrientAggregationAndElectrolyteScore() {
        var intake = MicronutrientIntake()
        intake.sodiumMg = 3500.0     // 100% of athletic target
        intake.potassiumMg = 3800.0  // 100%
        intake.magnesiumMg = 450.0   // 100%
        intake.calciumMg = 1200.0    // 100%
        intake.fiberGrams = 40.0     // 105% (exceeds 38g)

        let score = MicronutrientEngine.electrolyteScore(intake: intake)
        XCTAssertEqual(score, 100, "Full electrolyte fulfillment should score 100%")

        let progress = MicronutrientEngine.evaluateProgress(intake: intake)
        XCTAssertEqual(progress.count, 9)
        let fiberItem = progress.first { $0.name.contains("Φυτικές Ίνες") }
        XCTAssertNotNil(fiberItem)
        XCTAssertEqual(fiberItem?.percentage, 100)
        XCTAssertTrue(fiberItem?.isFulfilled ?? false)
    }

    // MARK: - 3. Smart Coaching Check-In Engine Tests
    func testCoachingRejectsAdjustmentWhenAdherenceIsLow() {
        let report = CoachingCheckInEngine.evaluateCheckIn(
            goal: .fatLoss,
            currentDailyKcal: 2200,
            weeklyWeightChangeKg: +0.2, // weight went up, but adherence was poor!
            adherenceRate: 0.60
        )

        XCTAssertFalse(report.requiresAction, "Check-in must not change calories if adherence < 75%")
        XCTAssertEqual(report.deltaCalories, 0.0)
        XCTAssertTrue(report.rationale.contains("Η συμμόρφωση στο πρόγραμμα ήταν 60%"))
    }

    func testCoachingCutsCaloriesWhenFatLossStalls() {
        let report = CoachingCheckInEngine.evaluateCheckIn(
            goal: .fatLoss,
            currentDailyKcal: 2400,
            weeklyWeightChangeKg: -0.05, // Stalled! Target is -0.3 to -0.75 kg
            adherenceRate: 0.90
        )

        XCTAssertTrue(report.requiresAction)
        XCTAssertEqual(report.deltaCalories, -140.0)
        XCTAssertEqual(report.recommendedCalories, 2260.0)
        XCTAssertEqual(report.deltaProteinGrams, 0.0, "Protein must stay untouched")
        XCTAssertTrue(report.deltaCarbsGrams < 0.0)
        XCTAssertTrue(report.deltaFatsGrams < 0.0)
    }

    // MARK: - 4. Intermittent Fasting Engine Tests
    func testFastingStagesProgression() {
        let start = makeDate(day: 1, hour: 20) // 20:00 last meal

        // 2 hours in -> digestion
        let t1 = makeDate(day: 1, hour: 22)
        let s1 = FastingEngine.evaluateStatus(lastMealTime: start, currentTime: t1, protocolType: .classic16_8)
        XCTAssertTrue(s1.isFasting)
        XCTAssertEqual(s1.stage, .digestion)
        XCTAssertEqual(s1.hoursElapsed, 2.0)

        // 8 hours in -> fat burning
        let t2 = makeDate(day: 2, hour: 4)
        let s2 = FastingEngine.evaluateStatus(lastMealTime: start, currentTime: t2, protocolType: .classic16_8)
        XCTAssertEqual(s2.stage, .fatBurning)

        // 14 hours in -> ketosis transition
        let t3 = makeDate(day: 2, hour: 10)
        let s3 = FastingEngine.evaluateStatus(lastMealTime: start, currentTime: t3, protocolType: .classic16_8)
        XCTAssertEqual(s3.stage, .ketosisTransition)

        // 17 hours in -> autophagy zone (goal complete)
        let t4 = makeDate(day: 2, hour: 13)
        let s4 = FastingEngine.evaluateStatus(lastMealTime: start, currentTime: t4, protocolType: .classic16_8)
        XCTAssertTrue(s4.isGoalCompleted)
        XCTAssertEqual(s4.stage, .autophagyStage)
        XCTAssertEqual(s4.progressFraction, 1.0)
    }
}
