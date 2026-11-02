import Foundation

/// Bevel & Whoop-style Workout Strain vs Peri-Workout Carbohydrate Fueling Engine.
/// Computes glycogen demand from Apple Watch workout active energy burn and scores fueling adequacy (0-100%).
public enum FuelingStatus: String, Codable, Sendable {
    case underfueled = "underfueled"
    case optimal = "optimal"
    case supercharged = "supercharged"

    public var titleGreek: String {
        switch self {
        case .underfueled: return "Ελλιπής Υδατανθράκωση (Underfueled)"
        case .optimal: return "Ιδανικός Ανεφοδιασμός Γλυκογόνου (Optimal)"
        case .supercharged: return "Υψηλή Ενεργειακή Φόρτιση (Supercharged)"
        }
    }
}

public struct WorkoutFuelReport: Codable, Equatable, Sendable {
    public let workoutBurnKcal: Double
    public let estimatedGlycogenCarbsRequiredGrams: Double
    public let periWorkoutCarbsConsumedGrams: Double
    public let fuelingRatio: Double                  // Consumed / Required
    public let fuelingScore: Int                     // 0 to 100
    public let status: FuelingStatus
    public let adviceGreek: String

    public init(
        workoutBurnKcal: Double,
        estimatedGlycogenCarbsRequiredGrams: Double,
        periWorkoutCarbsConsumedGrams: Double,
        fuelingRatio: Double,
        fuelingScore: Int,
        status: FuelingStatus,
        adviceGreek: String
    ) {
        self.workoutBurnKcal = workoutBurnKcal
        self.estimatedGlycogenCarbsRequiredGrams = estimatedGlycogenCarbsRequiredGrams
        self.periWorkoutCarbsConsumedGrams = periWorkoutCarbsConsumedGrams
        self.fuelingRatio = fuelingRatio
        self.fuelingScore = fuelingScore
        self.status = status
        self.adviceGreek = adviceGreek
    }
}

public enum WorkoutFuelEngine {
    /// Evaluates fueling quality comparing workout active burn with peri-workout carbs consumed.
    public static func evaluateFueling(
        workoutBurnKcal: Double,
        periWorkoutCarbsConsumedGrams: Double
    ) -> WorkoutFuelReport {
        // In high-intensity strength & athletic training, ~65% of energy expenditure is derived from glycogen.
        let glycogenKcal = max(0.0, workoutBurnKcal * 0.65)
        let carbsRequired = max(20.0, round(glycogenKcal / 4.0))

        let ratio = carbsRequired > 0 ? (periWorkoutCarbsConsumedGrams / carbsRequired) : 1.0
        let score = Int(min(100.0, max(0.0, ratio * 100.0)))

        let status: FuelingStatus
        let advice: String

        if ratio < 0.60 {
            status = .underfueled
            advice = "Χαμηλή πρόσληψη υδατανθράκων (\(Int(periWorkoutCarbsConsumedGrams))g / στόχος \(Int(carbsRequired))g). Αυξήστε τους υδατάνθρακες στο προ- και μετα-προπονητικό γεύμα για προστασία του μυϊκού ιστού."
        } else if ratio <= 1.25 {
            status = .optimal
            advice = "Άριστος ενεργειακός ανεφοδιασμός (\(Int(periWorkoutCarbsConsumedGrams))g / \(Int(carbsRequired))g). Τα αποθέματα γλυκογόνου αναπληρώθηκαν χωρίς υπερβολικό πλεόνασμα."
        } else {
            status = .supercharged
            advice = "Πλούσια ενεργειακή φόρτιση (\(Int(periWorkoutCarbsConsumedGrams))g). Ιδανικό για ημέρες διπλών προπονήσεων ή έντονης υπερτροφίας."
        }

        return WorkoutFuelReport(
            workoutBurnKcal: workoutBurnKcal,
            estimatedGlycogenCarbsRequiredGrams: carbsRequired,
            periWorkoutCarbsConsumedGrams: periWorkoutCarbsConsumedGrams,
            fuelingRatio: round(ratio * 100.0) / 100.0,
            fuelingScore: score,
            status: status,
            adviceGreek: advice
        )
    }
}
