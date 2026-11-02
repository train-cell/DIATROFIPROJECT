import Foundation
#if canImport(OrchardDomain)
#if canImport(OrchardDomain)
import OrchardDomain
#endif
#endif

/// Manages persistence of WidgetTodaySnapshot inside the shared App Group container.
public struct WidgetSnapshotStore: @unchecked Sendable {
    public static let appGroupIdentifier = "group.com.skyd3n.orchard"
    public static let snapshotKey = "orchard.widget.today_snapshot"

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard) {
        self.userDefaults = userDefaults
    }

    /// Saves the current snapshot to the shared App Group UserDefaults.
    public func save(snapshot: WidgetTodaySnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: Self.snapshotKey)
        }
    }

    /// Loads the latest snapshot from the shared App Group UserDefaults.
    public func load() -> WidgetTodaySnapshot? {
        guard let data = userDefaults.data(forKey: Self.snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetTodaySnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }
}
