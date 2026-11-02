import Foundation

/// Calculated summary of weekly adherence, calorie balance, and sleep correlation.
public struct WeeklyStats: Equatable, Sendable {
    public var totalPlannedMeals: Int
    public var completedMeals: Int
    public var skippedMeals: Int
    public var overdueMeals: Int
    public var mealAdherencePercentage: Double

    public var totalPlannedSupplements: Int
    public var completedSupplements: Int
    public var supplementAdherencePercentage: Double

    public var averageDailyCalorieBalance: Double

    // Sleep Analytics: Training Days vs Rest Days
    public var trainingDaysSleepCount: Int
    public var trainingDaysAverageSleepMinutes: Double
    public var trainingDaysAverageRating: Double

    public var restDaysSleepCount: Int
    public var restDaysAverageSleepMinutes: Double
    public var restDaysAverageRating: Double

    // Overall Sleep
    public var overallAverageSleepMinutes: Double
    public var overallAverageRating: Double

    public init(
        totalPlannedMeals: Int = 0,
        completedMeals: Int = 0,
        skippedMeals: Int = 0,
        overdueMeals: Int = 0,
        mealAdherencePercentage: Double = 100.0,
        totalPlannedSupplements: Int = 0,
        completedSupplements: Int = 0,
        supplementAdherencePercentage: Double = 100.0,
        averageDailyCalorieBalance: Double = 0.0,
        trainingDaysSleepCount: Int = 0,
        trainingDaysAverageSleepMinutes: Double = 0.0,
        trainingDaysAverageRating: Double = 0.0,
        restDaysSleepCount: Int = 0,
        restDaysAverageSleepMinutes: Double = 0.0,
        restDaysAverageRating: Double = 0.0,
        overallAverageSleepMinutes: Double = 0.0,
        overallAverageRating: Double = 0.0
    ) {
        self.totalPlannedMeals = totalPlannedMeals
        self.completedMeals = completedMeals
        self.skippedMeals = skippedMeals
        self.overdueMeals = overdueMeals
        self.mealAdherencePercentage = mealAdherencePercentage
        self.totalPlannedSupplements = totalPlannedSupplements
        self.completedSupplements = completedSupplements
        self.supplementAdherencePercentage = supplementAdherencePercentage
        self.averageDailyCalorieBalance = averageDailyCalorieBalance
        self.trainingDaysSleepCount = trainingDaysSleepCount
        self.trainingDaysAverageSleepMinutes = trainingDaysAverageSleepMinutes
        self.trainingDaysAverageRating = trainingDaysAverageRating
        self.restDaysSleepCount = restDaysSleepCount
        self.restDaysAverageSleepMinutes = restDaysAverageSleepMinutes
        self.restDaysAverageRating = restDaysAverageRating
        self.overallAverageSleepMinutes = overallAverageSleepMinutes
        self.overallAverageRating = overallAverageRating
    }
}

/// Pure deterministic calculator for weekly adherence and sleep correlation analytics.
public struct WeeklyStatsCalculator {

    /// Calculates weekly statistics deterministically.
    ///
    /// - Parameters:
    ///   - events: Scheduled events across the evaluation period.
    ///   - logs: Recorded log entries across the evaluation period.
    ///   - sleepEntries: Recorded sleep records.
    ///   - trainingDays: Set of "yyyy-MM-dd" strings indicating days with training sessions.
    ///   - dailyBalances: List of calorie surplus/deficits for each day.
    ///   - now: Reference timestamp for overdue calculations.
    ///   - calendar: Calendar used for date matching.
    /// - Returns: A complete `WeeklyStats` structure.
    public static func calculate(
        events: [ScheduledEvent],
        logs: [LogEntry],
        sleepEntries: [SleepEntry] = [],
        trainingDays: Set<String> = [],
        dailyBalances: [Double] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklyStats {
        // 1. Build log lookups
        var statusByEventKey: [String: LogStatus] = [:]
        for log in logs {
            statusByEventKey[log.eventKey] = log.status
            statusByEventKey[log.itemId] = log.status
        }

        // 2. Meal Adherence
        var totalPlannedMeals = 0
        var completedMeals = 0
        var skippedMeals = 0
        var overdueMeals = 0

        var totalPlannedSupplements = 0
        var completedSupplements = 0

        for event in events {
            let dateString = formatDate(date: event.date, calendar: calendar)
            let eventKey = "\(event.itemId).\(dateString)"
            let status = statusByEventKey[eventKey] ?? statusByEventKey[event.itemId]

            if event.item.type == .meal {
                totalPlannedMeals += 1
                switch status {
                case .done:
                    completedMeals += 1
                case .partial:
                    completedMeals += 1
                case .skipped:
                    skippedMeals += 1
                case .swapped:
                    completedMeals += 1
                case .none:
                    if event.resolvedTime < now {
                        overdueMeals += 1
                    }
                }
            } else if event.item.type == .supplement {
                totalPlannedSupplements += 1
                if status == .done {
                    completedSupplements += 1
                }
            }
        }

        let mealAdherence = totalPlannedMeals > 0
            ? (Double(completedMeals) / Double(totalPlannedMeals) * 100.0)
            : 100.0

        let supplementAdherence = totalPlannedSupplements > 0
            ? (Double(completedSupplements) / Double(totalPlannedSupplements) * 100.0)
            : 100.0

        // 3. Average Daily Calorie Balance
        let averageDailyBalance: Double
        if !dailyBalances.isEmpty {
            averageDailyBalance = dailyBalances.reduce(0.0, +) / Double(dailyBalances.count)
        } else {
            averageDailyBalance = 0.0
        }

        // 4. Sleep Correlation (Training Days vs Rest Days)
        var trainingSleepMinutes: [Int] = []
        var trainingRatings: [Int] = []

        var restSleepMinutes: [Int] = []
        var restRatings: [Int] = []

        var allSleepMinutes: [Int] = []
        var allRatings: [Int] = []

        for entry in sleepEntries {
            let dateString = formatDate(date: entry.date, calendar: calendar)
            let isTraining = trainingDays.contains(dateString)

            if let minutes = entry.asleepMinutes {
                allSleepMinutes.append(minutes)
                if isTraining {
                    trainingSleepMinutes.append(minutes)
                } else {
                    restSleepMinutes.append(minutes)
                }
            }

            allRatings.append(entry.rating)
            if isTraining {
                trainingRatings.append(entry.rating)
            } else {
                restRatings.append(entry.rating)
            }
        }

        func avg(_ values: [Int]) -> Double {
            guard !values.isEmpty else { return 0.0 }
            return Double(values.reduce(0, +)) / Double(values.count)
        }

        return WeeklyStats(
            totalPlannedMeals: totalPlannedMeals,
            completedMeals: completedMeals,
            skippedMeals: skippedMeals,
            overdueMeals: overdueMeals,
            mealAdherencePercentage: mealAdherence,
            totalPlannedSupplements: totalPlannedSupplements,
            completedSupplements: completedSupplements,
            supplementAdherencePercentage: supplementAdherence,
            averageDailyCalorieBalance: averageDailyBalance,
            trainingDaysSleepCount: trainingRatings.count,
            trainingDaysAverageSleepMinutes: avg(trainingSleepMinutes),
            trainingDaysAverageRating: avg(trainingRatings),
            restDaysSleepCount: restRatings.count,
            restDaysAverageSleepMinutes: avg(restSleepMinutes),
            restDaysAverageRating: avg(restRatings),
            overallAverageSleepMinutes: avg(allSleepMinutes),
            overallAverageRating: avg(allRatings)
        )
    }

    private static func formatDate(date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return ""
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
