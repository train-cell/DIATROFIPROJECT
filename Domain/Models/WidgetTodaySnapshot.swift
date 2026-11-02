import Foundation

/// Snapshot of today's nutrition and apple progress shared across App Groups for WidgetKit.
public struct WidgetTodaySnapshot: Codable, Equatable, Sendable {
    public var progressFraction: Double         // 0.0 ... 1.0 (Apple bite completion)
    public var eatenKcal: Double                // Total calories eaten today
    public var plannedKcal: Double              // Total calories planned today
    public var nextMealId: String?              // ID of next scheduled meal
    public var nextMealTitle: String?           // Title of next meal (e.g. "Pre-workout")
    public var nextMealTime: Date?              // Scheduled timestamp for next meal
    public var balanceNow: Double?              // Real-time calorie balance (in minus out)
    public var lastUpdated: Date

    public init(
        progressFraction: Double,
        eatenKcal: Double,
        plannedKcal: Double,
        nextMealId: String? = nil,
        nextMealTitle: String? = nil,
        nextMealTime: Date? = nil,
        balanceNow: Double? = nil,
        lastUpdated: Date = Date()
    ) {
        self.progressFraction = progressFraction
        self.eatenKcal = eatenKcal
        self.plannedKcal = plannedKcal
        self.nextMealId = nextMealId
        self.nextMealTitle = nextMealTitle
        self.nextMealTime = nextMealTime
        self.balanceNow = balanceNow
        self.lastUpdated = lastUpdated
    }
}
