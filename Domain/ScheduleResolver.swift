import Foundation

/// Pure deterministic resolver for translating a `Plan` and day reference into concrete `ScheduledEvent`s.
public struct ScheduleResolver {

    /// Resolves the daily schedule into a sorted list of `ScheduledEvent`s.
    ///
    /// - Parameters:
    ///   - date: The reference calendar date.
    ///   - plan: The user's complete `Plan`.
    ///   - selectedTemplateName: Optional template override chosen by the user in the morning.
    ///   - actualTrainings: Optional recorded/HealthKit training sessions for the day.
    ///   - calendar: Calendar to use for date arithmetic (defaults to `.current`).
    /// - Returns: Chronologically sorted array of `ScheduledEvent`s.
    public static func resolve(
        date: Date,
        plan: Plan,
        selectedTemplateName: String? = nil,
        actualTrainings: [TrainingSession]? = nil,
        calendar: Calendar = .current
    ) -> [ScheduledEvent] {
        guard let template = plan.template(for: date, selectedTemplateName: selectedTemplateName, calendar: calendar),
              !template.items.isEmpty else {
            return []
        }

        let startOfDay = calendar.startOfDay(for: date)
        let dateString = formatEventDate(date: date, calendar: calendar)

        func makeDate(timeString: String) -> Date? {
            let parts = timeString.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            var comps = calendar.dateComponents([.year, .month, .day], from: startOfDay)
            comps.hour = parts[0]
            comps.minute = parts[1]
            comps.second = 0
            return calendar.date(from: comps)
        }

        // 1. Reference: Wake & Bed times
        guard let wakeDate = makeDate(timeString: plan.settings.wake) else {
            return []
        }

        var bedDate = makeDate(timeString: plan.settings.bed) ?? wakeDate.addingTimeInterval(16 * 3600)
        if bedDate <= wakeDate {
            // Bedtime extends past midnight into the next day
            if let nextDayBed = calendar.date(byAdding: .day, value: 1, to: bedDate) {
                bedDate = nextDayBed
            }
        }

        // 2. Reference: Training session start & end
        var trainingStartTime: Date?
        var trainingEndTime: Date?

        if let actualSessions = actualTrainings, let actual = actualSessions.first {
            if let start = actual.startDate {
                trainingStartTime = start
                trainingEndTime = actual.endDate ?? start.addingTimeInterval(TimeInterval(actual.durationMinutes * 60))
            } else if let startStr = actual.start, let tStart = makeDate(timeString: startStr) {
                trainingStartTime = tStart
                trainingEndTime = tStart.addingTimeInterval(TimeInterval(actual.durationMinutes * 60))
            }
        } else if let templateSession = template.trainingSessions.first, let startStr = templateSession.start, let tStart = makeDate(timeString: startStr) {
            trainingStartTime = tStart
            trainingEndTime = tStart.addingTimeInterval(TimeInterval(templateSession.durationMinutes * 60))
        }

        // 3. Resolve items
        var resolvedTimes: [String: Date] = [:]
        var attachedToParent: [String: String] = [:] // childItemId -> parentItemId

        // Pass 1: Independent anchors
        for item in template.items {
            switch item.anchor {
            case .absolute(let time):
                if let date = makeDate(timeString: time) {
                    resolvedTimes[item.id] = date
                }
            case .afterWake(let minutes):
                resolvedTimes[item.id] = wakeDate.addingTimeInterval(TimeInterval(minutes * 60))
            case .beforeSleep(let minutes):
                resolvedTimes[item.id] = bedDate.addingTimeInterval(-TimeInterval(minutes * 60))
            case .beforeTraining(let minutes):
                if let tStart = trainingStartTime {
                    resolvedTimes[item.id] = tStart.addingTimeInterval(-TimeInterval(minutes * 60))
                } else if let fallback = item.fallbackTime, let fbDate = makeDate(timeString: fallback) {
                    resolvedTimes[item.id] = fbDate
                }
            case .afterTraining(let minutes):
                if let tEnd = trainingEndTime {
                    resolvedTimes[item.id] = tEnd.addingTimeInterval(TimeInterval(minutes * 60))
                } else if let fallback = item.fallbackTime, let fbDate = makeDate(timeString: fallback) {
                    resolvedTimes[item.id] = fbDate
                }
            case .withItem:
                break // Resolved in Pass 2
            }
        }

        // Pass 2: Dependent anchors (.withItem) - iterative resolution for potential chains
        var remainingItems = template.items.filter { $0.anchor.kind == .withItem }
        var iterations = 0
        let maxIterations = remainingItems.count + 1

        while !remainingItems.isEmpty && iterations < maxIterations {
            iterations += 1
            remainingItems.removeAll { item in
                guard case .withItem(let parentId) = item.anchor else { return true }
                if let parentTime = resolvedTimes[parentId] {
                    resolvedTimes[item.id] = parentTime
                    attachedToParent[item.id] = parentId
                    return true
                }
                return false
            }
        }

        // Fallback for any unresolvable items with fallbackTime
        for item in remainingItems {
            if let fallback = item.fallbackTime, let fbDate = makeDate(timeString: fallback) {
                resolvedTimes[item.id] = fbDate
            }
        }

        // 4. Map children into parent's attachedItems
        var parentToChildren: [String: [PlanItem]] = [:]
        for (childId, parentId) in attachedToParent {
            if let childItem = template.items.first(where: { $0.id == childId }) {
                parentToChildren[parentId, default: []].append(childItem)
            }
        }

        // 5. Construct ScheduledEvents
        var events: [ScheduledEvent] = []
        for item in template.items {
            guard let resolvedTime = resolvedTimes[item.id] else { continue }
            let event = ScheduledEvent(
                id: "evt.\(item.id).\(dateString)",
                itemId: item.id,
                item: item,
                date: startOfDay,
                resolvedTime: resolvedTime,
                hasConflict: false,
                conflictReason: nil,
                attachedItems: parentToChildren[item.id] ?? [],
                attachedToItemId: attachedToParent[item.id]
            )
            events.append(event)
        }

        // 6. Chronological sort
        events.sort { $0.resolvedTime < $1.resolvedTime }

        // 7. Check minimum meal gap conflicts
        let minMealGapMinutes = plan.settings.minMealGapMinutes
        var previousMealTime: Date? = nil

        for i in 0..<events.count {
            if events[i].item.type == .meal {
                if let prevTime = previousMealTime {
                    let gapMinutes = events[i].resolvedTime.timeIntervalSince(prevTime) / 60.0
                    if gapMinutes < Double(minMealGapMinutes) {
                        events[i].hasConflict = true
                        events[i].conflictReason = "Gap between meals (\(Int(gapMinutes)) min) is less than minimum (\(minMealGapMinutes) min)"
                    }
                }
                previousMealTime = events[i].resolvedTime
            }
        }

        return events
    }

    private static func formatEventDate(date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return ""
        }
        return String(format: "%04d%02d%02d", year, month, day)
    }
}
