import Foundation
import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif
#if canImport(OrchardServices)
import OrchardServices
#endif
#if canImport(HealthKit)
import HealthKit
#endif

/// Main application state and dependency container for Orchard.
@MainActor
public final class AppContainer: ObservableObject {
    public static let shared = AppContainer()

    // MARK: - Services
    public let healthStore: any HealthStoreProtocol

    // MARK: - Published State
    @Published public var plan: Plan
    @Published public var selectedTemplateKey: String
    @Published public var selectedDate: Date = Date()
    @Published public var selectedTemplatesByDate: [String: String] = [:]
    @Published public var logEntries: [LogEntry] = []
    @Published public var biteCount: Int = 0

    @Published public var resolvedEvents: [ScheduledEvent] = []
    @Published public var appleProgress: AppleProgress = AppleProgress()
    @Published public var energyBalance: EnergyBalanceSummary?
    @Published public var sleepEntries: [SleepEntry] = []
    @Published public var weeklyStats: WeeklyStats?

    public init(healthStore: (any HealthStoreProtocol)? = nil) {
        #if canImport(HealthKit)
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = healthStore ?? HealthKitStore()
        } else {
            self.healthStore = healthStore ?? FakeHealthStore()
        }
        #else
        self.healthStore = healthStore ?? FakeHealthStore()
        #endif

        // 1. Load Plan from bundle or embedded fallback
        let loadedPlan = Self.loadDefaultPlan()
        self.plan = loadedPlan

        // 2. Initial template key from weekday or today's saved selection
        let savedMap = UserDefaults.standard.dictionary(forKey: "orchard.selectedTemplatesByDate") as? [String: String] ?? [:]
        self.selectedTemplatesByDate = savedMap
        let todayFormatter = DateFormatter()
        todayFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = todayFormatter.string(from: Date())
        let savedToday = savedMap[todayKey]
        let initialKey = savedToday ?? (loadedPlan.templateKey(for: Date()) ?? "day_1")
        self.selectedTemplateKey = initialKey

        // 3. Resolve initial schedule & progress
        self.refreshSchedule()

        // 4. Background sync with HealthKit sleep
        Task { [weak self] in
            await self?.syncHealthKitSleep()
        }
    }

    public func syncHealthKitSleep() async {
        do {
            if let entry = try await healthStore.readSleepAnalysis(for: selectedDate) {
                if let idx = sleepEntries.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }) {
                    sleepEntries[idx] = entry
                } else {
                    sleepEntries.append(entry)
                }
                refreshSchedule()
            }
        } catch {
            // Non-fatal, continue with local entries
        }
    }

    // MARK: - Template Selection
    public func selectTemplate(key: String) {
        selectedTemplateKey = key
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: selectedDate)
        selectedTemplatesByDate[dateKey] = key
        UserDefaults.standard.set(selectedTemplatesByDate, forKey: "orchard.selectedTemplatesByDate")
        refreshSchedule()
    }

    /// Calculates how many times a given day template was selected in the rolling 14-day window.
    /// User rule: Each of the 7 days can be selected up to 2 times every 2 weeks (14 days).
    public func usageCountInLast14Days(templateKey: String, referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        guard let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: today) else { return 0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var count = 0
        for (dateStr, key) in selectedTemplatesByDate {
            guard key == templateKey else { continue }
            if let date = formatter.date(from: dateStr), date >= fourteenDaysAgo && date <= today {
                count += 1
            }
        }

        let todayStr = formatter.string(from: today)
        if selectedTemplateKey == templateKey && selectedTemplatesByDate[todayStr] == nil {
            count += 1
        }

        return count
    }

    // MARK: - Logging Operations
    public func logMeal(
        event: ScheduledEvent,
        status: LogStatus = .done,
        kcal: Double? = nil
    ) {
        // Remove existing log for this event/item if present
        logEntries.removeAll { $0.itemId == event.itemId || $0.eventKey == event.id }

        let entry = LogEntry(
            eventKey: event.id,
            itemId: event.itemId,
            status: status,
            timestamp: Date(),
            kcal: kcal ?? event.item.kcal,
            protein: event.item.protein,
            carbs: event.item.carbs,
            fat: event.item.fat,
            source: .plan,
            note: event.item.title
        )
        logEntries.append(entry)

        if status == .done {
            biteCount += 1
        }

        refreshSchedule()

        let store = self.healthStore
        let item = event.item
        Task {
            try? await store.writeDietaryLog(entry, item: item)
        }
    }

    public func undoLog(itemId: String) {
        if let idx = logEntries.firstIndex(where: { $0.itemId == itemId }) {
            let removedEntry = logEntries[idx]
            if removedEntry.status == .done {
                biteCount = max(0, biteCount - 1)
            }
            logEntries.remove(at: idx)
            refreshSchedule()

            let store = self.healthStore
            Task {
                try? await store.deleteDietaryLog(for: removedEntry.id)
            }
        }
    }

    public func addManualLog(
        title: String,
        type: PlanItemType,
        kcal: Double?,
        protein: Double?,
        carbs: Double?,
        fat: Double?,
        notes: String? = nil,
        timestamp: Date = Date()
    ) {
        let uniqueId = "manual_\(UUID().uuidString.prefix(8))"
        let entry = LogEntry(
            eventKey: uniqueId,
            itemId: uniqueId,
            status: .done,
            timestamp: timestamp,
            kcal: kcal,
            protein: protein,
            carbs: carbs,
            fat: fat,
            source: .manual,
            note: "\(title)\(notes.map { " - \($0)" } ?? "")"
        )
        logEntries.append(entry)
        biteCount += 1
        refreshSchedule()

        let store = self.healthStore
        Task {
            try? await store.writeDietaryLog(entry, item: nil)
        }
    }

    public func deleteLogEntry(id: UUID) {
        if let idx = logEntries.firstIndex(where: { $0.id == id }) {
            let removedEntry = logEntries[idx]
            if removedEntry.status == .done {
                biteCount = max(0, biteCount - 1)
            }
            logEntries.remove(at: idx)
            refreshSchedule()

            let store = self.healthStore
            Task {
                try? await store.deleteDietaryLog(for: removedEntry.id)
            }
        }
    }

    // MARK: - Schedule & Progress Refresh
    public func refreshSchedule() {
        resolvedEvents = ScheduleResolver.resolve(
            date: selectedDate,
            plan: plan,
            selectedTemplateName: selectedTemplateKey
        )

        appleProgress = AppleProgress.calculate(
            events: resolvedEvents,
            logEntries: logEntries,
            referenceDate: Date()
        )

        let items = Dictionary(uniqueKeysWithValues: (plan.template(for: selectedDate, selectedTemplateName: selectedTemplateKey)?.items ?? []).map { ($0.id, $0) })
        energyBalance = CalorieEngine.calculateBalance(
            now: Date(),
            entries: logEntries,
            items: items,
            events: resolvedEvents,
            dailyBasalEstimate: 1600.0,
            fallbackHistoricalBurn: 2200.0
        )

        weeklyStats = WeeklyStatsCalculator.calculate(
            events: resolvedEvents,
            logs: logEntries,
            sleepEntries: sleepEntries,
            trainingDays: [],
            dailyBalances: [energyBalance?.balanceNow ?? 0.0],
            now: Date()
        )
    }

    // MARK: - Plan Loading Helper
    private static func loadDefaultPlan() -> Plan {
        // Try loading plan.json from main bundle
        if let url = Bundle.main.url(forResource: "plan", withExtension: "json"),
           let plan = try? PlanLoader.loadPlan(from: url) {
            return ensureRestTemplate(plan)
        }

        // Try plan.sample.json
        if let url = Bundle.main.url(forResource: "plan.sample", withExtension: "json"),
           let plan = try? PlanLoader.loadPlan(from: url) {
            return ensureRestTemplate(plan)
        }

        // Try direct filesystem in working directory
        let localPaths = [
            "/Users/john_ak/antigarvity/Orchard/plan.json",
            "/Users/john_ak/antigarvity/Orchard/Resources/plan.json"
        ]
        for path in localPaths {
            if FileManager.default.fileExists(atPath: path),
               let plan = try? PlanLoader.loadPlan(fromFilePath: path) {
                return ensureRestTemplate(plan)
            }
        }

        // Fallback minimal default plan
        let defaultTemplate = DayTemplate(
            trainingSessions: [TrainingSession(start: "18:00", durationMinutes: 90, estKcal: 600)],
            items: [
                PlanItem(id: "d1_breakfast", type: .meal, title: "Πρωινό: Βρώμη με γάλα και μέλι", anchor: .afterWake(minutes: 30), kcal: 450, protein: 25, carbs: 60, fat: 10),
                PlanItem(id: "d1_lunch", type: .meal, title: "Μεσημεριανό: Κοτόπουλο φιλέτο με ρύζι", anchor: .absolute(time: "14:00"), kcal: 650, protein: 50, carbs: 70, fat: 12),
                PlanItem(id: "d1_snack", type: .meal, title: "Απογευματινό: Φρούτο και ξηροί καρποί", anchor: .beforeTraining(minutes: 90), kcal: 300, protein: 10, carbs: 40, fat: 10),
                PlanItem(id: "d1_dinner", type: .meal, title: "Βραδινό: Ομελέτα με λαχανικά", anchor: .afterTraining(minutes: 45), kcal: 500, protein: 35, carbs: 20, fat: 18)
            ]
        )

        var templates = ["day_1": defaultTemplate]
        templates["rest"] = DayTemplate(
            trainingSessions: [],
            items: [],
            rules: [Rule(type: .prefer, text: "Ημέρα ανάπαυσης και αποκατάστασης")]
        )

        return Plan(
            settings: PlanSettings(wake: "07:30", bed: "23:30", minMealGapMinutes: 60),
            weekly: ["mon": "day_1", "tue": "day_1", "wed": "day_1", "thu": "day_1", "fri": "day_1", "sat": "day_1", "sun": "rest"],
            templates: templates
        )
    }

    private static func ensureRestTemplate(_ plan: Plan) -> Plan {
        var mutablePlan = plan
        if mutablePlan.templates["rest"] == nil {
            mutablePlan.templates["rest"] = DayTemplate(
                trainingSessions: [],
                items: [],
                rules: [Rule(type: .prefer, text: "Ημέρα ανάπαυσης και αποκατάστασης")]
            )
        }
        return mutablePlan
    }
}
