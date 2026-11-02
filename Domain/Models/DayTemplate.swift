import Foundation

/// A reusable template representing a specific kind of day (e.g. "training", "rest", "competition", "day_a").
public struct DayTemplate: Codable, Equatable, Sendable {
    public var trainingSessions: [TrainingSession]
    public var items: [PlanItem]
    public var rules: [Rule]

    public init(
        trainingSessions: [TrainingSession] = [],
        items: [PlanItem] = [],
        rules: [Rule] = []
    ) {
        self.trainingSessions = trainingSessions
        self.items = items
        self.rules = rules
    }

    private enum CodingKeys: String, CodingKey {
        case trainingSessions
        case items
        case rules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.trainingSessions = try container.decodeIfPresent([TrainingSession].self, forKey: .trainingSessions) ?? []
        self.items = try container.decodeIfPresent([PlanItem].self, forKey: .items) ?? []
        self.rules = try container.decodeIfPresent([Rule].self, forKey: .rules) ?? []
    }
}
