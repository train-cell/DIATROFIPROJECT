import Foundation

/// Streaks & Carbon-style Multi-Goal Habit Adherence & Ring Engine.
/// Tracks 4 daily athletic disciplines: Nutrition, 4.0L Water, Sleep Recovery, and Supplements.
public struct DailyHabitStatus: Codable, Equatable, Sendable, Identifiable {
    public var id: Date { date }
    public var date: Date
    public var isNutritionCompleted: Bool
    public var isHydrationCompleted: Bool    // >= 4000 ml
    public var isSleepCompleted: Bool        // >= 7.0 hours or recoveryScore >= 75
    public var isSupplementsCompleted: Bool

    public init(
        date: Date,
        isNutritionCompleted: Bool,
        isHydrationCompleted: Bool,
        isSleepCompleted: Bool,
        isSupplementsCompleted: Bool
    ) {
        self.date = date
        self.isNutritionCompleted = isNutritionCompleted
        self.isHydrationCompleted = isHydrationCompleted
        self.isSleepCompleted = isSleepCompleted
        self.isSupplementsCompleted = isSupplementsCompleted
    }

    /// Number of closed rings today (0 to 4).
    public var completedRingsCount: Int {
        var count = 0
        if isNutritionCompleted { count += 1 }
        if isHydrationCompleted { count += 1 }
        if isSleepCompleted { count += 1 }
        if isSupplementsCompleted { count += 1 }
        return count
    }

    /// Perfect athletic compliance day when all 4 rings are closed.
    public var isPerfectDay: Bool {
        completedRingsCount == 4
    }
}

public struct StreakSummary: Codable, Equatable, Sendable {
    public let currentStreakDays: Int
    public let longestStreakDays: Int
    public let totalPerfectDays: Int
    public let nutritionStreakDays: Int
    public let hydrationStreakDays: Int

    public init(
        currentStreakDays: Int,
        longestStreakDays: Int,
        totalPerfectDays: Int,
        nutritionStreakDays: Int,
        hydrationStreakDays: Int
    ) {
        self.currentStreakDays = currentStreakDays
        self.longestStreakDays = longestStreakDays
        self.totalPerfectDays = totalPerfectDays
        self.nutritionStreakDays = nutritionStreakDays
        self.hydrationStreakDays = hydrationStreakDays
    }
}

public enum HabitStreakEngine {
    /// Computes consecutive streaks and historical milestones from daily habit records.
    public static func computeStreaks(history: [DailyHabitStatus]) -> StreakSummary {
        guard !history.isEmpty else {
            return StreakSummary(
                currentStreakDays: 0,
                longestStreakDays: 0,
                totalPerfectDays: 0,
                nutritionStreakDays: 0,
                hydrationStreakDays: 0
            )
        }

        let sorted = history.sorted { $0.date > $1.date } // Most recent first
        let totalPerfect = history.filter { $0.isPerfectDay }.count

        // Current perfect streak
        var currentStreak = 0
        for item in sorted {
            if item.isPerfectDay {
                currentStreak += 1
            } else {
                break
            }
        }

        // Longest perfect streak
        let ascending = history.sorted { $0.date < $1.date }
        var longest = 0
        var running = 0
        for item in ascending {
            if item.isPerfectDay {
                running += 1
                if running > longest { longest = running }
            } else {
                running = 0
            }
        }

        // Nutrition streak
        var nutritionStreak = 0
        for item in sorted {
            if item.isNutritionCompleted {
                nutritionStreak += 1
            } else {
                break
            }
        }

        // Hydration streak (4.0L)
        var hydrationStreak = 0
        for item in sorted {
            if item.isHydrationCompleted {
                hydrationStreak += 1
            } else {
                break
            }
        }

        return StreakSummary(
            currentStreakDays: currentStreak,
            longestStreakDays: max(longest, currentStreak),
            totalPerfectDays: totalPerfect,
            nutritionStreakDays: nutritionStreak,
            hydrationStreakDays: hydrationStreak
        )
    }
}
