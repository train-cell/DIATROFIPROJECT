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
    public var hrvMs: Double?                   // Heart Rate Variability (SDNN in milliseconds)
    public var restingHeartRateBpm: Double?     // Resting Heart Rate (beats per minute)

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
        inBedMinutes: Int? = nil,
        hrvMs: Double? = nil,
        restingHeartRateBpm: Double? = nil
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
        self.hrvMs = hrvMs
        self.restingHeartRateBpm = restingHeartRateBpm
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
    /// Combines subjective rating, sleep efficiency, restorative sleep proportion (Deep + REM),
    /// and Apple Watch HRV (Heart Rate Variability SDNN).
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
        // Athletic HRV Modulation:
        // Baseline healthy HRV: 50-70 ms.
        // Above 65 ms indicates parasympathetic dominance (high CNS readiness).
        // Below 35 ms indicates sympathetic strain or residual fatigue.
        if let hrv = hrvMs {
            if hrv >= 65.0 {
                score += 5.0
            } else if hrv < 35.0 {
                score -= 5.0
            }
        }
        return min(100, max(0, Int(score)))
    }

    /// Qualitative HRV readiness classification.
    public var hrvStatusDescription: String {
        guard let hrv = hrvMs else { return "Μη διαθέσιμη μέτρηση HRV" }
        if hrv >= 65.0 {
            return "Υψηλή Ετοιμότητα CNS (Παρασυμπαθητική Κυριαρχία)"
        } else if hrv >= 45.0 {
            return "Βέλτιστη Βασική Ετοιμότητα (Ισορροπημένο Νευρικό Σύστημα)"
        } else if hrv >= 30.0 {
            return "Μέτρια Ετοιμότητα (Ήπια Κόπωση)"
        } else {
            return "Αυξημένο Στρες / Κόπωση (Συμπαθητική Υπερφόρτωση)"
        }
    }

    /// Qualitative Resting Heart Rate classification.
    public var restingHeartRateStatusDescription: String {
        guard let rhr = restingHeartRateBpm else { return "Μη διαθέσιμη μέτρηση RHR" }
        if rhr <= 54.0 {
            return "Εξαιρετική Αθλητική Ανάκαμψη"
        } else if rhr <= 65.0 {
            return "Φυσιολογικός Καρδιακός Ρυθμός Ηρεμίας"
        } else {
            return "Ελαφρώς Αυξημένος Ρυθμός (Πιθανή Ελλιπής Ανάρρωση)"
        }
    }

    /// Sleep debt relative to an 8-hour target (in minutes, + = surplus, - = deficit).
    public var sleepDebtMinutes: Int? {
        guard let asleep = asleepMinutes else { return nil }
        return asleep - 480
    }
}
