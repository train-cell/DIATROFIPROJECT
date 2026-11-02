import Foundation
#if canImport(OrchardDomain)
import OrchardDomain
#endif

#if canImport(UserNotifications)
import UserNotifications
#endif

/// Protocol for scheduling and managing local notifications.
public protocol NotificationServiceProtocol: Sendable {
    func requestAuthorization() async throws -> Bool
    func registerCategories() async throws
    func schedule(specs: [NotificationSpec]) async throws
    func cancelPending(identifiers: [String]) async
    func cancelAll() async
    func getPendingNotificationIdentifiers() async -> [String]
}

#if canImport(UserNotifications)
/// Real implementation using iOS/macOS UNUserNotificationCenter.
public final class UserNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestAuthorization() async throws -> Bool {
        var options: UNAuthorizationOptions = [.alert, .sound, .badge]
        #if os(iOS)
        if #available(iOS 15.0, *) {
            options.insert(.timeSensitive)
        }
        #endif
        return try await center.requestAuthorization(options: options)
    }

    public func registerCategories() async throws {
        // 1. Meal Actions
        let mealDone = UNNotificationAction(
            identifier: NotificationAction.done.rawValue,
            title: "Έφαγα ✅",
            options: []
        )
        let mealSnooze = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: "Σε 30′",
            options: []
        )
        let mealSkip = UNNotificationAction(
            identifier: NotificationAction.skip.rawValue,
            title: "Παράλειψη",
            options: [.destructive]
        )
        let mealCategory = UNNotificationCategory(
            identifier: NotificationCategory.meal.rawValue,
            actions: [mealDone, mealSnooze, mealSkip],
            intentIdentifiers: [],
            options: []
        )

        // 2. Supplement Actions
        let suppDone = UNNotificationAction(
            identifier: NotificationAction.done.rawValue,
            title: "Πήρα ✅",
            options: []
        )
        let suppSnooze = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: "Σε 20′",
            options: []
        )
        let suppSkip = UNNotificationAction(
            identifier: NotificationAction.skip.rawValue,
            title: "Παράλειψη",
            options: [.destructive]
        )
        let suppCategory = UNNotificationCategory(
            identifier: NotificationCategory.supplement.rawValue,
            actions: [suppDone, suppSnooze, suppSkip],
            intentIdentifiers: [],
            options: []
        )

        // 3. Sleep Rating Actions
        let sleepBad = UNNotificationAction(
            identifier: NotificationAction.sleepBad.rawValue,
            title: "😴 Κακός",
            options: []
        )
        let sleepOk = UNNotificationAction(
            identifier: NotificationAction.sleepOk.rawValue,
            title: "😐 Οκ",
            options: []
        )
        let sleepGood = UNNotificationAction(
            identifier: NotificationAction.sleepGood.rawValue,
            title: "😊 Καλός",
            options: []
        )
        let sleepCategory = UNNotificationCategory(
            identifier: NotificationCategory.sleepRating.rawValue,
            actions: [sleepGood, sleepOk, sleepBad],
            intentIdentifiers: [],
            options: []
        )

        // 4. Signing Alert Category
        let signingCategory = UNNotificationCategory(
            identifier: NotificationCategory.signingAlert.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([mealCategory, suppCategory, sleepCategory, signingCategory])
    }

    public func schedule(specs: [NotificationSpec]) async throws {
        for spec in specs {
            let content = UNMutableNotificationContent()
            content.title = spec.title
            content.body = spec.body
            content.categoryIdentifier = spec.category
            content.sound = .default

            if #available(iOS 15.0, macOS 12.0, *), spec.isTimeSensitive {
                content.interruptionLevel = .timeSensitive
            }

            let timeInterval = max(1.0, spec.fireDate.timeIntervalSince(Date()))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            let request = UNNotificationRequest(identifier: spec.identifier, content: content, trigger: trigger)

            try await center.add(request)
        }
    }

    public func cancelPending(identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }

    public func getPendingNotificationIdentifiers() async -> [String] {
        let requests = await center.pendingNotificationRequests()
        return requests.map(\.identifier)
    }
}
#endif

/// In-memory test fake for testing notification orchestration without OS dependencies.
public actor FakeNotificationService: NotificationServiceProtocol {
    public private(set) var scheduledSpecs: [NotificationSpec] = []
    public private(set) var categoriesRegistered = false
    public var authorizationGranted = true

    public init() {}

    public func requestAuthorization() async throws -> Bool {
        return authorizationGranted
    }

    public func registerCategories() async throws {
        categoriesRegistered = true
    }

    public func schedule(specs: [NotificationSpec]) async throws {
        scheduledSpecs.append(contentsOf: specs)
    }

    public func cancelPending(identifiers: [String]) async {
        let idSet = Set(identifiers)
        scheduledSpecs.removeAll { idSet.contains($0.identifier) }
    }

    public func cancelAll() async {
        scheduledSpecs.removeAll()
    }

    public func getPendingNotificationIdentifiers() async -> [String] {
        return scheduledSpecs.map(\.identifier)
    }
}
