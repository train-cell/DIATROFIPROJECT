import Foundation

/// RP Diet Coach-style Peri-Workout Nutrient Timing & Anabolic Window Engine.
/// Dynamically calculates nutrient emphasis, gastric emptying parameters, and optimal
/// muscle protein synthesis (MPS) refueling countdowns around the athlete's workout.
public enum PeriWorkoutPhase: String, Codable, Sendable {
    case distant = "distant"                         // > 2h before or after training
    case preWorkoutFuel = "pre_workout"             // 60-90m prior: Carbs + Lean Protein
    case intraWorkoutHydration = "intra_workout"    // During session: Electrolytes + Water
    case postWorkoutAnabolic = "post_anabolic"       // 0-45m post: Whey + High GI Carbs
    case postWorkoutSolid = "post_solid"            // 45-120m post: Balanced meal

    public var titleGreek: String {
        switch self {
        case .distant: return "Βασική Περίοδος Ανάρρωσης"
        case .preWorkoutFuel: return "Προ-προπονητικό Γεύμα Ενέργειας"
        case .intraWorkoutHydration: return "Ενδο-προπονητική Ενυδάτωση & Ηλεκτρολύτες"
        case .postWorkoutAnabolic: return "Άμεσο Αναβολικό Παράθυρο (0-45′)"
        case .postWorkoutSolid: return "Μετα-προπονητικό Στερεό Γεύμα"
        }
    }

    public var nutrientFocusGreek: String {
        switch self {
        case .distant:
            return "Ισορροπημένα μακροθρεπτικά, φυτικές ίνες και καλά λιπαρά."
        case .preWorkoutFuel:
            return "Σύνθετοι υδατάνθρακες + άπαχη πρωτεΐνη. Χαμηλά λιπαρά & φυτικές ίνες για γρήγορη γαστρική κένωση."
        case .intraWorkoutHydration:
            return "500-1000ml νερό, νάτριο, κάλιο, μαγνήσιο + ηλεκτρολύτες Bolero ή EAAs."
        case .postWorkoutAnabolic:
            return "30-40g ταχείας απορρόφησης πρωτεΐνη ορού γάλακτος (Whey) + 40-60g υδατάνθρακας για αναπλήρωση γλυκογόνου."
        case .postWorkoutSolid:
            return "Πλήρες στερεό γεύμα (κοτόπουλο/μοσχάρι + ρύζι/πατάτα) για διαρκή πρωτεϊνοσύνθεση."
        }
    }
}

public struct PeriWorkoutStatus: Codable, Equatable, Sendable {
    public let phase: PeriWorkoutPhase
    public let minutesToNextPhase: Int
    public let workoutStartTime: Date
    public let workoutEndTime: Date
    public let isCurrentlyTraining: Bool
    public let isAnabolicWindowActive: Bool

    public init(
        phase: PeriWorkoutPhase,
        minutesToNextPhase: Int,
        workoutStartTime: Date,
        workoutEndTime: Date,
        isCurrentlyTraining: Bool,
        isAnabolicWindowActive: Bool
    ) {
        self.phase = phase
        self.minutesToNextPhase = minutesToNextPhase
        self.workoutStartTime = workoutStartTime
        self.workoutEndTime = workoutEndTime
        self.isCurrentlyTraining = isCurrentlyTraining
        self.isAnabolicWindowActive = isAnabolicWindowActive
    }
}

public enum PeriWorkoutEngine {
    /// Evaluates current peri-workout timing relative to workout start and end timestamps.
    public static func evaluatePhase(
        workoutStart: Date,
        workoutEnd: Date,
        currentTime: Date = Date()
    ) -> PeriWorkoutStatus {
        let secondsToStart = workoutStart.timeIntervalSince(currentTime)
        let secondsSinceEnd = currentTime.timeIntervalSince(workoutEnd)

        // 1. During Training
        if currentTime >= workoutStart && currentTime <= workoutEnd {
            let remainingTrainingMinutes = max(0, Int(workoutEnd.timeIntervalSince(currentTime) / 60.0))
            return PeriWorkoutStatus(
                phase: .intraWorkoutHydration,
                minutesToNextPhase: remainingTrainingMinutes,
                workoutStartTime: workoutStart,
                workoutEndTime: workoutEnd,
                isCurrentlyTraining: true,
                isAnabolicWindowActive: false
            )
        }

        // 2. Pre-Workout Window (60m to 90m before workout)
        if secondsToStart > 0 && secondsToStart <= (90 * 60) {
            let minutesToWorkout = Int(secondsToStart / 60.0)
            return PeriWorkoutStatus(
                phase: .preWorkoutFuel,
                minutesToNextPhase: minutesToWorkout,
                workoutStartTime: workoutStart,
                workoutEndTime: workoutEnd,
                isCurrentlyTraining: false,
                isAnabolicWindowActive: false
            )
        }

        // 3. Immediate Post-Workout Anabolic Window (0 to 45m post-workout)
        if secondsSinceEnd >= 0 && secondsSinceEnd <= (45 * 60) {
            let minutesLeftInWindow = max(0, 45 - Int(secondsSinceEnd / 60.0))
            return PeriWorkoutStatus(
                phase: .postWorkoutAnabolic,
                minutesToNextPhase: minutesLeftInWindow,
                workoutStartTime: workoutStart,
                workoutEndTime: workoutEnd,
                isCurrentlyTraining: false,
                isAnabolicWindowActive: true
            )
        }

        // 4. Post-Workout Solid Meal Window (45m to 120m post-workout)
        if secondsSinceEnd > (45 * 60) && secondsSinceEnd <= (120 * 60) {
            let minutesToBaseline = max(0, 120 - Int(secondsSinceEnd / 60.0))
            return PeriWorkoutStatus(
                phase: .postWorkoutSolid,
                minutesToNextPhase: minutesToBaseline,
                workoutStartTime: workoutStart,
                workoutEndTime: workoutEnd,
                isCurrentlyTraining: false,
                isAnabolicWindowActive: false
            )
        }

        // 5. Distant / Baseline
        let minutesToWait = secondsToStart > 0 ? Int(secondsToStart / 60.0) : 0
        return PeriWorkoutStatus(
            phase: .distant,
            minutesToNextPhase: minutesToWait,
            workoutStartTime: workoutStart,
            workoutEndTime: workoutEnd,
            isCurrentlyTraining: false,
            isAnabolicWindowActive: false
        )
    }
}
