import Foundation

/// Cronometer-style Micronutrient & Electrolyte tracking engine for serious athletes.
/// Tracks vital electrolytes (Sodium, Potassium, Magnesium, Calcium) and micronutrients
/// (Zinc, Iron, Vitamin D, Vitamin C, Dietary Fiber) against athletic Recommended Daily Allowances (RDA).
public struct MicronutrientTargets: Codable, Equatable, Sendable {
    public var sodiumMg: Double        // Target: 3500 mg for heavy training / sweating
    public var potassiumMg: Double     // Target: 3800 mg
    public var magnesiumMg: Double     // Target: 450 mg (recovery & muscle contractions)
    public var calciumMg: Double       // Target: 1200 mg
    public var zincMg: Double          // Target: 15 mg (testosterone / immunity)
    public var ironMg: Double          // Target: 18 mg
    public var vitaminDIU: Double      // Target: 3000 IU
    public var vitaminCMg: Double      // Target: 150 mg
    public var fiberGrams: Double      // Target: 38 g (gut microbiome & steady GI transit)

    public static let athleticDefault = MicronutrientTargets(
        sodiumMg: 3500.0,
        potassiumMg: 3800.0,
        magnesiumMg: 450.0,
        calciumMg: 1200.0,
        zincMg: 15.0,
        ironMg: 18.0,
        vitaminDIU: 3000.0,
        vitaminCMg: 150.0,
        fiberGrams: 38.0
    )
}

public struct MicronutrientIntake: Codable, Equatable, Sendable {
    public var sodiumMg: Double
    public var potassiumMg: Double
    public var magnesiumMg: Double
    public var calciumMg: Double
    public var zincMg: Double
    public var ironMg: Double
    public var vitaminDIU: Double
    public var vitaminCMg: Double
    public var fiberGrams: Double

    public init(
        sodiumMg: Double = 0.0,
        potassiumMg: Double = 0.0,
        magnesiumMg: Double = 0.0,
        calciumMg: Double = 0.0,
        zincMg: Double = 0.0,
        ironMg: Double = 0.0,
        vitaminDIU: Double = 0.0,
        vitaminCMg: Double = 0.0,
        fiberGrams: Double = 0.0
    ) {
        self.sodiumMg = sodiumMg
        self.potassiumMg = potassiumMg
        self.magnesiumMg = magnesiumMg
        self.calciumMg = calciumMg
        self.zincMg = zincMg
        self.ironMg = ironMg
        self.vitaminDIU = vitaminDIU
        self.vitaminCMg = vitaminCMg
        self.fiberGrams = fiberGrams
    }

    public mutating func add(_ other: MicronutrientIntake) {
        self.sodiumMg += other.sodiumMg
        self.potassiumMg += other.potassiumMg
        self.magnesiumMg += other.magnesiumMg
        self.calciumMg += other.calciumMg
        self.zincMg += other.zincMg
        self.ironMg += other.ironMg
        self.vitaminDIU += other.vitaminDIU
        self.vitaminCMg += other.vitaminCMg
        self.fiberGrams += other.fiberGrams
    }
}

public struct MicronutrientProgressItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let unit: String
    public let current: Double
    public let target: Double
    public let isElectrolyte: Bool

    public var fraction: Double {
        guard target > 0 else { return 0.0 }
        return min(current / target, 1.0)
    }

    public var percentage: Int {
        Int(round(fraction * 100.0))
    }

    public var isFulfilled: Bool {
        current >= target
    }
}

public enum MicronutrientEngine {
    /// Evaluates list of progress items for UI rendering with color-coded fulfillment.
    public static func evaluateProgress(
        intake: MicronutrientIntake,
        targets: MicronutrientTargets = .athleticDefault
    ) -> [MicronutrientProgressItem] {
        return [
            MicronutrientProgressItem(name: "Νάτριο (Sodium)", unit: "mg", current: intake.sodiumMg, target: targets.sodiumMg, isElectrolyte: true),
            MicronutrientProgressItem(name: "Κάλιο (Potassium)", unit: "mg", current: intake.potassiumMg, target: targets.potassiumMg, isElectrolyte: true),
            MicronutrientProgressItem(name: "Μαγνήσιο (Magnesium)", unit: "mg", current: intake.magnesiumMg, target: targets.magnesiumMg, isElectrolyte: true),
            MicronutrientProgressItem(name: "Ασβέστιο (Calcium)", unit: "mg", current: intake.calciumMg, target: targets.calciumMg, isElectrolyte: true),
            MicronutrientProgressItem(name: "Ψευδάργυρος (Zinc)", unit: "mg", current: intake.zincMg, target: targets.zincMg, isElectrolyte: false),
            MicronutrientProgressItem(name: "Σίδηρος (Iron)", unit: "mg", current: intake.ironMg, target: targets.ironMg, isElectrolyte: false),
            MicronutrientProgressItem(name: "Βιταμίνη D", unit: "IU", current: intake.vitaminDIU, target: targets.vitaminDIU, isElectrolyte: false),
            MicronutrientProgressItem(name: "Βιταμίνη C", unit: "mg", current: intake.vitaminCMg, target: targets.vitaminCMg, isElectrolyte: false),
            MicronutrientProgressItem(name: "Φυτικές Ίνες (Fiber)", unit: "g", current: intake.fiberGrams, target: targets.fiberGrams, isElectrolyte: false)
        ]
    }

    /// Overall electrolyte replenishment score (0 to 100).
    public static func electrolyteScore(intake: MicronutrientIntake, targets: MicronutrientTargets = .athleticDefault) -> Int {
        let na = min(intake.sodiumMg / targets.sodiumMg, 1.0)
        let k = min(intake.potassiumMg / targets.potassiumMg, 1.0)
        let mg = min(intake.magnesiumMg / targets.magnesiumMg, 1.0)
        let ca = min(intake.calciumMg / targets.calciumMg, 1.0)
        let avg = (na + k + mg + ca) / 4.0
        return Int(round(avg * 100.0))
    }
}
