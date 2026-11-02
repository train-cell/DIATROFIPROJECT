import Foundation

/// Macronutrient totals.
public struct MacroTotals: Codable, Equatable, Sendable {
    public var kcal: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double

    public init(kcal: Double = 0.0, protein: Double = 0.0, carbs: Double = 0.0, fat: Double = 0.0) {
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

/// Energy burned values read from HealthKit or estimated by fallback heuristics.
public struct EnergyBurned: Codable, Equatable, Sendable {
    public var basalKcal: Double
    public var activeKcal: Double
    public var totalKcal: Double { basalKcal + activeKcal }

    public init(basalKcal: Double = 0.0, activeKcal: Double = 0.0) {
        self.basalKcal = basalKcal
        self.activeKcal = activeKcal
    }
}

/// Snapshot summary of daily calorie and energy balance arithmetic.
public struct EnergyBalanceSummary: Codable, Equatable, Sendable {
    /// Calories consumed so far from confirmed/partial meal logs.
    public let consumedKcal: Double
    /// Total calories planned for the entire day.
    public let plannedDayKcal: Double
    /// Total calories scheduled to have been consumed up to `now`.
    public let plannedToNowKcal: Double
    /// Calories burned so far today (basal + active).
    public let outSoFar: Double
    /// Projected total burn for the full day (outSoFar + prorated remaining basal + remaining planned training).
    public let projectedOut: Double
    /// Current balance: consumedKcal - outSoFar (+ = surplus, - = deficit).
    public let balanceNow: Double
    /// Projected end-of-day balance: plannedDayKcal - projectedOut (+ = surplus, - = deficit).
    public let projectedBalance: Double
    /// True when Apple Health was unavailable/unauthorized and fallback heuristics were used.
    public let isFallback: Bool

    public init(
        consumedKcal: Double,
        plannedDayKcal: Double,
        plannedToNowKcal: Double,
        outSoFar: Double,
        projectedOut: Double,
        balanceNow: Double,
        projectedBalance: Double,
        isFallback: Bool
    ) {
        self.consumedKcal = consumedKcal
        self.plannedDayKcal = plannedDayKcal
        self.plannedToNowKcal = plannedToNowKcal
        self.outSoFar = outSoFar
        self.projectedOut = projectedOut
        self.balanceNow = balanceNow
        self.projectedBalance = projectedBalance
        self.isFallback = isFallback
    }
}

/// Pure deterministic domain engine for calorie and energy balance arithmetic.
/// Operates without UI, HealthKit, or network dependencies.
public struct CalorieEngine: Sendable {

    // MARK: - 1. Consumed Calories & Macros

    /// Pure calculation of calories consumed for a single `LogEntry`.
    /// - `.done`: 100% of planned or logged calories
    /// - `.partial(fraction)`: fraction * calories
    /// - `.skipped`: 0 kcal
    /// - `.swapped`: actual logged calories
    public static func consumedKcal(for entry: LogEntry, baseKcal: Double? = nil) -> Double {
        switch entry.status {
        case .skipped:
            return 0.0
        case .done:
            return max(0.0, entry.kcal ?? baseKcal ?? 0.0)
        case .partial(let fraction):
            let base = entry.kcal ?? baseKcal ?? 0.0
            return max(0.0, base * max(0.0, fraction))
        case .swapped:
            return max(0.0, entry.kcal ?? baseKcal ?? 0.0)
        }
    }

    /// Calculates macronutrient breakdown for an individual LogEntry.
    public static func consumedMacros(for entry: LogEntry, baseItem: PlanItem? = nil) -> MacroTotals {
        switch entry.status {
        case .skipped:
            return MacroTotals(kcal: 0, protein: 0, carbs: 0, fat: 0)
        case .done, .swapped:
            let kcal = max(0.0, entry.kcal ?? baseItem?.kcal ?? 0.0)
            let protein = max(0.0, entry.protein ?? baseItem?.protein ?? 0.0)
            let carbs = max(0.0, entry.carbs ?? baseItem?.carbs ?? 0.0)
            let fat = max(0.0, entry.fat ?? baseItem?.fat ?? 0.0)
            return MacroTotals(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
        case .partial(let fraction):
            let factor = max(0.0, fraction)
            let kcal = max(0.0, (entry.kcal ?? baseItem?.kcal ?? 0.0) * factor)
            let protein = max(0.0, (entry.protein ?? baseItem?.protein ?? 0.0) * factor)
            let carbs = max(0.0, (entry.carbs ?? baseItem?.carbs ?? 0.0) * factor)
            let fat = max(0.0, (entry.fat ?? baseItem?.fat ?? 0.0) * factor)
            return MacroTotals(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
        }
    }

    /// Sums consumed calories across all logged entries.
    public static func consumedKcal(
        entries: [LogEntry],
        items: [String: PlanItem] = [:]
    ) -> Double {
        entries.reduce(0.0) { sum, entry in
            sum + consumedKcal(for: entry, baseKcal: items[entry.itemId]?.kcal)
        }
    }

    /// Sums consumed calories for a given DayTemplate.
    public static func consumedKcal(
        entries: [LogEntry],
        template: DayTemplate
    ) -> Double {
        let itemMap = Dictionary(uniqueKeysWithValues: template.items.map { ($0.id, $0) })
        return consumedKcal(entries: entries, items: itemMap)
    }

    /// Sums macronutrients across all logged entries.
    public static func consumedMacros(
        entries: [LogEntry],
        items: [String: PlanItem] = [:]
    ) -> MacroTotals {
        var totals = MacroTotals()
        for entry in entries {
            let m = consumedMacros(for: entry, baseItem: items[entry.itemId])
            totals.kcal += m.kcal
            totals.protein += m.protein
            totals.carbs += m.carbs
            totals.fat += m.fat
        }
        return totals
    }

    // MARK: - 2. Planned Calories

    /// Sum of all planned items in a list.
    public static func plannedDayKcal(items: [PlanItem]) -> Double {
        items.reduce(0.0) { $0 + ($1.kcal ?? 0.0) }
    }

    /// Sum of all planned items in a DayTemplate.
    public static func plannedDayKcal(template: DayTemplate) -> Double {
        plannedDayKcal(items: template.items)
    }

    /// Sum of all scheduled events for the day.
    public static func plannedDayKcal(events: [ScheduledEvent]) -> Double {
        events.reduce(0.0) { $0 + ($1.item.kcal ?? 0.0) }
    }

    /// Sum of planned items scheduled to be consumed at or before `now`.
    public static func plannedToNowKcal(events: [ScheduledEvent], now: Date) -> Double {
        events
            .filter { $0.resolvedTime <= now }
            .reduce(0.0) { $0 + ($1.item.kcal ?? 0.0) }
    }

    // MARK: - 3. Energy Out So Far

    /// Calculates total burned energy so far today: basal + active.
    public static func outSoFar(basalBurned: Double, activeBurned: Double) -> Double {
        max(0.0, basalBurned) + max(0.0, activeBurned)
    }

    /// Calculates total burned energy so far from an `EnergyBurned` struct.
    public static func outSoFar(energyBurned: EnergyBurned) -> Double {
        outSoFar(basalBurned: energyBurned.basalKcal, activeBurned: energyBurned.activeKcal)
    }

    /// Fallback for `outSoFar` when HealthKit permissions are unavailable.
    /// Prefers manual burn if provided, otherwise prorates historical 7-day average daily burn.
    public static func outSoFarFallback(
        manualBurn: Double?,
        historicalAverageDailyBurn: Double?,
        now: Date,
        calendar: Calendar = .current
    ) -> Double {
        if let manual = manualBurn {
            return max(0.0, manual)
        }
        if let historical = historicalAverageDailyBurn {
            let fractions = dayFractions(at: now, calendar: calendar)
            return max(0.0, historical * fractions.elapsed)
        }
        return 0.0
    }

    // MARK: - 4. Day Fraction & Prorated Basal

    /// Computes the elapsed and remaining fractions (0.0 ... 1.0) of the calendar day for `date`.
    public static func dayFractions(
        at date: Date,
        calendar: Calendar = .current
    ) -> (elapsed: Double, remaining: Double) {
        let startOfDay = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return (1.0, 0.0)
        }
        let totalSeconds = nextDay.timeIntervalSince(startOfDay)
        guard totalSeconds > 0 else {
            return (1.0, 0.0)
        }
        let elapsedSeconds = date.timeIntervalSince(startOfDay)
        let elapsed = min(1.0, max(0.0, elapsedSeconds / totalSeconds))
        let remaining = max(0.0, 1.0 - elapsed)
        return (elapsed, remaining)
    }

    /// Calculates prorated remaining basal burn for the rest of today.
    /// - If `dailyBasal` (e.g. 7-day average or user profile) is provided, uses `dailyBasal * remainingFraction`.
    /// - Else if `basalSoFar > 0` and `elapsedFraction > 0.01`, extrapolates full-day basal burn.
    /// - Otherwise safely returns 0.0 (e.g. missing basal, zero burn, or right at midnight).
    public static func proratedRemainingBasal(
        now: Date,
        dailyBasal: Double? = nil,
        basalSoFar: Double = 0.0,
        calendar: Calendar = .current
    ) -> Double {
        let fractions = dayFractions(at: now, calendar: calendar)
        if let daily = dailyBasal, daily > 0 {
            return max(0.0, daily * fractions.remaining)
        }
        if basalSoFar > 0 && fractions.elapsed > 0.01 {
            let extrapolatedDaily = basalSoFar / fractions.elapsed
            return max(0.0, extrapolatedDaily * fractions.remaining)
        }
        return 0.0
    }

    // MARK: - 5. Projected Out

    /// Pure calculation of projectedOut:
    /// projectedOut = outSoFar + prorated basal + planned training estKcal.
    public static func calculateProjectedOut(
        outSoFar: Double,
        remainingBasal: Double,
        plannedTrainingEstKcal: Double
    ) -> Double {
        max(0.0, outSoFar) + max(0.0, remainingBasal) + max(0.0, plannedTrainingEstKcal)
    }

    /// Sums estimated calories of planned training sessions that have not yet occurred or been recorded.
    public static func remainingPlannedTrainingKcal(
        sessions: [TrainingSession],
        completedSessionIds: Set<String> = []
    ) -> Double {
        sessions
            .filter { !completedSessionIds.contains($0.id) && !$0.isActual }
            .reduce(0.0) { $0 + ($1.estKcal ?? 0.0) }
    }

    // MARK: - 6. Balance Arithmetic (+ = Surplus, - = Deficit)

    /// Current balance: consumed - outSoFar.
    /// Sign convention:
    /// - Positive (+) indicates a Calorie Surplus.
    /// - Negative (-) indicates a Calorie Deficit.
    public static func balanceNow(consumed: Double, outSoFar: Double) -> Double {
        consumed - outSoFar
    }

    /// Projected end-of-day balance: plannedDay - projectedOut.
    /// Sign convention:
    /// - Positive (+) indicates a projected Calorie Surplus.
    /// - Negative (-) indicates a projected Calorie Deficit.
    public static func projectedBalance(plannedDay: Double, projectedOut: Double) -> Double {
        plannedDay - projectedOut
    }

    // MARK: - 7. Comprehensive Balance Calculation

    /// Resolves full energy balance summary with HealthKit or fallback heuristics.
    public static func calculateBalance(
        now: Date,
        entries: [LogEntry],
        items: [String: PlanItem] = [:],
        events: [ScheduledEvent] = [],
        healthEnergy: EnergyBurned? = nil,
        dailyBasalEstimate: Double? = nil,
        fallbackHistoricalBurn: Double? = nil,
        manualBurnKcal: Double? = nil,
        remainingPlannedTrainingKcal: Double = 0.0,
        calendar: Calendar = .current
    ) -> EnergyBalanceSummary {
        let consumed = consumedKcal(entries: entries, items: items)
        let plannedDay = events.isEmpty
            ? items.values.reduce(0.0) { $0 + ($1.kcal ?? 0.0) }
            : plannedDayKcal(events: events)
        let plannedToNow = plannedToNowKcal(events: events, now: now)

        let isFallback = (healthEnergy == nil)
        let outToday: Double
        let projectedBurn: Double

        if let health = healthEnergy {
            outToday = outSoFar(energyBurned: health)
            let remainingBasal = proratedRemainingBasal(
                now: now,
                dailyBasal: dailyBasalEstimate,
                basalSoFar: health.basalKcal,
                calendar: calendar
            )
            projectedBurn = calculateProjectedOut(
                outSoFar: outToday,
                remainingBasal: remainingBasal,
                plannedTrainingEstKcal: remainingPlannedTrainingKcal
            )
        } else {
            outToday = outSoFarFallback(
                manualBurn: manualBurnKcal,
                historicalAverageDailyBurn: fallbackHistoricalBurn,
                now: now,
                calendar: calendar
            )
            let remainingBasal: Double
            if let fallbackDaily = fallbackHistoricalBurn {
                let fractions = dayFractions(at: now, calendar: calendar)
                remainingBasal = fallbackDaily * fractions.remaining
            } else {
                remainingBasal = 0.0
            }
            projectedBurn = calculateProjectedOut(
                outSoFar: outToday,
                remainingBasal: remainingBasal,
                plannedTrainingEstKcal: remainingPlannedTrainingKcal
            )
        }

        let currentBalance = balanceNow(consumed: consumed, outSoFar: outToday)
        let projBalance = projectedBalance(plannedDay: plannedDay, projectedOut: projectedBurn)

        return EnergyBalanceSummary(
            consumedKcal: consumed,
            plannedDayKcal: plannedDay,
            plannedToNowKcal: plannedToNow,
            outSoFar: outToday,
            projectedOut: projectedBurn,
            balanceNow: currentBalance,
            projectedBalance: projBalance,
            isFallback: isFallback
        )
    }
}
