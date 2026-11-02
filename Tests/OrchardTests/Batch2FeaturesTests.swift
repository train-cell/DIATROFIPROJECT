import XCTest
@testable import OrchardDomain

final class Batch2FeaturesTests: XCTestCase {

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

    // MARK: - 5. Habit Streak Engine Tests
    func testHabitStreakCalculation() {
        var history: [DailyHabitStatus] = []
        // Days 1, 2, 3: Perfect
        // Day 4: Nutrition missed
        // Days 5, 6, 7: Perfect
        let days = [
            (1, true), (2, true), (3, true),
            (4, false),
            (5, true), (6, true), (7, true)
        ]
        for (d, nut) in days {
            history.append(DailyHabitStatus(
                date: makeDate(day: d),
                isNutritionCompleted: nut,
                isHydrationCompleted: true,
                isSleepCompleted: true,
                isSupplementsCompleted: true
            ))
        }

        let summary = HabitStreakEngine.computeStreaks(history: history)
        XCTAssertEqual(summary.currentStreakDays, 3, "Days 5, 6, 7 form current 3-day perfect streak")
        XCTAssertEqual(summary.longestStreakDays, 3)
        XCTAssertEqual(summary.totalPerfectDays, 6)
        XCTAssertEqual(summary.hydrationStreakDays, 7, "Hydration was 100% across all 7 days")
    }

    // MARK: - 6. Staple Foods Library Tests
    func testStapleFoodSearchAndBarcodeLookup() {
        // Search
        let results = StapleFoodLibrary.search(query: "Κοτόπουλο")
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results[0].id, "chk_brst")

        // Barcode lookup
        let item = StapleFoodLibrary.lookup(barcode: "5201001000104")
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.nameGreek, "Whey Protein Isolate (100g)")

        // Macro scaling: 30g scoop of Whey Isolate
        let scoop = item!.macros(forGrams: 30.0)
        XCTAssertEqual(scoop.kcal, 111.0)
        XCTAssertEqual(scoop.p, 25.8)
    }

    // MARK: - 7. Peri-Workout Timing Engine Tests
    func testPeriWorkoutPhases() {
        let workoutStart = makeDate(day: 2, hour: 18) // 18:00
        let workoutEnd = makeDate(day: 2, hour: 19)   // 19:00

        // 17:15 (45 min before) -> Pre-workout fuel window
        let tPre = makeDate(day: 2, hour: 17, minute: 15)
        let sPre = PeriWorkoutEngine.evaluatePhase(workoutStart: workoutStart, workoutEnd: workoutEnd, currentTime: tPre)
        XCTAssertEqual(sPre.phase, .preWorkoutFuel)
        XCTAssertEqual(sPre.minutesToNextPhase, 45)
        XCTAssertFalse(sPre.isCurrentlyTraining)

        // 18:30 (during) -> Intra-workout hydration
        let tIntra = makeDate(day: 2, hour: 18, minute: 30)
        let sIntra = PeriWorkoutEngine.evaluatePhase(workoutStart: workoutStart, workoutEnd: workoutEnd, currentTime: tIntra)
        XCTAssertEqual(sIntra.phase, .intraWorkoutHydration)
        XCTAssertTrue(sIntra.isCurrentlyTraining)
        XCTAssertEqual(sIntra.minutesToNextPhase, 30)

        // 19:15 (15 min after end) -> Anabolic post-workout window active
        let tPost = makeDate(day: 2, hour: 19, minute: 15)
        let sPost = PeriWorkoutEngine.evaluatePhase(workoutStart: workoutStart, workoutEnd: workoutEnd, currentTime: tPost)
        XCTAssertEqual(sPost.phase, .postWorkoutAnabolic)
        XCTAssertTrue(sPost.isAnabolicWindowActive)
        XCTAssertEqual(sPost.minutesToNextPhase, 30) // 45 - 15 = 30 left
    }

    // MARK: - 8. Custom Recipe Builder Tests
    func testRecipeBuilderMacroAggregation() {
        let oats = StapleFoodLibrary.lookup(barcode: "5201001000108")!      // 100g oats
        let whey = StapleFoodLibrary.lookup(barcode: "5201001000104")!      // Whey isolate
        let pb = StapleFoodLibrary.lookup(barcode: "5201001000113")!        // Peanut butter

        let ing1 = RecipeIngredient.fromStaple(item: oats, grams: 80.0)    // 80g oats
        let ing2 = RecipeIngredient.fromStaple(item: whey, grams: 35.0)    // 35g whey
        let ing3 = RecipeIngredient.fromStaple(item: pb, grams: 20.0)      // 20g peanut butter

        let recipe = CustomRecipe(
            titleGreek: "Power Proats (Oatmeal + Whey + Peanut Butter)",
            servings: 1,
            ingredients: [ing1, ing2, ing3]
        )

        XCTAssertEqual(recipe.totalGrams, 135.0)
        XCTAssertTrue(recipe.totalProtein > 45.0, "Expected high protein proats bowl (>45g protein)")
        XCTAssertTrue(recipe.totalCarbs > 55.0)
        XCTAssertTrue(recipe.totalKcal > 500.0)

        // Convert to PlanItem
        let planItem = recipe.toPlanItem(id: "custom_proats", anchor: .afterWake(minutes: 30))
        XCTAssertEqual(planItem.id, "custom_proats")
        XCTAssertEqual(planItem.title, "Power Proats (Oatmeal + Whey + Peanut Butter)")
        XCTAssertEqual(planItem.kcal, recipe.perServingKcal)
    }

    private func makeDate(day: Int, hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }
}
