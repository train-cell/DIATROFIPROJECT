import Foundation

/// Notification category identifiers matching iOS interactive notification categories.
public enum NotificationCategory: String, Sendable, CaseIterable {
    case meal = "ORCHARD_MEAL"
    case supplement = "ORCHARD_SUPPLEMENT"
    case sleepRating = "ORCHARD_SLEEP_RATING"
    case signingAlert = "ORCHARD_SIGNING_ALERT"
}

/// Action identifiers for lock-screen notification buttons.
public enum NotificationAction: String, Sendable, CaseIterable {
    // Shared / Meal / Supplement
    case done = "ACTION_DONE"
    case snooze = "ACTION_SNOOZE"
    case skip = "ACTION_SKIP"

    // Sleep rating actions
    case sleepBad = "ACTION_SLEEP_BAD"       // Rating: 2
    case sleepOk = "ACTION_SLEEP_OK"         // Rating: 3
    case sleepGood = "ACTION_SLEEP_GOOD"     // Rating: 5
}
