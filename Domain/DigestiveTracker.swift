import Foundation

/// Lifesum & MacroFactor-style Postprandial Satiety, Energy & GI Digestion Journal.
/// Allows athletes to monitor gut comfort, food comas, and gastric motility to identify optimal performance foods.
public enum SatietyScore: Int, Codable, Sendable {
    case starving = 1
    case hungry = 2
    case pleasantlySatisfied = 3
    case full = 4
    case stuffed = 5

    public var titleGreek: String {
        switch self {
        case .starving: return "Έντονη Πείνα (1/5)"
        case .hungry: return "Ελαφριά Πείνα (2/5)"
        case .pleasantlySatisfied: return "Ιδανικός Κορεσμός (3/5)"
        case .full: return "Πλήρης (4/5)"
        case .stuffed: return "Υπερπλήρωση / Βαρυστομαχιά (5/5)"
        }
    }
}

public enum EnergyLevel: Int, Codable, Sendable {
    case foodComa = 1
    case lowEnergy = 2
    case steady = 3
    case highVitality = 4
    case peakAthletic = 5

    public var titleGreek: String {
        switch self {
        case .foodComa: return "Λήθαργος / Food Coma (1/5)"
        case .lowEnergy: return "Υπνηλία (2/5)"
        case .steady: return "Σταθερή Ενέργεια (3/5)"
        case .highVitality: return "Υψηλή Ζωτικότητα (4/5)"
        case .peakAthletic: return "Κορυφαία Ετοιμότητα (5/5)"
        }
    }
}

public enum DigestSymptom: String, Codable, Sendable, CaseIterable {
    case optimal = "optimal"
    case lightBloat = "light_bloat"
    case heavyStomach = "heavy_stomach"
    case acidReflux = "acid_reflux"
    case rapidEmptying = "rapid_emptying"

    public var titleGreek: String {
        switch self {
        case .optimal: return "Ομαλή Πέψη ✅"
        case .lightBloat: return "Ήπιο Φούσκωμα"
        case .heavyStomach: return "Βαρύ Στομάχι"
        case .acidReflux: return "Παλινδρόμηση / Καούρα"
        case .rapidEmptying: return "Ταχεία Κένωση"
        }
    }
}

public struct DigestiveLog: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var mealEventId: String
    public var timestamp: Date
    public var satiety: SatietyScore
    public var energy: EnergyLevel
    public var symptoms: [DigestSymptom]
    public var notes: String?

    public init(
        id: UUID = UUID(),
        mealEventId: String,
        timestamp: Date = Date(),
        satiety: SatietyScore,
        energy: EnergyLevel,
        symptoms: [DigestSymptom] = [.optimal],
        notes: String? = nil
    ) {
        self.id = id
        self.mealEventId = mealEventId
        self.timestamp = timestamp
        self.satiety = satiety
        self.energy = energy
        self.symptoms = symptoms
        self.notes = notes
    }

    /// Overall digestive wellness score (0 to 100).
    public var wellnessScore: Int {
        var score = 100
        if symptoms.contains(.heavyStomach) { score -= 25 }
        if symptoms.contains(.lightBloat) { score -= 15 }
        if symptoms.contains(.acidReflux) { score -= 30 }
        if energy == .foodComa { score -= 20 }
        if satiety == .stuffed { score -= 15 }
        return max(10, min(100, score))
    }
}
