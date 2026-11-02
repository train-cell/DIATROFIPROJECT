import Foundation

/// MacroFactor-style Dynamic Total Daily Energy Expenditure (TDEE) and Trend Weight Estimator.
/// Uses an Exponential Moving Average (EMA) for smoothed weight display and ordinary least squares (OLS)
/// linear regression for robust rate-of-change estimation free from water retention noise.
/// Expenditure = Intake - (Rate of Change * 7,700 kcal / kg).
public struct DailyWeightLog: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var weightKg: Double
    public var intakeKcal: Double

    public init(id: UUID = UUID(), date: Date, weightKg: Double, intakeKcal: Double) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.intakeKcal = intakeKcal
    }
}

public struct ExpenditureResult: Codable, Equatable, Sendable {
    public let currentTrendWeightKg: Double
    public let estimatedTdeeKcal: Double
    public let weightChangePerWeekKg: Double
    public let confidenceScore: Double // 0.0 to 1.0 based on data points
    public let dailySurplusDeficit: Double

    public init(
        currentTrendWeightKg: Double,
        estimatedTdeeKcal: Double,
        weightChangePerWeekKg: Double,
        confidenceScore: Double,
        dailySurplusDeficit: Double
    ) {
        self.currentTrendWeightKg = currentTrendWeightKg
        self.estimatedTdeeKcal = estimatedTdeeKcal
        self.weightChangePerWeekKg = weightChangePerWeekKg
        self.confidenceScore = confidenceScore
        self.dailySurplusDeficit = dailySurplusDeficit
    }
}

public enum ExpenditureEngine {
    /// 1 kg of body mass delta is approximately 7,700 kcal.
    public static let kcalPerKgBodyMass: Double = 7700.0
    public static let defaultAlpha: Double = 0.25 // EMA smoothing factor

    /// Computes exponential moving average (EMA) trend weights for a chronological series.
    public static func computeTrendWeights(logs: [DailyWeightLog], alpha: Double = defaultAlpha) -> [Double] {
        guard !logs.isEmpty else { return [] }
        var trends: [Double] = []
        var current = logs[0].weightKg
        trends.append(current)

        for log in logs.dropFirst() {
            current = alpha * log.weightKg + (1.0 - alpha) * current
            trends.append(current)
        }
        return trends
    }

    /// Computes rate of weight change in kg/day using Ordinary Least Squares (OLS) linear regression.
    /// Uses actual calendar day differences from the first log date to handle non-consecutive entries cleanly.
    public static func computeDailyRateOfChange(logs: [DailyWeightLog], calendar: Calendar = Calendar.current) -> Double {
        let n = Double(logs.count)
        guard n >= 2, let firstDate = logs.first?.date else { return 0.0 }

        var dayOffsets: [Double] = []
        var sumT: Double = 0.0
        var sumW: Double = 0.0

        for log in logs {
            let days = Double(calendar.dateComponents([.day], from: firstDate, to: log.date).day ?? 0)
            dayOffsets.append(days)
            sumT += days
            sumW += log.weightKg
        }

        let meanT = sumT / n
        let meanW = sumW / n

        var numerator: Double = 0.0
        var denominator: Double = 0.0
        for i in 0..<logs.count {
            let dt = dayOffsets[i] - meanT
            let dw = logs[i].weightKg - meanW
            numerator += dt * dw
            denominator += dt * dt
        }

        guard denominator > 0 else { return 0.0 }
        return numerator / denominator
    }

    /// Evaluates dynamic TDEE based on logs spanning 3 to 30 days.
    public static func estimateExpenditure(logs: [DailyWeightLog], baselineTdee: Double = 2600.0) -> ExpenditureResult {
        guard logs.count >= 3 else {
            let lastWeight = logs.last?.weightKg ?? 80.0
            return ExpenditureResult(
                currentTrendWeightKg: lastWeight,
                estimatedTdeeKcal: baselineTdee,
                weightChangePerWeekKg: 0.0,
                confidenceScore: Double(logs.count) / 7.0,
                dailySurplusDeficit: 0.0
            )
        }

        let sortedLogs = logs.sorted { $0.date < $1.date }
        let trendWeights = computeTrendWeights(logs: sortedLogs)
        let lastTrend = trendWeights.last ?? (sortedLogs.last?.weightKg ?? 80.0)

        // Robust daily rate of change via linear regression
        let dailyWeightRate = computeDailyRateOfChange(logs: sortedLogs)
        let weeklyRate = dailyWeightRate * 7.0

        let totalIntake = sortedLogs.reduce(0.0) { $0 + $1.intakeKcal }
        let averageDailyIntake = totalIntake / Double(sortedLogs.count)

        // Energy balance: intake - expenditure = weightRate * 7700
        // => expenditure = intake - (weightRate * 7700)
        let dailyKcalDelta = dailyWeightRate * kcalPerKgBodyMass
        let calculatedTdee = averageDailyIntake - dailyKcalDelta

        // Clamping to humanly plausible athletic boundaries [1400, 4800]
        let clampedTdee = min(max(calculatedTdee, 1400.0), 4800.0)

        // Confidence increases with more logged days, reaching 1.0 at 14 days
        let confidence = min(Double(sortedLogs.count) / 14.0, 1.0)

        return ExpenditureResult(
            currentTrendWeightKg: round(lastTrend * 100.0) / 100.0,
            estimatedTdeeKcal: round(clampedTdee),
            weightChangePerWeekKg: round(weeklyRate * 1000.0) / 1000.0,
            confidenceScore: round(confidence * 100.0) / 100.0,
            dailySurplusDeficit: round(averageDailyIntake - clampedTdee)
        )
    }
}
