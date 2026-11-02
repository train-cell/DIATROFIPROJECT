import Foundation

/// Pure description of a planned notification before submission to UNUserNotificationCenter.
public struct NotificationSpec: Codable, Equatable, Sendable, Identifiable {
    public var id: String { identifier }
    public var identifier: String               // e.g. "evt.breakfast.20261102.0"
    public var fireDate: Date                   // Exactly when the notification should fire
    public var category: String                 // Category identifier (e.g. "ORCHARD_MEAL")
    public var title: String                    // Notification title
    public var body: String                     // Notification body text
    public var isTimeSensitive: Bool            // Time-Sensitive interruption level
    public var nudgeIndex: Int                  // 0 (initial), 1 (+15m/20m), 2 (+30m)
    public var itemId: String                   // Associated PlanItem.id
    public var eventDate: Date                  // The day date for reference

    public init(
        identifier: String,
        fireDate: Date,
        category: String,
        title: String,
        body: String,
        isTimeSensitive: Bool = true,
        nudgeIndex: Int = 0,
        itemId: String = "",
        eventDate: Date = Date()
    ) {
        self.identifier = identifier
        self.fireDate = fireDate
        self.category = category
        self.title = title
        self.body = body
        self.isTimeSensitive = isTimeSensitive
        self.nudgeIndex = nudgeIndex
        self.itemId = itemId
        self.eventDate = eventDate
    }
}
