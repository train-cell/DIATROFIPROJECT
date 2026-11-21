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
    @Published public var selectedDate: Date = Date() {
        didSet {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            let dateKey = f.string(from: selectedDate)
            self.selectedTemplateKey = self.selectedTemplatesByDate[dateKey] ?? self.plan.templateKey(for: selectedDate) ?? self.selectedTemplateKey
            self.waterIntakeMl = UserDefaults.standard.double(forKey: "orchard.water.\(dateKey)")
            self.logEntries = Self.loadLogEntries(forDateKey: dateKey)
            refreshSchedule()
        }
    }
    @Published public var selectedTemplatesByDate: [String: String] = [:]
    @Published public var selectedOptionsByDate: [String: [String: String]] = [:]
    @Published public var logEntries: [LogEntry] = []
    @Published public var biteCount: Int = 0

    // MARK: - Water Hydration Tracking (Dynamic Target)
    @Published public var waterIntakeMl: Double = 0.0

    public var targetWaterMl: Double {
        if let template = plan.template(for: selectedDate, selectedTemplateName: selectedTemplateKey),
           let tMl = template.targetWaterMl, tMl > 0 {
            return tMl
        }
        return plan.settings.targetWaterMl > 0 ? plan.settings.targetWaterMl : 3000.0
    }

    // MARK: - Optional Fasting & Goal Tracking ON/OFF
    @Published public var isFastingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isFastingEnabled, forKey: "orchard.fastingEnabled")
        }
    }

    @Published public var isGoalTrackingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isGoalTrackingEnabled, forKey: "orchard.goalTrackingEnabled")
        }
    }

    // MARK: - AI Nutrition Coach State
    @Published public var aiAutoLogEnabled: Bool {
        didSet {
            UserDefaults.standard.set(aiAutoLogEnabled, forKey: "orchard.ai.autoLogEnabled")
        }
    }
    @Published public var aiChatMessages: [AICoachChatMessage] = []

    // MARK: - 12 Premier Athletic Features State
    @Published public var weightLogs: [DailyWeightLog] = [
        DailyWeightLog(date: Date().addingTimeInterval(-13 * 86400), weightKg: 82.0, intakeKcal: 2300),
        DailyWeightLog(date: Date().addingTimeInterval(-10 * 86400), weightKg: 81.8, intakeKcal: 2250),
        DailyWeightLog(date: Date().addingTimeInterval(-7 * 86400), weightKg: 81.5, intakeKcal: 2320),
        DailyWeightLog(date: Date().addingTimeInterval(-4 * 86400), weightKg: 81.3, intakeKcal: 2280),
        DailyWeightLog(date: Date(), weightKg: 81.0, intakeKcal: 2300)
    ]
    @Published public var coachingGoal: CoachingGoal = .maintenance
    @Published public var targetGoalWeightKg: Double = 78.0
    @Published public var digestiveLogs: [DigestiveLog] = []
    @Published public var customRecipes: [CustomRecipe] = []
    @Published public var fastingProtocol: FastingProtocol = .classic16_8

    @Published public var resolvedEvents: [ScheduledEvent] = []
    @Published public var appleProgress: AppleProgress = AppleProgress()
    @Published public var supplementProgress: SupplementProgress = SupplementProgress(completed: 0, total: 0, isCompleted: true)
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

        // 0. Load Feature Toggles (default false)
        self.isFastingEnabled = UserDefaults.standard.bool(forKey: "orchard.fastingEnabled")
        self.isGoalTrackingEnabled = UserDefaults.standard.bool(forKey: "orchard.goalTrackingEnabled")
        self.aiAutoLogEnabled = UserDefaults.standard.bool(forKey: "orchard.ai.autoLogEnabled")

        // 1. Load Plan from bundle or embedded fallback
        let loadedPlan = Self.loadDefaultPlan()
        self.plan = loadedPlan

        // 2. Initial template key from weekday or today's saved selection
        let savedMap = UserDefaults.standard.dictionary(forKey: "orchard.selectedTemplatesByDate") as? [String: String] ?? [:]
        self.selectedTemplatesByDate = savedMap

        let savedOptions = UserDefaults.standard.dictionary(forKey: "orchard.selectedOptionsByDate") as? [String: [String: String]] ?? [:]
        self.selectedOptionsByDate = savedOptions

        let todayFormatter = DateFormatter()
        todayFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = todayFormatter.string(from: Date())
        let savedToday = savedMap[todayKey]
        let initialKey = savedToday ?? (loadedPlan.templateKey(for: Date()) ?? loadedPlan.templates.keys.sorted().first ?? "training")
        self.selectedTemplateKey = initialKey

        // 3. Load today's hydration intake & persisted log entries
        self.waterIntakeMl = UserDefaults.standard.double(forKey: "orchard.water.\(todayKey)")
        if NSClassFromString("XCTestCase") == nil {
            self.logEntries = Self.loadLogEntries(forDateKey: todayKey)
        } else {
            self.logEntries = []
        }

        // 4. Resolve initial schedule & progress
        self.refreshSchedule()

        // 5. Background sync with HealthKit sleep
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

    // MARK: - Option Selection (Menu Picker)
    public func selectedOption(for item: PlanItem) -> PlanOption? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: selectedDate)
        let optId = selectedOptionsByDate[dateKey]?[item.id]
        if let opt = item.option(for: optId) {
            return opt
        }
        return item.options?.first
    }

    public func selectOption(_ option: PlanOption, for item: PlanItem) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: selectedDate)
        var map = selectedOptionsByDate[dateKey] ?? [:]
        map[item.id] = option.id
        selectedOptionsByDate[dateKey] = map
        UserDefaults.standard.set(selectedOptionsByDate, forKey: "orchard.selectedOptionsByDate")
        refreshSchedule()
    }

    // MARK: - Water Hydration Operations
    public func addWater(ml: Double) {
        waterIntakeMl = max(0.0, waterIntakeMl + ml)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: selectedDate)
        UserDefaults.standard.set(waterIntakeMl, forKey: "orchard.water.\(dateKey)")

        #if canImport(HealthKit)
        if ml > 0, let quantityType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml)
            let sample = HKQuantitySample(type: quantityType, quantity: quantity, start: Date(), end: Date())
            HKHealthStore().save(sample) { _, _ in }
        }
        #endif
    }

    public func resetWater() {
        waterIntakeMl = 0.0
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: selectedDate)
        UserDefaults.standard.removeObject(forKey: "orchard.water.\(dateKey)")
    }

    // MARK: - Persistence for Log Entries
    private static func loadLogEntries(forDateKey dateKey: String) -> [LogEntry] {
        guard let data = UserDefaults.standard.data(forKey: "orchard.logs.\(dateKey)"),
              let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveCurrentLogEntries() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: selectedDate)
        if let data = try? JSONEncoder().encode(logEntries) {
            UserDefaults.standard.set(data, forKey: "orchard.logs.\(dateKey)")
        }
    }

    // MARK: - Logging Operations
    public func logMeal(
        event: ScheduledEvent,
        selectedOption: PlanOption? = nil,
        status: LogStatus = .done,
        kcal: Double? = nil
    ) {
        let wasAlreadyDone = logEntries.contains { ($0.itemId == event.itemId || $0.eventKey == event.id) && $0.status == .done }

        // Remove existing log for this event/item if present
        logEntries.removeAll { $0.itemId == event.itemId || $0.eventKey == event.id }

        let opt = selectedOption ?? self.selectedOption(for: event.item)
        let optMacros = opt != nil ? event.item.effectiveMacros(selectedOptionId: opt?.id) : nil

        let entry = LogEntry(
            eventKey: event.id,
            itemId: event.itemId,
            status: status,
            timestamp: Date(),
            kcal: kcal ?? optMacros?.kcal ?? event.item.kcal,
            protein: optMacros?.protein ?? event.item.protein,
            carbs: optMacros?.carbs ?? event.item.carbs,
            fat: optMacros?.fat ?? event.item.fat,
            source: .plan,
            note: opt?.title ?? event.item.title,
            selectedOptionId: opt?.id,
            selectedOptionTitle: opt?.title
        )
        logEntries.append(entry)

        if status == .done && !wasAlreadyDone {
            biteCount += 1
        }

        saveCurrentLogEntries()
        refreshSchedule()

        let store = self.healthStore
        let item = event.item
        Task {
            try? await store.writeDietaryLog(entry, item: item)
        }
    }

    public func logSupplement(event: ScheduledEvent) {
        let isAlreadyLogged = logEntries.contains { ($0.itemId == event.itemId || $0.eventKey == event.id) && $0.status == .done }

        logEntries.removeAll { $0.itemId == event.itemId || $0.eventKey == event.id }

        let entry = LogEntry(
            eventKey: event.id,
            itemId: event.itemId,
            status: .done,
            timestamp: Date(),
            kcal: event.item.kcal,
            protein: event.item.protein,
            carbs: event.item.carbs,
            fat: event.item.fat,
            source: .plan,
            note: event.item.title
        )
        logEntries.append(entry)

        if !isAlreadyLogged, let waterMl = event.item.waterMl, waterMl > 0 {
            addWater(ml: waterMl)
        }

        saveCurrentLogEntries()
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
            let matchedItem = resolvedEvents.first(where: { $0.itemId == itemId })?.item ?? plan.template(for: selectedDate, selectedTemplateName: selectedTemplateKey)?.items.first(where: { $0.id == itemId })
            let isMeal = matchedItem?.type == .meal || (matchedItem == nil && removedEntry.source == .manual)

            if removedEntry.status == .done && isMeal {
                biteCount = max(0, biteCount - 1)
            }

            // If item has waterMl, subtract it
            if let water = matchedItem?.waterMl, water > 0 {
                addWater(ml: -water)
            }

            logEntries.remove(at: idx)
            saveCurrentLogEntries()
            refreshSchedule()

            let store = self.healthStore
            Task {
                try? await store.deleteDietaryLog(for: removedEntry.id)
            }
        }
    }

    @discardableResult
    public func addManualLog(
        title: String,
        type: PlanItemType,
        kcal: Double?,
        protein: Double?,
        carbs: Double?,
        fat: Double?,
        notes: String? = nil,
        timestamp: Date = Date(),
        source: LogSource = .manual
    ) -> String {
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
            source: source,
            note: "\(title)\(notes.map { " - \($0)" } ?? "")"
        )
        logEntries.append(entry)
        biteCount += 1
        saveCurrentLogEntries()
        refreshSchedule()

        let store = self.healthStore
        Task {
            try? await store.writeDietaryLog(entry, item: nil)
        }
        return uniqueId
    }

    public func deleteLogEntry(id: UUID) {
        if let idx = logEntries.firstIndex(where: { $0.id == id }) {
            let removedEntry = logEntries[idx]
            let matchedItem = resolvedEvents.first(where: { $0.itemId == removedEntry.itemId })?.item ?? plan.template(for: selectedDate, selectedTemplateName: selectedTemplateKey)?.items.first(where: { $0.id == removedEntry.itemId })
            let isManualOrAI: Bool
            switch removedEntry.source {
            case .manual, .ai:
                isManualOrAI = true
            case .plan:
                isManualOrAI = false
            }
            let isMeal = matchedItem?.type == .meal || (matchedItem == nil && isManualOrAI)

            if removedEntry.status == .done && isMeal {
                biteCount = max(0, biteCount - 1)
            }

            if let water = matchedItem?.waterMl, water > 0 {
                addWater(ml: -water)
            }

            logEntries.remove(at: idx)
            saveCurrentLogEntries()
            refreshSchedule()

            let store = self.healthStore
            Task {
                try? await store.deleteDietaryLog(for: removedEntry.id)
            }
        }
    }

    // MARK: - AI Nutrition Coach Operations
    public func makeAICoachSnapshot() -> AICoachDailySnapshot {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let dateKey = f.string(from: selectedDate)
        return AICoachDailySnapshot(
            date: selectedDate,
            weekday: Weekday.from(date: selectedDate),
            selectedTemplateKey: selectedTemplateKey,
            resolvedEvents: resolvedEvents,
            logEntries: logEntries,
            waterIntakeMl: waterIntakeMl,
            targetWaterMl: targetWaterMl,
            selectedOptionIds: selectedOptionsByDate[dateKey] ?? [:]
        )
    }

    @discardableResult
    public func applyAICoachAction(_ action: AICoachLogAction) -> String? {
        switch action.kind {
        case .meal:
            if let itemId = action.itemId, let matchingEvent = resolvedEvents.first(where: { $0.itemId == itemId }) {
                var selectedOpt: PlanOption? = nil
                if let optId = action.selectedOptionId {
                    let matchedOpt = matchingEvent.item.options?.first(where: {
                        $0.id == optId ||
                        $0.id.replacingOccurrences(of: "_opt_", with: "_") == optId ||
                        optId.replacingOccurrences(of: "tupper_", with: "tupper_opt_") == $0.id ||
                        optId.replacingOccurrences(of: "sw_", with: "sw_opt_") == $0.id ||
                        $0.id.hasSuffix(optId) || optId.hasSuffix($0.id)
                    })
                    if let opt = matchedOpt {
                        selectOption(opt, for: matchingEvent.item)
                        selectedOpt = opt
                    }
                }
                logMeal(event: matchingEvent, selectedOption: selectedOpt, kcal: action.kcal)
                return matchingEvent.itemId
            } else {
                return addManualLog(
                    title: action.title,
                    type: .meal,
                    kcal: action.kcal,
                    protein: action.protein,
                    carbs: action.carbs,
                    fat: action.fat,
                    notes: action.notes
                )
            }

        case .supplement:
            if let itemId = action.itemId, let matchingEvent = resolvedEvents.first(where: { $0.itemId == itemId }) {
                logSupplement(event: matchingEvent)
                return matchingEvent.itemId
            } else {
                let logId = addManualLog(
                    title: action.title,
                    type: .supplement,
                    kcal: action.kcal,
                    protein: action.protein,
                    carbs: action.carbs,
                    fat: action.fat,
                    notes: action.notes
                )
                if let water = action.waterMl, water > 0 {
                    addWater(ml: water)
                }
                return logId
            }

        case .water:
            let amount = action.waterMl ?? 250.0
            addWater(ml: amount)
            return nil
        }
    }

    public func undoAICoachAction(_ action: AICoachLogAction, appliedLogId: String? = nil) {
        switch action.kind {
        case .water:
            let amount = action.waterMl ?? 250.0
            addWater(ml: -amount)

        case .meal, .supplement:
            let targetId = appliedLogId ?? action.itemId
            if let id = targetId {
                if resolvedEvents.contains(where: { $0.itemId == id }) {
                    undoLog(itemId: id)
                } else if let entry = logEntries.first(where: { $0.itemId == id || $0.eventKey == id }) {
                    deleteLogEntry(id: entry.id)
                }
            }
            if action.kind == .supplement, action.itemId == nil, let water = action.waterMl, water > 0 {
                addWater(ml: -water)
            }
        }
    }

    public func sendAICoachMessage(_ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMsg = AICoachChatMessage(isUser: true, text: trimmed)
        aiChatMessages.append(userMsg)

        let service = AICoachService.makeLive()
        let response = try await service.sendMessage(
            trimmed,
            history: aiChatMessages,
            plan: plan,
            snapshot: makeAICoachSnapshot()
        )

        var appliedIds = Set<String>()
        var appliedLogMap: [String: String] = [:]
        if aiAutoLogEnabled && !response.suggestedActions.isEmpty {
            for action in response.suggestedActions {
                if let logId = applyAICoachAction(action) {
                    appliedLogMap[action.id] = logId
                }
                appliedIds.insert(action.id)
            }
        }

        let assistantMsg = AICoachChatMessage(
            isUser: false,
            text: response.replyGreek,
            suggestedActions: response.suggestedActions,
            appliedActionIds: appliedIds,
            appliedLogIds: appliedLogMap
        )
        aiChatMessages.append(assistantMsg)
    }

    public func clearAIChat() {
        aiChatMessages.removeAll()
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

        supplementProgress = AppleProgress.calculateSupplements(
            events: resolvedEvents,
            logEntries: logEntries
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

        // Fallback minimal default plan matching protocol #1
        let defaultTemplate = DayTemplate(
            title: "Προπόνηση",
            subtitle: "Τεχνική Κολύμβηση (14:30 - 16:30)",
            icon: "figure.pool.swim",
            targetWaterMl: 3000.0,
            order: 1,
            trainingSessions: [TrainingSession(start: "14:30", durationMinutes: 120, estKcal: 800)],
            items: [
                PlanItem(id: "d1_breakfast", type: .meal, title: "10:30 Πρωινό (Υγρά & Στερεά)", anchor: .afterWake(minutes: 0), kcal: 450, protein: 35, carbs: 45, fat: 12),
                PlanItem(id: "d1_lunch", type: .meal, title: "12:00–12:30 Ελαφρύ Γεύμα (Sandwich/Porridge)", anchor: .beforeTraining(minutes: 120), kcal: 450, protein: 30, carbs: 55, fat: 12),
                PlanItem(id: "d1_intra", type: .supplement, title: "Έως 11:45: 500ml HIGH5 + BCAA + 20g Πρωτεΐνη AFTER", anchor: .beforeTraining(minutes: 165), waterMl: 500),
                PlanItem(id: "d1_post", type: .supplement, title: "Μετά την προπόνηση: 500ml HIGH5 + BCAA + 30g Πρωτεΐνη AFTER + Γλουταμίνη", anchor: .afterTraining(minutes: 0), waterMl: 500),
                PlanItem(id: "d1_dinner", type: .meal, title: "17:30–18:00 Κυρίως Γεύμα (Tupper)", anchor: .afterTraining(minutes: 60), kcal: 700, protein: 50, carbs: 70, fat: 20)
            ]
        )

        var templates = ["training": defaultTemplate]
        templates["rest"] = DayTemplate(
            title: "Ανάπαυση",
            subtitle: "Αποκατάσταση & Ενυδάτωση",
            icon: "bed.double.fill",
            targetWaterMl: 2500.0,
            order: 5,
            trainingSessions: [],
            items: [],
            rules: [Rule(type: .prefer, text: "Ημέρα ανάπαυσης και αποκατάστασης")]
        )

        return Plan(
            settings: PlanSettings(
                wake: "10:30",
                bed: "00:30",
                minMealGapMinutes: 60,
                targetWaterMl: 3000.0,
                minWaterMl: 2500.0,
                sport: "Τεχνική Κολύμβηση",
                planLabel: "Πρόγραμμα #1 (11.11.26)"
            ),
            weekly: ["mon": "training", "tue": "training", "wed": "training", "thu": "training", "fri": "training", "sat": "training", "sun": "rest"],
            templates: templates
        )
    }

    private static func ensureRestTemplate(_ plan: Plan) -> Plan {
        var mutablePlan = plan
        if mutablePlan.templates["rest"] == nil {
            mutablePlan.templates["rest"] = DayTemplate(
                title: "Ανάπαυση",
                subtitle: "Αποκατάσταση & Ενυδάτωση",
                icon: "bed.double.fill",
                targetWaterMl: 2500.0,
                order: 5,
                trainingSessions: [],
                items: [],
                rules: [Rule(type: .prefer, text: "Ημέρα ανάπαυσης και αποκατάστασης")]
            )
        }
        return mutablePlan
    }

    // MARK: - 12 Premier Athletic Features Dynamic Accessors
    public var dynamicExpenditure: ExpenditureResult {
        ExpenditureEngine.estimateExpenditure(logs: weightLogs)
    }

    public var todayMicronutrients: MicronutrientIntake {
        MicronutrientIntake(
            sodiumMg: 2850.0,
            potassiumMg: 3100.0,
            magnesiumMg: 390.0,
            calciumMg: 1050.0,
            zincMg: 14.5,
            ironMg: 16.0,
            vitaminDIU: 2500.0,
            vitaminCMg: 130.0,
            fiberGrams: 34.0
        )
    }

    public var micronutrientProgress: [MicronutrientProgressItem] {
        MicronutrientEngine.evaluateProgress(intake: todayMicronutrients)
    }

    public var electrolyteScore: Int {
        MicronutrientEngine.electrolyteScore(intake: todayMicronutrients)
    }

    public var coachingReport: CoachingCheckInReport {
        CoachingCheckInEngine.evaluateCheckIn(
            goal: coachingGoal,
            currentDailyKcal: energyBalance?.plannedDayKcal ?? 2400.0,
            weeklyWeightChangeKg: dynamicExpenditure.weightChangePerWeekKg,
            adherenceRate: appleProgress.progressFraction,
            bodyweightKg: weightLogs.last?.weightKg ?? 81.0
        )
    }

    public var fastingStatus: FastingStatus {
        let lastMealTime = resolvedEvents.filter { $0.item.type == .meal }.last?.resolvedTime ?? Date().addingTimeInterval(-14 * 3600)
        return FastingEngine.evaluateStatus(lastMealTime: lastMealTime, protocolType: fastingProtocol)
    }

    public var habitStreaks: StreakSummary {
        let todayStatus = DailyHabitStatus(
            date: selectedDate,
            isNutritionCompleted: appleProgress.progressFraction >= 0.75,
            isHydrationCompleted: waterIntakeMl >= targetWaterMl,
            isSleepCompleted: (sleepEntries.first?.recoveryScore ?? 80) >= 75,
            isSupplementsCompleted: supplementProgress.total == 0 || supplementProgress.isCompleted
        )
        return HabitStreakEngine.computeStreaks(history: [todayStatus])
    }

    public var periWorkoutStatus: PeriWorkoutStatus {
        let cal = Calendar.current
        let currentTemplate = plan.template(for: selectedDate, selectedTemplateName: selectedTemplateKey)
        let sessions = currentTemplate?.trainingSessions ?? []

        if sessions.isEmpty {
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDate) ?? Date()
            return PeriWorkoutEngine.evaluatePhase(workoutStart: noon, workoutEnd: noon)
        }

        let now = Date()
        var selectedSession: (start: Date, end: Date)? = nil

        let resolvedSessions: [(start: Date, end: Date)] = sessions.compactMap { session in
            guard let startStr = session.start else { return nil }
            let parts = startStr.split(separator: ":").compactMap { Int($0) }
            guard parts.count >= 2,
                  let startDate = cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: selectedDate) else {
                return nil
            }
            let endDate = startDate.addingTimeInterval(TimeInterval(session.durationMinutes * 60))
            return (start: startDate, end: endDate)
        }.sorted { $0.start < $1.start }

        // 1. Check if we are inside or in anabolic window of a session
        for s in resolvedSessions {
            if now >= s.start.addingTimeInterval(-1800) && now <= s.end.addingTimeInterval(7200) {
                selectedSession = s
                break
            }
        }

        // 2. Otherwise pick next upcoming session today
        if selectedSession == nil {
            selectedSession = resolvedSessions.first(where: { $0.start > now })
        }

        let finalSession = selectedSession ?? resolvedSessions.first

        if let s = finalSession {
            return PeriWorkoutEngine.evaluatePhase(workoutStart: s.start, workoutEnd: s.end)
        }

        let fallbackStart = cal.date(bySettingHour: 14, minute: 30, second: 0, of: selectedDate) ?? Date()
        return PeriWorkoutEngine.evaluatePhase(workoutStart: fallbackStart, workoutEnd: fallbackStart.addingTimeInterval(7200))
    }

    public var workoutFuelReport: WorkoutFuelReport {
        let burn = energyBalance?.outSoFar ?? 550.0
        let periCarbs = resolvedEvents.filter { $0.item.type == .meal }.reduce(0.0) { $0 + ($1.item.carbs ?? 0.0) } * 0.5
        return WorkoutFuelEngine.evaluateFueling(workoutBurnKcal: burn, periWorkoutCarbsConsumedGrams: periCarbs)
    }

    public var weightProjection: WeightProjectionResult {
        let startWeight = weightLogs.last?.weightKg ?? 81.0
        let delta = energyBalance?.projectedBalance ?? -450.0
        return WeightProjectionEngine.projectTrajectory(
            startWeightKg: startWeight,
            targetWeightKg: targetGoalWeightKg,
            dailyKcalDelta: delta,
            startDate: selectedDate
        )
    }

    public func exportCSV() -> String {
        let items = Dictionary(uniqueKeysWithValues: (plan.template(for: selectedDate, selectedTemplateName: selectedTemplateKey)?.items ?? []).map { ($0.id, $0) })
        let macros = CalorieEngine.consumedMacros(entries: logEntries, items: items)
        let record = DailyReportRecord(
            dateString: {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f.string(from: selectedDate)
            }(),
            templateKey: selectedTemplateKey,
            kcalConsumed: energyBalance?.consumedKcal ?? macros.kcal,
            kcalBurned: energyBalance?.projectedOut ?? 2700.0,
            balanceKcal: energyBalance?.projectedBalance ?? -450.0,
            proteinGrams: macros.protein,
            carbsGrams: macros.carbs,
            fatGrams: macros.fat,
            waterMl: waterIntakeMl,
            sleepHours: Double(sleepEntries.first?.asleepMinutes ?? 450) / 60.0,
            sleepRecoveryScore: sleepEntries.first?.recoveryScore ?? 85,
            adherencePercent: Int(round(appleProgress.progressFraction * 100.0))
        )
        return ReportExportEngine.generateCSV(records: [record])
    }

    public func exportCoachSummary() -> String {
        let items = Dictionary(uniqueKeysWithValues: (plan.template(for: selectedDate, selectedTemplateName: selectedTemplateKey)?.items ?? []).map { ($0.id, $0) })
        let macros = CalorieEngine.consumedMacros(entries: logEntries, items: items)
        let record = DailyReportRecord(
            dateString: {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f.string(from: selectedDate)
            }(),
            templateKey: selectedTemplateKey,
            kcalConsumed: energyBalance?.consumedKcal ?? macros.kcal,
            kcalBurned: energyBalance?.projectedOut ?? 2700.0,
            balanceKcal: energyBalance?.projectedBalance ?? -450.0,
            proteinGrams: macros.protein,
            carbsGrams: macros.carbs,
            fatGrams: macros.fat,
            waterMl: waterIntakeMl,
            sleepHours: Double(sleepEntries.first?.asleepMinutes ?? 450) / 60.0,
            sleepRecoveryScore: sleepEntries.first?.recoveryScore ?? 85,
            adherencePercent: Int(round(appleProgress.progressFraction * 100.0))
        )
        return ReportExportEngine.generateCoachSummary(athleteName: "John Akrivos", records: [record])
    }
}
