import Foundation

/// MacroFactor-style Goal Weight Projection and Caloric Deficit/Surplus Curve Engine.
/// Computes future milestone timeline, estimated target completion date, and safe rate-of-loss guardrails.
public struct WeightMilestone: Codable, Equatable, Sendable, Identifiable {
    public var id: Int { weekIndex }
    public let weekIndex: Int
    public let date: Date
    public let projectedWeightKg: Double
}

public struct WeightProjectionResult: Codable, Equatable, Sendable {
    public let startWeightKg: Double
    public let targetWeightKg: Double
    public let dailyKcalDelta: Double             // Negative for deficit, positive for surplus
    public let weeklyRateKg: Double
    public let totalDaysNeeded: Int
    public let targetCompletionDate: Date
    public let isAggressiveCut: Bool             // > 1.0% bodyweight per week
    public let milestones: [WeightMilestone]

    public init(
        startWeightKg: Double,
        targetWeightKg: Double,
        dailyKcalDelta: Double,
        weeklyRateKg: Double,
        totalDaysNeeded: Int,
        targetCompletionDate: Date,
        isAggressiveCut: Bool,
        milestones: [WeightMilestone]
    ) {
        self.startWeightKg = startWeightKg
        self.targetWeightKg = targetWeightKg
        self.dailyKcalDelta = dailyKcalDelta
        self.weeklyRateKg = weeklyRateKg
        self.totalDaysNeeded = totalDaysNeeded
        self.targetCompletionDate = targetCompletionDate
        self.isAggressiveCut = isAggressiveCut
        self.milestones = milestones
    }
}

public enum WeightProjectionEngine {
    public static let kcalPerKg: Double = 7700.0

    /// Projects timeline and weekly milestones from startDate.
    public static func projectTrajectory(
        startWeightKg: Double,
        targetWeightKg: Double,
        dailyKcalDelta: Double, // e.g. -500.0 kcal
        startDate: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> WeightProjectionResult {
        let weightDiff = targetWeightKg - startWeightKg

        // If delta is 0 or opposing direction, return 0-day result
        guard abs(dailyKcalDelta) >= 50.0, (weightDiff * dailyKcalDelta) > 0 else {
            return WeightProjectionResult(
                startWeightKg: startWeightKg,
                targetWeightKg: targetWeightKg,
                dailyKcalDelta: dailyKcalDelta,
                weeklyRateKg: 0.0,
                totalDaysNeeded: 0,
                targetCompletionDate: startDate,
                isAggressiveCut: false,
                milestones: [WeightMilestone(weekIndex: 0, date: startDate, projectedWeightKg: startWeightKg)]
            )
        }

        let dailyRateKg = dailyKcalDelta / kcalPerKg
        let weeklyRateKg = dailyRateKg * 7.0
        let totalDaysFloat = weightDiff / dailyRateKg
        let totalDays = max(1, Int(ceil(abs(totalDaysFloat))))
        let completionDate = calendar.date(byAdding: .day, value: totalDays, to: startDate) ?? startDate

        // Aggressive cut check (> 1.0% bodyweight / week)
        let weeklyPct = abs(weeklyRateKg) / startWeightKg
        let isAggressive = weeklyPct > 0.010

        // Build weekly milestones
        var milestones: [WeightMilestone] = []
        let totalWeeks = max(1, Int(ceil(Double(totalDays) / 7.0)))
        var currentWeight = startWeightKg

        for w in 0...totalWeeks {
            let milestoneDate = calendar.date(byAdding: .day, value: w * 7, to: startDate) ?? startDate
            if w == totalWeeks {
                milestones.append(WeightMilestone(weekIndex: w, date: completionDate, projectedWeightKg: round(targetWeightKg * 10.0) / 10.0))
            } else {
                milestones.append(WeightMilestone(weekIndex: w, date: milestoneDate, projectedWeightKg: round(currentWeight * 10.0) / 10.0))
                currentWeight += weeklyRateKg
            }
        }

        return WeightProjectionResult(
            startWeightKg: startWeightKg,
            targetWeightKg: targetWeightKg,
            dailyKcalDelta: dailyKcalDelta,
            weeklyRateKg: round(weeklyRateKg * 100.0) / 100.0,
            totalDaysNeeded: totalDays,
            targetCompletionDate: completionDate,
            isAggressiveCut: isAggressive,
            milestones: milestones
        )
    }
}
