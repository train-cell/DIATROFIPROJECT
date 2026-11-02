#if canImport(WidgetKit) && canImport(SwiftUI)
import WidgetKit
import SwiftUI
#if canImport(OrchardDomain)
import OrchardDomain
#endif
#if canImport(OrchardServices)
import OrchardServices
#endif

public struct OrchardWidgetEntry: TimelineEntry {
    public let date: Date
    public let snapshot: WidgetTodaySnapshot

    public init(date: Date, snapshot: WidgetTodaySnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct OrchardWidgetProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> OrchardWidgetEntry {
        OrchardWidgetEntry(
            date: Date(),
            snapshot: WidgetTodaySnapshot(
                progressFraction: 0.75,
                eatenKcal: 1500,
                plannedKcal: 2000,
                nextMealId: "pre",
                nextMealTitle: "Pre-workout",
                nextMealTime: Date().addingTimeInterval(3600),
                balanceNow: -100
            )
        )
    }

    public func getSnapshot(in context: Context, completion: @escaping (OrchardWidgetEntry) -> Void) {
        let store = WidgetSnapshotStore()
        let snapshot = store.load() ?? placeholder(in: context).snapshot
        completion(OrchardWidgetEntry(date: Date(), snapshot: snapshot))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<OrchardWidgetEntry>) -> Void) {
        let store = WidgetSnapshotStore()
        let snapshot = store.load() ?? placeholder(in: context).snapshot
        let entry = OrchardWidgetEntry(date: Date(), snapshot: snapshot)

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

public struct OrchardWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: OrchardWidgetProvider.Entry

    public init(entry: OrchardWidgetProvider.Entry) {
        self.entry = entry
    }

    public var body: some View {
        switch family {
        case .accessoryCircular:
            LockScreenCircularView(snapshot: entry.snapshot)
        case .accessoryRectangular:
            LockScreenRectangularView(snapshot: entry.snapshot)
        default:
            SmallHomeWidgetView(snapshot: entry.snapshot)
        }
    }
}

struct SmallHomeWidgetView: View {
    let snapshot: WidgetTodaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("🍏 The DIAτροφή Project")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
                Spacer()
                Text("\(Int(snapshot.progressFraction * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("\(Int(snapshot.eatenKcal)) / \(Int(snapshot.plannedKcal)) kcal")
                .font(.headline)

            if let title = snapshot.nextMealTitle, let id = snapshot.nextMealId {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                #if canImport(AppIntents)
                if #available(iOS 17.0, macOS 14.0, *) {
                    Button(intent: LogMealIntent(mealId: id)) {
                        Text("Έφαγα ✅")
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                #endif
            } else {
                Text("Όλα τα γεύματα ολοκληρώθηκαν!")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

struct LockScreenCircularView: View {
    let snapshot: WidgetTodaySnapshot

    var body: some View {
        Gauge(value: snapshot.progressFraction) {
            Text("🍏")
        } currentValueLabel: {
            Text("\(Int(snapshot.progressFraction * 100))%")
                .font(.caption2)
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(.background, for: .widget)
    }
}

struct LockScreenRectangularView: View {
    let snapshot: WidgetTodaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("🍏 The DIAτροφή Project: \(Int(snapshot.progressFraction * 100))%")
                .font(.headline)
            if let title = snapshot.nextMealTitle {
                Text("Επόμενο: \(title)")
                    .font(.caption)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

public struct OrchardWidget: Widget {
    public let kind: String = "OrchardWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OrchardWidgetProvider()) { entry in
            OrchardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("The DIAτροφή Project")
        .description("Παρακολούθησε την πρόοδο της ημέρας και κατάγραψε γεύματα με 1 tap.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}
#endif
