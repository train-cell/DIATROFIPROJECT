import Foundation

/// Type of item in a daily plan (meal or supplement).
public enum PlanItemType: String, Codable, Sendable {
    case meal
    case supplement
}

/// An individual scheduled item within a DayTemplate.
public struct PlanItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var type: PlanItemType
    public var title: String
    public var anchor: Anchor
    public var kcal: Double?
    public var protein: Double?
    public var carbs: Double?
    public var fat: Double?
    public var fallbackTime: String?
    public var notes: String?

    public init(
        id: String,
        type: PlanItemType,
        title: String,
        anchor: Anchor,
        kcal: Double? = nil,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        fallbackTime: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.anchor = anchor
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fallbackTime = fallbackTime
        self.notes = notes
    }
}
