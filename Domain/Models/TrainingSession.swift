import Foundation

/// Represents a workout/training session, either planned in a template or recorded as actual.
public struct TrainingSession: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var start: String?               // "HH:mm", e.g. "18:00" for planned session
    public var startDate: Date?             // Exact timestamp for actual session
    public var endDate: Date?               // Exact timestamp for actual session
    public var durationMinutes: Int
    public var estKcal: Double?
    public var actualKcal: Double?
    public var isActual: Bool
    public var title: String?

    public init(
        id: String = UUID().uuidString,
        start: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        durationMinutes: Int = 60,
        estKcal: Double? = nil,
        actualKcal: Double? = nil,
        isActual: Bool = false,
        title: String? = nil
    ) {
        self.id = id
        self.start = start
        self.startDate = startDate
        self.endDate = endDate
        self.durationMinutes = durationMinutes
        self.estKcal = estKcal
        self.actualKcal = actualKcal
        self.isActual = isActual
        self.title = title
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case start
        case startDate
        case endDate
        case durationMinutes
        case estKcal
        case actualKcal
        case isActual
        case title
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.start = try container.decodeIfPresent(String.self, forKey: .start)
        self.startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        self.endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        self.durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 60
        self.estKcal = try container.decodeIfPresent(Double.self, forKey: .estKcal)
        self.actualKcal = try container.decodeIfPresent(Double.self, forKey: .actualKcal)
        self.isActual = try container.decodeIfPresent(Bool.self, forKey: .isActual) ?? false
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
    }
}
