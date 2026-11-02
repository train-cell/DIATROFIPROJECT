import Foundation

/// Daily water hydration tracking model configured for the high-adherence 4.0 Liters/day (4000 ml) target.
public struct HydrationDay: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var targetMl: Double
    public var consumedMl: Double

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        targetMl: Double = 4000.0,
        consumedMl: Double = 0.0
    ) {
        self.id = id
        self.date = date
        self.targetMl = targetMl
        self.consumedMl = max(0.0, consumedMl)
    }

    /// Progress fraction clamped to [0.0, 1.0] for gauges and progress bars.
    public var progressFraction: Double {
        guard targetMl > 0 else { return 0.0 }
        return min(max(consumedMl / targetMl, 0.0), 1.0)
    }

    /// Progress percentage rounded to nearest integer (e.g. 75%).
    public var percentage: Int {
        Int(round(progressFraction * 100.0))
    }

    /// Remaining milliliters required to reach the 4.0L target.
    public var remainingMl: Double {
        max(0.0, targetMl - consumedMl)
    }

    /// Whether the user has achieved the daily 4.0 Liters goal.
    public var isGoalReached: Bool {
        consumedMl >= targetMl
    }

    /// Consumed volume in Liters.
    public var litersConsumed: Double {
        consumedMl / 1000.0
    }

    /// Target volume in Liters.
    public var litersTarget: Double {
        targetMl / 1000.0
    }

    /// Adds water intake in milliliters (e.g., 250, 500, 1000 ml).
    public mutating func add(ml: Double) {
        consumedMl = max(0.0, consumedMl + ml)
    }

    /// Resets consumed water back to zero.
    public mutating func reset() {
        consumedMl = 0.0
    }
}
