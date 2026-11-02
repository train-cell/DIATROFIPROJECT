import Foundation

/// Sleep record captured in the morning, combining user rating and HealthKit sleep architecture (Apple Watch Ultra / Bevel style).
public struct SleepEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date                       // Morning wake-up date
    public var rating: Int                      // 1...5 subjective rating
    public var tags: [String]
    public var note: String?
    public var asleepMinutes: Int?              // Total asleep duration
    public var deepSleepMinutes: Int?           // Deep / restorative sleep
    public var remSleepMinutes: Int?            // REM / cognitive restoration
    public var coreSleepMinutes: Int?           // Core / light sleep
    public var awakeMinutes: Int?               // Awake time during night
    public var inBedMinutes: Int?               // Total time in bed

    public init(
        id: UUID = UUID(),
        date: Date,
        rating: Int,
        tags: [String] = [],
        note: String? = nil,
        asleepMinutes: Int? = nil,
        deepSleepMinutes: Int? = nil,
        remSleepMinutes: Int? = nil,
        coreSleepMinutes: Int? = nil,
        awakeMinutes: Int? = nil,
        inBedMinutes: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.rating = rating
        self.tags = tags
        self.note = note
        self.asleepMinutes = asleepMinutes
        self.deepSleepMinutes = deepSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.coreSleepMinutes = coreSleepMinutes
        self.awakeMinutes = awakeMinutes
        self.inBedMinutes = inBedMinutes
    }

    /// Sleep efficiency percentage (asleep time vs total in bed).
    public var efficiencyPercentage: Double? {
        guard let asleep = asleepMinutes, let inBed = inBedMinutes, inBed > 0 else { return nil }
        return min(100.0, (Double(asleep) / Double(inBed)) * 100.0)
    }

    /// Restorative sleep percentage: (Deep + REM) / Total Asleep. Target: 35-45%.
    public var restorativePercentage: Double? {
        guard let asleep = asleepMinutes, asleep > 0 else { return nil }
        let deep = deepSleepMinutes ?? 0
        let rem = remSleepMinutes ?? 0
        return min(100.0, (Double(deep + rem) / Double(asleep)) * 100.0)
    }

    /// Bevel / Whoop style Recovery Readiness Score (0...100).
    public var recoveryScore: Int {
        var score: Double = Double(rating) * 12.0 // 12-60 base from subjective rating
        if let eff = efficiencyPercentage {
            score += (eff * 0.25) // up to 25 pts
        } else {
            score += 20.0
        }
        if let rest = restorativePercentage {
            score += min(20.0, rest * 0.5) // up to 20 pts
        } else {
            score += 15.0
        }
        return min(100, max(0, Int(score)))
    }

    /// Sleep debt relative to an 8-hour target (in minutes, + = surplus, - = deficit).
    public var sleepDebtMinutes: Int? {
        guard let asleep = asleepMinutes else { return nil }
        return asleep - 480
    }
}
