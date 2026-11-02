import Foundation

/// Status of a logged meal or item.
public enum LogStatus: Codable, Equatable, Sendable {
    case done
    case partial(fraction: Double)
    case skipped
    case swapped

    private enum CodingKeys: String, CodingKey {
        case type
        case fraction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "done":
            self = .done
        case "partial":
            let fraction = try container.decode(Double.self, forKey: .fraction)
            self = .partial(fraction: fraction)
        case "skipped":
            self = .skipped
        case "swapped":
            self = .swapped
        default:
            self = .done
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .done:
            try container.encode("done", forKey: .type)
        case .partial(let fraction):
            try container.encode("partial", forKey: .type)
            try container.encode(fraction, forKey: .fraction)
        case .skipped:
            try container.encode("skipped", forKey: .type)
        case .swapped:
            try container.encode("swapped", forKey: .type)
        }
    }
}

/// Source that produced the log entry.
public enum LogSource: Codable, Equatable, Sendable {
    case plan
    case manual
    case ai(provider: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case provider
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "plan":
            self = .plan
        case "manual":
            self = .manual
        case "ai":
            let provider = try container.decode(String.self, forKey: .provider)
            self = .ai(provider: provider)
        default:
            self = .manual
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .plan:
            try container.encode("plan", forKey: .type)
        case .manual:
            try container.encode("manual", forKey: .type)
        case .ai(let provider):
            try container.encode("ai", forKey: .type)
            try container.encode(provider, forKey: .provider)
        }
    }
}

/// A persisted log entry confirming or adjusting a scheduled item.
public struct LogEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var eventKey: String                 // e.g. "breakfast.20261102"
    public var itemId: String
    public var status: LogStatus
    public var timestamp: Date
    public var kcal: Double?
    public var protein: Double?
    public var carbs: Double?
    public var fat: Double?
    public var source: LogSource
    public var healthSyncId: String?            // "orchard.<uuid>"
    public var note: String?

    public init(
        id: UUID = UUID(),
        eventKey: String,
        itemId: String,
        status: LogStatus,
        timestamp: Date = Date(),
        kcal: Double? = nil,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        source: LogSource = .plan,
        healthSyncId: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.eventKey = eventKey
        self.itemId = itemId
        self.status = status
        self.timestamp = timestamp
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.source = source
        self.healthSyncId = healthSyncId
        self.note = note
    }
}
