import Foundation

/// Core settings for sleep times and meal intervals.
public struct PlanSettings: Codable, Equatable, Sendable {
    public var wake: String                 // "HH:mm", e.g. "07:30"
    public var bed: String                  // "HH:mm", e.g. "23:30"
    public var minMealGapMinutes: Int       // e.g. 90 minutes

    public init(wake: String, bed: String, minMealGapMinutes: Int = 90) {
        self.wake = wake
        self.bed = bed
        self.minMealGapMinutes = minMealGapMinutes
    }
}

/// Normalized weekday representation matching plan JSON keys ("mon"..."sun").
public enum Weekday: String, Codable, Sendable, CaseIterable {
    case mon, tue, wed, thu, fri, sat, sun

    public static func from(date: Date, calendar: Calendar = .current) -> Weekday {
        let weekdayInt = calendar.component(.weekday, from: date)
        // In Gregorian: 1 = Sun, 2 = Mon, 3 = Tue, 4 = Wed, 5 = Thu, 6 = Fri, 7 = Sat
        switch weekdayInt {
        case 1: return .sun
        case 2: return .mon
        case 3: return .tue
        case 4: return .wed
        case 5: return .thu
        case 6: return .fri
        case 7: return .sat
        default: return .mon
        }
    }
}

/// The complete nutrition and workout schedule plan.
public struct Plan: Codable, Equatable, Sendable {
    public var version: Int
    public var settings: PlanSettings
    public var weekly: [String: String]
    public var templates: [String: DayTemplate]
    public var overrides: [String: String]?

    public init(
        version: Int = 1,
        settings: PlanSettings,
        weekly: [String: String],
        templates: [String: DayTemplate],
        overrides: [String: String]? = nil
    ) {
        self.version = version
        self.settings = settings
        self.weekly = weekly
        self.templates = templates
        self.overrides = overrides
    }

    /// Resolves the template key for a given date.
    /// Priority order:
    /// 1. `selectedTemplateName` (user manual selection in the morning)
    /// 2. `overrides["yyyy-MM-dd"]`
    /// 3. `weekly["mon"..."sun"]`
    public func templateKey(
        for date: Date,
        selectedTemplateName: String? = nil,
        calendar: Calendar = .current
    ) -> String? {
        if let selected = selectedTemplateName, !selected.trimmingCharacters(in: .whitespaces).isEmpty {
            return selected
        }

        let dateString = formatDate(date: date, calendar: calendar)
        if let overrideKey = overrides?[dateString] {
            return overrideKey
        }

        let weekday = Weekday.from(date: date, calendar: calendar)
        return weekly[weekday.rawValue]
    }

    /// Resolves the DayTemplate for a given date.
    public func template(
        for date: Date,
        selectedTemplateName: String? = nil,
        calendar: Calendar = .current
    ) -> DayTemplate? {
        guard let key = templateKey(for: date, selectedTemplateName: selectedTemplateName, calendar: calendar) else {
            return nil
        }
        return templates[key]
    }

    private func formatDate(date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return ""
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
