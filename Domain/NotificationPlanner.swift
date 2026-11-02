import Foundation

/// Pure deterministic planner for generating local notification specifications.
public struct NotificationPlanner {

    /// System limit on iOS for pending local notifications.
    public static let maxPendingNotifications = 60

    /// Plans local notification specifications for a window of time.
    ///
    /// - Parameters:
    ///   - events: Resolved scheduled events.
    ///   - logs: Persisted log entries (to suppress already completed or skipped items).
    ///   - now: Reference current timestamp.
    ///   - windowDays: How many days forward to schedule (default 3).
    ///   - settings: User's PlanSettings for quiet hours and wake times.
    ///   - calendar: Calendar for date arithmetic.
    /// - Returns: An array of `NotificationSpec`s capped to $\le 60$.
    public static func plan(
        events: [ScheduledEvent],
        logs: [LogEntry] = [],
        now: Date,
        windowDays: Int = 3,
        settings: PlanSettings? = nil,
        calendar: Calendar = .current
    ) -> [NotificationSpec] {
        let windowEnd = calendar.date(byAdding: .day, value: windowDays, to: now) ?? now.addingTimeInterval(Double(windowDays) * 86400)

        // 1. Index completed/skipped logs to suppress notifications
        var completedKeys: Set<String> = []
        for log in logs {
            if log.status == .done || log.status == .skipped {
                completedKeys.insert(log.eventKey)
                completedKeys.insert(log.itemId)
            }
        }

        var specs: [NotificationSpec] = []

        // 2. Generate nudges for scheduled events
        for event in events {
            let maxOffset = (event.item.type == .meal ? 30 : 20) * 60
            let maxNudgeTime = event.resolvedTime.addingTimeInterval(TimeInterval(maxOffset))

            guard maxNudgeTime >= now && event.resolvedTime <= windowEnd else {
                continue
            }

            let dateString = formatEventDate(date: event.date, calendar: calendar)
            let eventKey = "\(event.itemId).\(dateString)"

            if completedKeys.contains(event.itemId) || completedKeys.contains(eventKey) || completedKeys.contains(event.id) {
                continue
            }

            let offsets: [Int]
            let category: String
            if event.item.type == .meal {
                offsets = [0, 15, 30]
                category = NotificationCategory.meal.rawValue
            } else {
                offsets = [0, 20]
                category = NotificationCategory.supplement.rawValue
            }

            for (index, offsetMinutes) in offsets.enumerated() {
                let fireDate = event.resolvedTime.addingTimeInterval(TimeInterval(offsetMinutes * 60))

                guard fireDate >= now else { continue }

                // Check quiet hours
                if let settings = settings, isQuietHours(date: fireDate, settings: settings, calendar: calendar) {
                    continue
                }

                let identifier = "evt.\(event.itemId).\(dateString).\(index)"
                let title = event.item.title
                let body: String
                switch index {
                case 0:
                    if let kcal = event.item.kcal {
                        body = "Time for \(event.item.title) (\(Int(kcal)) kcal)"
                    } else {
                        body = "Time for \(event.item.title)"
                    }
                case 1:
                    body = "Reminder: \(event.item.title)"
                default:
                    body = "Final reminder: \(event.item.title)"
                }

                let spec = NotificationSpec(
                    identifier: identifier,
                    fireDate: fireDate,
                    category: category,
                    title: title,
                    body: body,
                    isTimeSensitive: index == 0,
                    nudgeIndex: index,
                    itemId: event.itemId,
                    eventDate: event.date
                )
                specs.append(spec)
            }
        }

        // 3. Morning Sleep Rating Notifications
        if let settings = settings {
            let startOfToday = calendar.startOfDay(for: now)
            for dayOffset in 0..<windowDays {
                guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
                if let wakeDate = makeDate(dayDate: dayDate, timeString: settings.wake, calendar: calendar) {
                    if wakeDate >= now && wakeDate <= windowEnd {
                        let dateString = formatEventDate(date: dayDate, calendar: calendar)
                        let spec = NotificationSpec(
                            identifier: "evt.sleep_rating.\(dateString)",
                            fireDate: wakeDate,
                            category: NotificationCategory.sleepRating.rawValue,
                            title: "Good Morning! 😴",
                            body: "How did you sleep last night?",
                            isTimeSensitive: false,
                            nudgeIndex: 0,
                            itemId: "sleep_rating",
                            eventDate: dayDate
                        )
                        specs.append(spec)
                    }
                }
            }
        }

        // 4. Sort chronologically
        specs.sort { $0.fireDate < $1.fireDate }

        // 5. Smart pruning if exceeding max capacity (<= 60)
        return pruneToCapacity(specs: specs, maxLimit: maxPendingNotifications)
    }

    // MARK: - Smart Pruning

    private static func pruneToCapacity(specs: [NotificationSpec], maxLimit: Int) -> [NotificationSpec] {
        guard specs.count > maxLimit else { return specs }

        var result = specs

        // Step 1: Prune distant nudge 2 (final reminders) from latest to earliest
        if result.count > maxLimit {
            for i in stride(from: result.count - 1, through: 0, by: -1) {
                if result[i].nudgeIndex == 2 {
                    result.remove(at: i)
                    if result.count <= maxLimit { return result }
                }
            }
        }

        // Step 2: Prune distant nudge 1 (first reminders) from latest to earliest
        if result.count > maxLimit {
            for i in stride(from: result.count - 1, through: 0, by: -1) {
                if result[i].nudgeIndex == 1 {
                    result.remove(at: i)
                    if result.count <= maxLimit { return result }
                }
            }
        }

        // Step 3: Prune farthest notifications altogether from latest to earliest
        if result.count > maxLimit {
            result = Array(result.prefix(maxLimit))
        }

        return result
    }

    // MARK: - Helpers

    private static func isQuietHours(date: Date, settings: PlanSettings, calendar: Calendar) -> Bool {
        let wakeParts = parseTime(settings.wake)
        let bedParts = parseTime(settings.bed)

        let comps = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = comps.hour, let minute = comps.minute else { return false }
        let currentMinutes = hour * 60 + minute

        let wakeMinutes = wakeParts.hour * 60 + wakeParts.minute
        let bedMinutes = bedParts.hour * 60 + bedParts.minute

        if bedMinutes > wakeMinutes {
            // Normal sleep window (e.g. 23:00 to 07:30)
            return currentMinutes >= bedMinutes || currentMinutes < wakeMinutes
        } else {
            // Bedtime past midnight (e.g. 00:30 to 07:30)
            return currentMinutes >= bedMinutes && currentMinutes < wakeMinutes
        }
    }

    private static func parseTime(_ timeString: String) -> (hour: Int, minute: Int) {
        let parts = timeString.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return (0, 0) }
        return (parts[0], parts[1])
    }

    private static func makeDate(dayDate: Date, timeString: String, calendar: Calendar) -> Date? {
        let parts = parseTime(timeString)
        var comps = calendar.dateComponents([.year, .month, .day], from: dayDate)
        comps.hour = parts.hour
        comps.minute = parts.minute
        comps.second = 0
        return calendar.date(from: comps)
    }

    private static func formatEventDate(date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return ""
        }
        return String(format: "%04d%02d%02d", year, month, day)
    }
}
