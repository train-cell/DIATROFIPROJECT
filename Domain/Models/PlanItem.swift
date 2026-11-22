import Foundation

/// Type of item in a daily plan (meal or supplement).
public enum PlanItemType: String, Codable, Sendable {
    case meal
    case supplement
}

/// An interchangeable food or supplement choice within a modular PlanItem.
public struct PlanOption: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var category: String?
    public var details: String?
    public var kcal: Double?
    public var protein: Double?
    public var carbs: Double?
    public var fat: Double?
    public var isEstimatedMacros: Bool

    public init(
        id: String,
        title: String,
        category: String? = nil,
        details: String? = nil,
        kcal: Double? = nil,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        isEstimatedMacros: Bool = true
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.details = details
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.isEstimatedMacros = isEstimatedMacros
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, category, details, kcal, protein, carbs, fat, isEstimatedMacros
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.category = try container.decodeIfPresent(String.self, forKey: .category)
        self.details = try container.decodeIfPresent(String.self, forKey: .details)
        self.kcal = try container.decodeIfPresent(Double.self, forKey: .kcal)
        self.protein = try container.decodeIfPresent(Double.self, forKey: .protein)
        self.carbs = try container.decodeIfPresent(Double.self, forKey: .carbs)
        self.fat = try container.decodeIfPresent(Double.self, forKey: .fat)
        self.isEstimatedMacros = try container.decodeIfPresent(Bool.self, forKey: .isEstimatedMacros) ?? true
    }
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
    public var options: [PlanOption]?
    public var activeWeekdays: [Weekday]?
    public var sessionIndex: Int?
    public var waterMl: Double?
    public var isOptional: Bool?

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
        notes: String? = nil,
        options: [PlanOption]? = nil,
        activeWeekdays: [Weekday]? = nil,
        sessionIndex: Int? = nil,
        waterMl: Double? = nil,
        isOptional: Bool? = nil
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
        self.options = options
        self.activeWeekdays = activeWeekdays
        self.sessionIndex = sessionIndex
        self.waterMl = waterMl
        self.isOptional = isOptional
    }

    /// Finds option by matching its ID.
    public func option(for id: String?) -> PlanOption? {
        guard let id = id else { return nil }
        return options?.first(where: { $0.id == id })
    }

    /// Resolves effective macronutrients for the selected option, or falls back to item base macros.
    public func effectiveMacros(selectedOptionId: String?) -> MacroTotals {
        if let opt = option(for: selectedOptionId) {
            return MacroTotals(
                kcal: opt.kcal ?? self.kcal ?? 0.0,
                protein: opt.protein ?? self.protein ?? 0.0,
                carbs: opt.carbs ?? self.carbs ?? 0.0,
                fat: opt.fat ?? self.fat ?? 0.0
            )
        }
        return MacroTotals(
            kcal: self.kcal ?? 0.0,
            protein: self.protein ?? 0.0,
            carbs: self.carbs ?? 0.0,
            fat: self.fat ?? 0.0
        )
    }
}
