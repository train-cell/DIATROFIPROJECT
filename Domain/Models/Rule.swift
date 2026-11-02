import Foundation

/// Type of rule (guidance constraint).
public enum RuleType: String, Codable, Sendable {
    case avoid
    case prefer
}

/// A nutritional or timing rule associated with a DayTemplate.
public struct Rule: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var type: RuleType
    public var text: String

    public init(id: String = UUID().uuidString, type: RuleType, text: String) {
        self.id = id
        self.type = type
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case text
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.type = try container.decode(RuleType.self, forKey: .type)
        self.text = try container.decode(String.self, forKey: .text)
    }
}
