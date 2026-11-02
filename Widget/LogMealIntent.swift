#if canImport(AppIntents)
import AppIntents
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(OrchardDomain)
import OrchardDomain
#endif
#if canImport(OrchardServices)
import OrchardServices
#endif

/// Interactive App Intent allowing one-tap meal logging directly from the Orchard widget.
@available(iOS 17.0, macOS 14.0, *)
public struct LogMealIntent: AppIntent {
    public static let title: LocalizedStringResource = "Έφαγα ✅"
    public static let description = IntentDescription("Επιβεβαίωση γεύματος από το Widget")

    @Parameter(title: "Meal ID")
    public var mealId: String

    public init() {
        self.mealId = ""
    }

    public init(mealId: String) {
        self.mealId = mealId
    }

    public func perform() async throws -> some IntentResult {
        let store = WidgetSnapshotStore()
        if var current = store.load() {
            current.progressFraction = min(1.0, current.progressFraction + 0.25)
            current.lastUpdated = Date()
            store.save(snapshot: current)
        }

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        return .result()
    }
}
#endif
