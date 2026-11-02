import Foundation

/// A deterministically calculated event for a specific day and time.
/// Generated on the fly by `ScheduleResolver`, never stored as the source of truth.
public struct ScheduledEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: String                       // e.g. "evt.breakfast.20261102"
    public var itemId: String                   // Matches PlanItem.id
    public var item: PlanItem                   // The item snapshot
    public var date: Date                       // Target day
    public var resolvedTime: Date               // Resolved fire/target timestamp
    public var hasConflict: Bool                // True if violates minMealGapMinutes, etc.
    public var conflictReason: String?          // Description of conflict if any
    public var attachedItems: [PlanItem]        // Supplements/items anchored via withItem
    public var attachedToItemId: String?        // Parent item id if attached via withItem

    public init(
        id: String,
        itemId: String,
        item: PlanItem,
        date: Date,
        resolvedTime: Date,
        hasConflict: Bool = false,
        conflictReason: String? = nil,
        attachedItems: [PlanItem] = [],
        attachedToItemId: String? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.item = item
        self.date = date
        self.resolvedTime = resolvedTime
        self.hasConflict = hasConflict
        self.conflictReason = conflictReason
        self.attachedItems = attachedItems
        self.attachedToItemId = attachedToItemId
    }
}
