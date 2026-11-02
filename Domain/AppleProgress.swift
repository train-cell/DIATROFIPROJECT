import Foundation

/// State of an individual meal slice within the daily apple.
public enum SliceState: String, Codable, Equatable, Sendable, CaseIterable {
    case pending
    case eaten
    case skipped
    case overdue
}

/// A slice of the Apple representing an individual meal's contribution to daily nutrition.
public struct AppleSlice: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var itemId: String
    public var title: String
    public var plannedKcal: Double
    public var actualKcal: Double?
    public var scheduledTime: Date
    public var state: SliceState
    public var orderIndex: Int
    public var proportion: Double            // 0.0 ... 1.0 of the whole apple
    public var startAngleFraction: Double     // 0.0 ... 1.0
    public var endAngleFraction: Double       // 0.0 ... 1.0

    public init(
        id: String,
        itemId: String,
        title: String,
        plannedKcal: Double,
        actualKcal: Double? = nil,
        scheduledTime: Date,
        state: SliceState,
        orderIndex: Int = 0,
        proportion: Double = 0.0,
        startAngleFraction: Double = 0.0,
        endAngleFraction: Double = 0.0
    ) {
        self.id = id
        self.itemId = itemId
        self.title = title
        self.plannedKcal = plannedKcal
        self.actualKcal = actualKcal
        self.scheduledTime = scheduledTime
        self.state = state
        self.orderIndex = orderIndex
        self.proportion = proportion
        self.startAngleFraction = startAngleFraction
        self.endAngleFraction = endAngleFraction
    }
}

/// Pure model calculating nutrition fraction by kcal eaten, slices per meal, and completion states.
public struct AppleProgress: Codable, Equatable, Sendable {
    public var slices: [AppleSlice]
    public var totalPlannedKcal: Double
    public var totalEatenKcal: Double
    public var progressFraction: Double       // 0.0 ... 1.0 (clamped)

    public var remainingKcal: Double {
        max(0.0, totalPlannedKcal - totalEatenKcal)
    }

    public var eatenCount: Int {
        slices.filter { $0.state == .eaten }.count
    }

    public var skippedCount: Int {
        slices.filter { $0.state == .skipped }.count
    }

    public var overdueCount: Int {
        slices.filter { $0.state == .overdue }.count
    }

    public var pendingCount: Int {
        slices.filter { $0.state == .pending }.count
    }

    public var totalCount: Int {
        slices.count
    }

    public var isComplete: Bool {
        if totalPlannedKcal > 0 {
            return totalEatenKcal >= totalPlannedKcal
        } else if totalCount > 0 {
            return eatenCount == totalCount
        } else {
            return false
        }
    }

    public init(
        slices: [AppleSlice] = [],
        totalPlannedKcal: Double? = nil,
        totalEatenKcal: Double? = nil
    ) {
        self.slices = slices
        let planned = totalPlannedKcal ?? slices.reduce(0.0) { $0 + max(0.0, $1.plannedKcal) }
        let eaten = totalEatenKcal ?? slices.filter { $0.state == .eaten }.reduce(0.0) {
            $0 + ($1.actualKcal ?? $1.plannedKcal)
        }

        self.totalPlannedKcal = planned
        self.totalEatenKcal = eaten

        if planned > 0 {
            self.progressFraction = min(1.0, max(0.0, eaten / planned))
        } else if !slices.isEmpty {
            let eatenNum = slices.filter { $0.state == .eaten }.count
            self.progressFraction = min(1.0, max(0.0, Double(eatenNum) / Double(slices.count)))
        } else {
            self.progressFraction = 0.0
        }
    }

    /// Pure deterministic calculation of AppleProgress given scheduled events and logged entries.
    ///
    /// - Parameters:
    ///   - events: Chronologically resolved scheduled events for the day.
    ///   - logEntries: Logged entries for the day.
    ///   - referenceDate: Current reference timestamp (defaults to Date()).
    ///   - overdueGraceMinutes: Grace window past scheduled time before marking overdue (defaults to 0).
    /// - Returns: Fully populated `AppleProgress`.
    public static func calculate(
        events: [ScheduledEvent],
        logEntries: [LogEntry],
        referenceDate: Date = Date(),
        overdueGraceMinutes: Int = 0
    ) -> AppleProgress {
        // Meals are the primary drivers of apple slices
        let mealEvents = events.filter { $0.item.type == .meal }

        guard !mealEvents.isEmpty else {
            return AppleProgress(slices: [], totalPlannedKcal: 0, totalEatenKcal: 0)
        }

        // Map log entries by itemId and eventKey for quick lookup
        let logsByItem = Dictionary(grouping: logEntries, by: { $0.itemId })
        let logsByEvent = Dictionary(grouping: logEntries, by: { $0.eventKey })

        var rawSlices: [(event: ScheduledEvent, state: SliceState, actualKcal: Double?)] = []

        for event in mealEvents {
            // Find most relevant log entry
            let matchingLog = logsByEvent[event.id]?.last ?? logsByItem[event.itemId]?.last

            let state: SliceState
            let actualKcal: Double?

            if let log = matchingLog {
                switch log.status {
                case .done, .swapped:
                    state = .eaten
                    actualKcal = log.kcal ?? event.item.kcal ?? 0.0
                case .skipped:
                    state = .skipped
                    actualKcal = 0.0
                case .partial(let fraction):
                    if fraction >= 1.0 {
                        state = .eaten
                        actualKcal = log.kcal ?? event.item.kcal ?? 0.0
                    } else if fraction > 0 {
                        state = .eaten
                        let baseKcal = log.kcal ?? event.item.kcal ?? 0.0
                        actualKcal = baseKcal * fraction
                    } else {
                        state = .pending
                        actualKcal = 0.0
                    }
                }
            } else {
                let cutoff = event.resolvedTime.addingTimeInterval(TimeInterval(overdueGraceMinutes * 60))
                if referenceDate > cutoff {
                    state = .overdue
                } else {
                    state = .pending
                }
                actualKcal = nil
            }

            rawSlices.append((event: event, state: state, actualKcal: actualKcal))
        }

        let totalPlanned = rawSlices.reduce(0.0) { $0 + max(0.0, $1.event.item.kcal ?? 0.0) }
        let totalWeight = totalPlanned > 0 ? totalPlanned : Double(rawSlices.count)

        var runningAngle = 0.0
        var computedSlices: [AppleSlice] = []

        for (index, item) in rawSlices.enumerated() {
            let plannedKcal = max(0.0, item.event.item.kcal ?? 0.0)
            let weight = totalPlanned > 0 ? plannedKcal : 1.0
            let proportion = totalWeight > 0 ? (weight / totalWeight) : (1.0 / Double(rawSlices.count))
            let start = runningAngle
            let end = min(1.0, start + proportion)
            runningAngle = end

            let slice = AppleSlice(
                id: item.event.id,
                itemId: item.event.itemId,
                title: item.event.item.title,
                plannedKcal: plannedKcal,
                actualKcal: item.actualKcal,
                scheduledTime: item.event.resolvedTime,
                state: item.state,
                orderIndex: index,
                proportion: proportion,
                startAngleFraction: start,
                endAngleFraction: end
            )
            computedSlices.append(slice)
        }

        return AppleProgress(
            slices: computedSlices,
            totalPlannedKcal: totalPlanned,
            totalEatenKcal: nil // will be computed from slices
        )
    }
}
