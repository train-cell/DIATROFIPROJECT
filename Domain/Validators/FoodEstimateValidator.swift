import Foundation

/// Pure deterministic validator for food calorie and macro estimates suggested by AI.
public struct FoodEstimateValidator {

    public static let maxPlausibleMealCalories: Double = 3500.0
    public static let macroDiscrepancyTolerance: Double = 0.15 // 15%

    /// Validates calories and macros for plausibility and mathematical consistency.
    public static func validate(
        kcal: Double,
        protein: Double,
        carbs: Double,
        fat: Double
    ) -> ValidationResult {
        var invalidReasons: [String] = []
        var warningReasons: [String] = []

        // 1. Non-negativity check
        if kcal < 0 || protein < 0 || carbs < 0 || fat < 0 {
            invalidReasons.append("Nutritional values cannot be negative")
        }

        // 2. Upper bounds check
        if kcal > maxPlausibleMealCalories {
            invalidReasons.append("Calories (\(Int(kcal))) exceed maximum plausible meal limit (3500 kcal)")
        }

        if !invalidReasons.isEmpty {
            return .invalid(reasons: invalidReasons)
        }

        // 3. Macro mathematical consistency check: 4P + 4C + 9F ~= kcal +- 15%
        let calculatedKcal = (4.0 * protein) + (4.0 * carbs) + (9.0 * fat)
        if kcal > 0 && calculatedKcal > 0 {
            let difference = abs(calculatedKcal - kcal)
            let relativeDiff = difference / kcal
            if relativeDiff > macroDiscrepancyTolerance {
                warningReasons.append(
                    "Macro energy (\(Int(calculatedKcal)) kcal) differs by >15% from stated calories (\(Int(kcal)) kcal)"
                )
            }
        }

        if !warningReasons.isEmpty {
            return .warning(reasons: warningReasons)
        }

        return .valid
    }
}
