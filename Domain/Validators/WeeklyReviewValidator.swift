import Foundation

/// Deterministic guardrail for AI-generated weekly narrative reviews, preventing fabricated or hallucinated numbers.
public struct WeeklyReviewValidator {

    /// Validates that numbers cited in narrative text correspond to actual ground-truth weekly statistics.
    public static func validate(narrative: String, stats: WeeklyStats) -> ValidationResult {
        // Collect all legitimate ground truth numbers from WeeklyStats
        let legitimateNumbers: Set<Double> = [
            Double(stats.totalPlannedMeals),
            Double(stats.completedMeals),
            Double(stats.skippedMeals),
            Double(stats.overdueMeals),
            round(stats.mealAdherencePercentage * 10) / 10,
            Double(Int(stats.mealAdherencePercentage)),
            Double(stats.totalPlannedSupplements),
            Double(stats.completedSupplements),
            round(stats.supplementAdherencePercentage * 10) / 10,
            Double(Int(stats.supplementAdherencePercentage)),
            abs(stats.averageDailyCalorieBalance),
            Double(stats.trainingDaysSleepCount),
            Double(stats.restDaysSleepCount),
            round(stats.trainingDaysAverageRating * 10) / 10,
            round(stats.restDaysAverageRating * 10) / 10,
            round(stats.overallAverageRating * 10) / 10,
            round(stats.trainingDaysAverageSleepMinutes),
            round(stats.restDaysAverageSleepMinutes),
            round(stats.overallAverageSleepMinutes),
            7.0, 1.0, 2.0, 3.0, 4.0, 5.0, 0.0 // Allow small day numbers / ratings
        ]

        // Extract numbers from narrative
        let pattern = #"(?<!\w)-?\d+(?:\.\d+)?%?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return .valid
        }

        let nsString = narrative as NSString
        let matches = regex.matches(in: narrative, range: NSRange(location: 0, length: nsString.length))

        var warnings: [String] = []

        for match in matches {
            var rawText = nsString.substring(with: match.range)
            if rawText.hasSuffix("%") {
                rawText.removeLast()
            }
            guard let value = Double(rawText) else { continue }

            let absVal = abs(value)
            // If the number is significant (> 7) and not found in ground truth within +-1.0
            if absVal > 7.0 {
                let matchesAny = legitimateNumbers.contains { groundTruth in
                    abs(groundTruth - absVal) <= 1.0
                }
                if !matchesAny {
                    warnings.append("Narrative cites unverified number '\(rawText)' which does not match weekly stats")
                }
            }
        }

        if !warnings.isEmpty {
            return .warning(reasons: warnings)
        }

        return .valid
    }
}
