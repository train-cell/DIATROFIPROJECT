import Foundation

/// Zero & YAZIO-style Intermittent Fasting & Circadian Eating Window Tracker.
/// Dynamically maps fasting stages, cellular autophagy, and glycogen depletion milestones
/// relative to the athlete's real meal timestamps.
public enum FastingProtocol: String, Codable, Sendable, CaseIterable {
    case circadian12 = "12_12"
    case classic16_8 = "16_8"
    case warrior18_6 = "18_6"
    case custom = "custom"

    public var fastingHours: Int {
        switch self {
        case .circadian12: return 12
        case .classic16_8: return 16
        case .warrior18_6: return 18
        case .custom: return 14
        }
    }

    public var eatingWindowHours: Int {
        return 24 - fastingHours
    }

    public var titleGreek: String {
        switch self {
        case .circadian12: return "Κιρκάδια Νηστεία 12:12"
        case .classic16_8: return "Κλασική Νηστεία 16:8 (Leangains)"
        case .warrior18_6: return "Warrior Protocol 18:6"
        case .custom: return "Προσαρμοσμένο Παράθυρο"
        }
    }
}

public enum FastingStage: String, Codable, Sendable {
    case digestion = "digestion"                 // 0-4h: Postprandial & Insulin active
    case fatBurning = "fat_burning"             // 4-12h: Insulin drops, beta-oxidation active
    case ketosisTransition = "ketosis"          // 12-16h: Liver glycogen depleted, mild ketones
    case autophagyStage = "autophagy"           // 16h+: AMPK & cellular cleanup activated

    public var titleGreek: String {
        switch self {
        case .digestion: return "Πέψη & Αποθήκευση Γλυκογόνου"
        case .fatBurning: return "Καύση Λίπους (Fat Oxidation)"
        case .ketosisTransition: return "Μεταβολική Κέτωση & AMPK"
        case .autophagyStage: return "Κυτταρική Αυτοφαγία (Autophagy)"
        }
    }

    public var subtitleGreek: String {
        switch self {
        case .digestion: return "0-4 ώρες: Τα επίπεδα ινσουλίνης παραμένουν υψηλά, τα θρεπτικά συστατικά απορροφώνται."
        case .fatBurning: return "4-12 ώρες: Η ινσουλίνη υποχωρεί και ο οργανισμός χρησιμοποιεί λιπαρά οξέα για ενέργεια."
        case .ketosisTransition: return "12-16 ώρες: Εξάντληση ηπατικού γλυκογόνου, έναρξη παραγωγής κετονών."
        case .autophagyStage: return "16+ ώρες: Ενεργοποίηση κυτταρικού καθαρισμού και επιδιόρθωσης μιτοχονδρίων."
        }
    }
}

public struct FastingStatus: Codable, Equatable, Sendable {
    public let isFasting: Bool
    public let startTime: Date
    public let targetEndTime: Date
    public let elapsedSeconds: TimeInterval
    public let targetDurationSeconds: TimeInterval
    public let progressFraction: Double          // 0.0 to 1.0
    public let stage: FastingStage
    public let protocolType: FastingProtocol

    public var hoursElapsed: Double {
        elapsedSeconds / 3600.0
    }

    public var remainingSeconds: TimeInterval {
        max(0.0, targetDurationSeconds - elapsedSeconds)
    }

    public var isGoalCompleted: Bool {
        elapsedSeconds >= targetDurationSeconds
    }
}

public enum FastingEngine {
    /// Evaluates current fasting status given the last finished meal and evaluation timestamp.
    public static func evaluateStatus(
        lastMealTime: Date,
        currentTime: Date = Date(),
        protocolType: FastingProtocol = .classic16_8
    ) -> FastingStatus {
        let elapsed = max(0.0, currentTime.timeIntervalSince(lastMealTime))
        let targetDuration = TimeInterval(protocolType.fastingHours * 3600)
        let fraction = min(1.0, max(0.0, elapsed / targetDuration))
        let isFasting = elapsed < targetDuration

        let hours = elapsed / 3600.0
        let stage: FastingStage
        if hours < 4.0 {
            stage = .digestion
        } else if hours < 12.0 {
            stage = .fatBurning
        } else if hours < 16.0 {
            stage = .ketosisTransition
        } else {
            stage = .autophagyStage
        }

        let targetEndTime = lastMealTime.addingTimeInterval(targetDuration)

        return FastingStatus(
            isFasting: isFasting,
            startTime: lastMealTime,
            targetEndTime: targetEndTime,
            elapsedSeconds: elapsed,
            targetDurationSeconds: targetDuration,
            progressFraction: fraction,
            stage: stage,
            protocolType: protocolType
        )
    }
}
