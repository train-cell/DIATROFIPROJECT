import Foundation

/// RP Diet Coach & MacroFactor-style Smart Algorithmic Weekly Coaching Check-In Engine.
/// Recommends disciplined adjustments while strictly guarding muscle mass (protein pinned at ~2.2g/kg).
public enum CoachingGoal: String, Codable, Sendable, CaseIterable {
    case fatLoss = "fat_loss"
    case maintenance = "maintenance"
    case muscleGain = "muscle_gain"

    public var titleGreek: String {
        switch self {
        case .fatLoss: return "Απώλεια Λίπους (Cut)"
        case .maintenance: return "Συντήρηση & Recomp"
        case .muscleGain: return "Μυϊκή Υπερτροφία (Lean Bulk)"
        }
    }

    public var targetWeeklyRateKg: ClosedRange<Double> {
        switch self {
        case .fatLoss: return -0.75 ... -0.30
        case .maintenance: return -0.15 ... 0.15
        case .muscleGain: return 0.15 ... 0.35
        }
    }
}

public struct CoachingCheckInReport: Codable, Equatable, Sendable {
    public let date: Date
    public let goal: CoachingGoal
    public let adherenceRate: Double           // 0.0 to 1.0 (meal compliance)
    public let weeklyWeightChangeKg: Double
    public let currentCalories: Double
    public let recommendedCalories: Double
    public let deltaCalories: Double
    public let deltaProteinGrams: Double
    public let deltaCarbsGrams: Double
    public let deltaFatsGrams: Double
    public let rationale: String
    public let requiresAction: Bool

    public init(
        date: Date = Date(),
        goal: CoachingGoal,
        adherenceRate: Double,
        weeklyWeightChangeKg: Double,
        currentCalories: Double,
        recommendedCalories: Double,
        deltaCalories: Double,
        deltaProteinGrams: Double,
        deltaCarbsGrams: Double,
        deltaFatsGrams: Double,
        rationale: String,
        requiresAction: Bool
    ) {
        self.date = date
        self.goal = goal
        self.adherenceRate = adherenceRate
        self.weeklyWeightChangeKg = weeklyWeightChangeKg
        self.currentCalories = currentCalories
        self.recommendedCalories = recommendedCalories
        self.deltaCalories = deltaCalories
        self.deltaProteinGrams = deltaProteinGrams
        self.deltaCarbsGrams = deltaCarbsGrams
        self.deltaFatsGrams = deltaFatsGrams
        self.rationale = rationale
        self.requiresAction = requiresAction
    }
}

public enum CoachingCheckInEngine {
    /// Analyzes the weekly check-in and generates deterministic recommendations.
    public static func evaluateCheckIn(
        goal: CoachingGoal,
        currentDailyKcal: Double,
        weeklyWeightChangeKg: Double,
        adherenceRate: Double,
        bodyweightKg: Double = 82.0
    ) -> CoachingCheckInReport {
        // Rule 1: High-Adherence requirement. If adherence is below 75%, do not touch macros.
        if adherenceRate < 0.75 {
            return CoachingCheckInReport(
                goal: goal,
                adherenceRate: adherenceRate,
                weeklyWeightChangeKg: weeklyWeightChangeKg,
                currentCalories: currentDailyKcal,
                recommendedCalories: currentDailyKcal,
                deltaCalories: 0.0,
                deltaProteinGrams: 0.0,
                deltaCarbsGrams: 0.0,
                deltaFatsGrams: 0.0,
                rationale: "Η συμμόρφωση στο πρόγραμμα ήταν \(Int(adherenceRate * 100))% (<75%). Διατηρούμε τις ίδιες θερμίδες και εστιάζουμε στη σταθερότητα των γευμάτων πριν αλλάξουμε τις θερμίδες.",
                requiresAction: false
            )
        }

        var deltaKcal: Double = 0.0
        var explanation = ""

        switch goal {
        case .fatLoss:
            if weeklyWeightChangeKg > -0.20 {
                // Rate of loss too slow -> Cut ~120-150 kcal
                deltaKcal = -140.0
                explanation = "Ο ρυθμός απώλειας (\(String(format: "%+.2f", weeklyWeightChangeKg)) kg/εβδομάδα) είναι πιο αργός από τον στόχο. Μικρή μείωση 140 kcal (κυρίως υδατάνθρακες/λιπαρά) για διατήρηση του ρυθμού."
            } else if weeklyWeightChangeKg < -1.0 {
                // Rate of loss too aggressive -> Increase by 100 kcal to protect muscle mass
                deltaKcal = +110.0
                explanation = "Η απώλεια είναι πολύ επιθετική (\(String(format: "%.2f", weeklyWeightChangeKg)) kg). Προσθήκη 110 kcal για προστασία της μυϊκής μάζας και αποφυγή καταβολισμού."
            } else {
                deltaKcal = 0.0
                explanation = "Ιδανικός ρυθμός απώλειας (\(String(format: "%.2f", weeklyWeightChangeKg)) kg). Συνεχίζουμε ακριβώς όπως είμαστε!"
            }

        case .muscleGain:
            if weeklyWeightChangeKg < 0.10 {
                deltaKcal = +130.0
                explanation = "Ο ρυθμός αύξησης (\(String(format: "%+.2f", weeklyWeightChangeKg)) kg) είναι χαμηλός. Αύξηση 130 kcal γύρω από την προπόνηση για ενίσχυση του μυϊκού πλεονάσματος."
            } else if weeklyWeightChangeKg > 0.45 {
                deltaKcal = -100.0
                explanation = "Απότομη αύξηση (\(String(format: "%.2f", weeklyWeightChangeKg)) kg). Μείωση 100 kcal για περιορισμό της συσσώρευσης σωματικού λίπους (lean bulk)."
            } else {
                deltaKcal = 0.0
                explanation = "Τέλειο lean bulk (\(String(format: "%+.2f", weeklyWeightChangeKg)) kg/εβδομάδα). Διατήρηση των τρεχόντων μακροσυστατικών."
            }

        case .maintenance:
            if abs(weeklyWeightChangeKg) > 0.35 {
                deltaKcal = weeklyWeightChangeKg > 0 ? -100.0 : +100.0
                explanation = "Το βάρος μετακινήθηκε εκτός του εύρους συντήρησης. Ήπια διόρθωση \(Int(deltaKcal)) kcal για επαναφορά σε ισοζύγιο."
            } else {
                deltaKcal = 0.0
                explanation = "Άριστη συντήρηση βάρους (\(String(format: "%+.2f", weeklyWeightChangeKg)) kg). Το μεταβολικό ισοζύγιο είναι σταθερό."
            }
        }

        // Protein remains pinned to high athletic standard (2.2g/kg), so deltas are allocated:
        // 70% from Carbohydrates (4 kcal/g) and 30% from Fats (9 kcal/g).
        let carbKcal = deltaKcal * 0.70
        let fatKcal = deltaKcal * 0.30
        let deltaCarbs = round((carbKcal / 4.0) * 10.0) / 10.0
        let deltaFats = round((fatKcal / 9.0) * 10.0) / 10.0

        let newKcal = max(1400.0, currentDailyKcal + deltaKcal)

        return CoachingCheckInReport(
            goal: goal,
            adherenceRate: adherenceRate,
            weeklyWeightChangeKg: weeklyWeightChangeKg,
            currentCalories: currentDailyKcal,
            recommendedCalories: newKcal,
            deltaCalories: deltaKcal,
            deltaProteinGrams: 0.0,
            deltaCarbsGrams: deltaCarbs,
            deltaFatsGrams: deltaFats,
            rationale: explanation,
            requiresAction: deltaKcal != 0.0
        )
    }
}
