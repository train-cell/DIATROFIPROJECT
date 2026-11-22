import Foundation

/// A reusable template representing a specific kind of day (e.g. "training", "rest", "competition", "day_a").
public struct DayTemplate: Codable, Equatable, Sendable {
    public var title: String?
    public var subtitle: String?
    public var icon: String?
    public var targetWaterMl: Double?
    public var order: Int?
    public var trainingSessions: [TrainingSession]
    public var items: [PlanItem]
    public var rules: [Rule]

    public init(
        title: String? = nil,
        subtitle: String? = nil,
        icon: String? = nil,
        targetWaterMl: Double? = nil,
        order: Int? = nil,
        trainingSessions: [TrainingSession] = [],
        items: [PlanItem] = [],
        rules: [Rule] = []
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.targetWaterMl = targetWaterMl
        self.order = order
        self.trainingSessions = trainingSessions
        self.items = items
        self.rules = rules
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case icon
        case targetWaterMl
        case order
        case trainingSessions
        case items
        case rules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
        self.targetWaterMl = try container.decodeIfPresent(Double.self, forKey: .targetWaterMl)
        self.order = try container.decodeIfPresent(Int.self, forKey: .order)
        self.trainingSessions = try container.decodeIfPresent([TrainingSession].self, forKey: .trainingSessions) ?? []
        self.items = try container.decodeIfPresent([PlanItem].self, forKey: .items) ?? []
        self.rules = try container.decodeIfPresent([Rule].self, forKey: .rules) ?? []
    }
}
