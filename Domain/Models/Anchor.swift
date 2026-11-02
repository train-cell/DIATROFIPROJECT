import Foundation

/// Defines how an item's time is scheduled relative to reference points.
public enum Anchor: Codable, Equatable, Sendable {
    case absolute(time: String)             // "HH:mm", e.g. "13:30"
    case afterWake(minutes: Int)            // Minutes after wake time
    case beforeSleep(minutes: Int)          // Minutes before bed time
    case beforeTraining(minutes: Int)       // Minutes before workout start
    case afterTraining(minutes: Int)        // Minutes after workout end
    case withItem(itemId: String)           // Attached to another item's resolved time

    public enum Kind: String, Codable, Sendable {
        case absolute
        case afterWake
        case beforeSleep
        case beforeTraining
        case afterTraining
        case withItem
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case minutes
        case time
        case itemId
    }

    public var kind: Kind {
        switch self {
        case .absolute: return .absolute
        case .afterWake: return .afterWake
        case .beforeSleep: return .beforeSleep
        case .beforeTraining: return .beforeTraining
        case .afterTraining: return .afterTraining
        case .withItem: return .withItem
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .absolute:
            let time = try container.decode(String.self, forKey: .time)
            self = .absolute(time: time)
        case .afterWake:
            let minutes = try container.decode(Int.self, forKey: .minutes)
            self = .afterWake(minutes: minutes)
        case .beforeSleep:
            let minutes = try container.decode(Int.self, forKey: .minutes)
            self = .beforeSleep(minutes: minutes)
        case .beforeTraining:
            let minutes = try container.decode(Int.self, forKey: .minutes)
            self = .beforeTraining(minutes: minutes)
        case .afterTraining:
            let minutes = try container.decode(Int.self, forKey: .minutes)
            self = .afterTraining(minutes: minutes)
        case .withItem:
            let itemId = try container.decode(String.self, forKey: .itemId)
            self = .withItem(itemId: itemId)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .absolute(let time):
            try container.encode(time, forKey: .time)
        case .afterWake(let minutes):
            try container.encode(minutes, forKey: .minutes)
        case .beforeSleep(let minutes):
            try container.encode(minutes, forKey: .minutes)
        case .beforeTraining(let minutes):
            try container.encode(minutes, forKey: .minutes)
        case .afterTraining(let minutes):
            try container.encode(minutes, forKey: .minutes)
        case .withItem(let itemId):
            try container.encode(itemId, forKey: .itemId)
        }
    }
}
