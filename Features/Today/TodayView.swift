import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif

extension Weekday {
    fileprivate var shortGreek: String {
        switch self {
        case .mon: return "ΔΕ"
        case .tue: return "ΤΡ"
        case .wed: return "ΤΕ"
        case .thu: return "ΠΕ"
        case .fri: return "ΠΑ"
        case .sat: return "ΣΑ"
        case .sun: return "ΚΥ"
        }
    }
}

public struct TodayView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var showSleepSheet: Bool = false
    @State private var selectedEventForOptions: ScheduledEvent? = nil
    @State private var showAICoachChat: Bool = false

    public init() {}

    /// Dynamic Day Mode templates sorted by `order`
    private var sortedDayTemplates: [(key: String, template: DayTemplate)] {
        container.plan.templates.map { ($0.key, $0.value) }
            .sorted { ($0.template.order ?? 999, $0.key) < ($1.template.order ?? 999, $1.key) }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Dynamic Day Mode Template Picker Chips
                    templatePickerSection

                    // 1.5 Habit Streaks & 4-Rings Status
                    habitStreakPillSection

                    // 2. Hero Apple Progress View
                    heroAppleSection

                    // 3. Hydration Tracking Section (Dynamic Target)
                    hydrationSection

                    // 4. AutoSleep / Bevel Recovery Quick Card
                    sleepRecoveryCardSection

                    // 4.5 Optional Fasting & Peri-Workout Nutrient Timing Section
                    fastingAndPeriWorkoutSection

                    // 5. "Now / Next" Hero Card (Meals + Standalone Supplements)
                    nowNextCardSection

                    // 6. Interactive Timeline (Meals + Standalone Supplements)
                    timelineSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 36)
            }
            .background(OrchardColors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "tab_today"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSleepSheet) {
                SleepDetailView(sleepEntry: container.sleepEntries.first)
            }
            .sheet(item: $selectedEventForOptions) { event in
                MenuOptionPickerSheet(event: event, container: container)
            }
            .sheet(isPresented: $showAICoachChat) {
                AICoachChatView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            Haptics.selection()
                            showAICoachChat = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                                Text("AI ✨")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(Color.purple)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("ai_coach_button")

                        Button {
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                container.refreshSchedule()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(OrchardColors.appleRed)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 1. Dynamic Day Mode Picker Section
    private var templatePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ΕΠΙΛΟΓΗ ΗΜΕΡΗΣΙΟΥ ΠΡΟΓΡΑΜΜΑΤΟΣ")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                Spacer()
            }
            .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sortedDayTemplates, id: \.key) { item in
                        let key = item.key
                        let template = item.template
                        let isSelected = container.selectedTemplateKey == key
                        let title = template.title ?? key
                        let subtitle = template.subtitle ?? ""
                        let iconName = template.icon ?? (template.trainingSessions.isEmpty ? "bed.double.fill" : "figure.pool.swim")

                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                container.selectTemplate(key: key)
                            }
                        } label: {
                            VStack(spacing: 3) {
                                HStack(spacing: 5) {
                                    Image(systemName: iconName)
                                        .font(.system(size: 12))
                                    Text(title)
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                }
                                .foregroundStyle(isSelected ? Color.white : OrchardColors.text)

                                if !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(.system(size: 10, weight: .regular, design: .rounded))
                                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : .secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? OrchardColors.appleRed : Color.secondary.opacity(0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 2)
            }

            // Dedicated Active Day Confirmation Banner
            if let active = container.plan.template(for: container.selectedDate, selectedTemplateName: container.selectedTemplateKey) {
                let activeTitle = active.title ?? container.selectedTemplateKey
                let activeSubtitle = active.subtitle ?? ""
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(OrchardColors.leafGreen)
                            .font(.system(size: 13))

                        Text("Ενεργό: Ακολουθείς το πρόγραμμα **\(activeTitle)**\(activeSubtitle.isEmpty ? "" : " (\(activeSubtitle))").")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(OrchardColors.text)
                        Spacer()
                    }
                }
                .padding(8)
                .background(OrchardColors.leafGreen.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 2)
                .padding(.top, 2)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Habit Streaks & 4-Rings Pill
    private var habitStreakPillSection: some View {
        let streaks = container.habitStreaks
        let suppProgress = container.supplementProgress
        let suppLabel = suppProgress.total > 0 ? "Supps (\(suppProgress.completed)/\(suppProgress.total))" : "Supps"
        let waterLabel = String(format: "%.1fL Νερό", container.targetWaterMl / 1000.0)

        return HStack(spacing: 8) {
            HStack(spacing: 5) {
                Text("🔥")
                    .font(.system(size: 13))
                Text("\(streaks.currentStreakDays) ΗΜΕΡΕΣ STREAK")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.12))
            .clipShape(Capsule())

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                habitRing(title: "Διατροφή", isDone: container.appleProgress.progressFraction >= 0.75, color: .green)
                habitRing(title: waterLabel, isDone: container.waterIntakeMl >= container.targetWaterMl, color: .cyan)
                habitRing(title: "Ύπνος", isDone: (container.sleepEntries.first?.recoveryScore ?? 85) >= 75, color: .indigo)
                habitRing(title: suppLabel, isDone: suppProgress.isCompleted, color: .purple)
            }
        }
        .padding(.horizontal, 2)
    }

    private func habitRing(title: String, isDone: Bool, color: Color) -> some View {
        HStack(spacing: 3) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.25), lineWidth: 2)
                    .frame(width: 9, height: 9)
                if isDone {
                    Circle()
                        .trim(from: 0.0, to: 1.0)
                        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 9, height: 9)
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                }
            }
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(isDone ? color : .secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - 2. Hero Apple Progress Section
    private var heroAppleSection: some View {
        VStack(spacing: 12) {
            HeroAppleView(
                progress: container.appleProgress,
                biteCount: container.biteCount,
                onBiteTapped: {
                    Haptics.impact(.medium)
                }
            )
            .padding(.top, 6)

            // Progress Summary Text
            if container.appleProgress.totalPlannedKcal > 0 {
                let remaining = container.appleProgress.remainingKcal
                if remaining > 0 {
                    Text("Απομένουν **\(Int(remaining)) kcal** για τον σημερινό στόχο")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(OrchardColors.leafGreen)
                        Text("Ολοκληρώθηκε ο ημερήσιος θερμιδικός στόχος!")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(OrchardColors.leafGreen)
                    }
                }
            } else if container.appleProgress.totalCount > 0 {
                Text("\(container.appleProgress.eatenCount) από \(container.appleProgress.totalCount) γεύματα καταγράφηκαν")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text("Ημέρα ανάπαυσης. Ξεκούραση & ενυδάτωση.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - 3. Dynamic Hydration Tracking Section
    private var hydrationSection: some View {
        let progress = min(1.0, container.waterIntakeMl / container.targetWaterMl)
        let litersCurrent = container.waterIntakeMl / 1000.0
        let litersTarget = container.targetWaterMl / 1000.0
        let percent = Int(progress * 100)

        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Color.cyan)
                        .font(.system(size: 14))
                    Text(String(format: "ΕΝΥΔΑΤΩΣΗ (ΣΤΟΧΟΣ %.1f L)", litersTarget))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                }

                Spacer()

                Text("\(percent)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.18))
                    .foregroundStyle(Color.cyan)
                    .clipShape(Capsule())
            }

            // Stats & Progress Bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(format: "%.2f", litersCurrent))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.text)
                    Text(String(format: "/ %.2f L", litersTarget))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if container.waterIntakeMl >= container.targetWaterMl {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OrchardColors.leafGreen)
                            Text("Στόχος επετεύχθη! 💧")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(OrchardColors.leafGreen)
                        }
                    } else {
                        let remainingL = max(0.0, litersTarget - litersCurrent)
                        Text("Απομένουν \(String(format: "%.2f", remainingL)) L")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                // Smooth Animated Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(height: 12)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(12, geo.size.width * CGFloat(progress)), height: 12)
                            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: container.waterIntakeMl)
                    }
                }
                .frame(height: 12)
            }

            // Quick Add Buttons
            HStack(spacing: 6) {
                waterQuickButton(label: "+250 ml", ml: 250)
                waterQuickButton(label: "+500 ml", ml: 500)
                waterQuickButton(label: "+1.0 L", ml: 1000)
                waterQuickButton(label: "HIGH5+BCAA", ml: 500, isElectrolyte: true)

                if container.waterIntakeMl > 0 {
                    Button {
                        Haptics.impact(.light)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            container.resetWater()
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func waterQuickButton(label: String, ml: Double, isElectrolyte: Bool = false) -> some View {
        Button {
            Haptics.impact(.medium)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                container.addWater(ml: ml)
            }
        } label: {
            HStack(spacing: 3) {
                if isElectrolyte {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8))
                }
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .background(isElectrolyte ? Color.orange.opacity(0.15) : Color.cyan.opacity(0.15))
            .foregroundStyle(isElectrolyte ? Color.orange : Color.cyan)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4. Sleep & Recovery Quick Card Section
    private var sleepRecoveryCardSection: some View {
        let sleep = container.sleepEntries.first ?? SleepEntry(
            date: Date(),
            rating: 4,
            tags: ["Ξεκούραστος"],
            asleepMinutes: 445,
            deepSleepMinutes: 85,
            remSleepMinutes: 105,
            coreSleepMinutes: 255,
            awakeMinutes: 30,
            inBedMinutes: 475,
            hrvMs: 68.0,
            restingHeartRateBpm: 52.0
        )

        let totalAsleep = sleep.asleepMinutes ?? 445
        let asleepHours = totalAsleep / 60
        let asleepRemainingMinutes = totalAsleep % 60
        let deepMin = sleep.deepSleepMinutes ?? 85
        let remMin = sleep.remSleepMinutes ?? 105
        let hrvVal = Int(round(sleep.hrvMs ?? 68.0))
        let rhrVal = Int(round(sleep.restingHeartRateBpm ?? 52.0))

        return Button {
            Haptics.selection()
            showSleepSheet = true
        } label: {
            HStack(spacing: 14) {
                // Mini Score Ring
                ZStack {
                    Circle()
                        .stroke(Color.indigo.opacity(0.2), lineWidth: 6)
                        .frame(width: 54, height: 54)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(sleep.recoveryScore) / 100.0)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan, Color.indigo, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 54, height: 54)
                        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: sleep.recoveryScore)

                    Text("\(sleep.recoveryScore)%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.text)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("ΑΠΟΚΑΤΑΣΤΑΣΗ & ΥΠΝΟΣ")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)

                        Text("AutoSleep / Bevel")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.indigo.opacity(0.15))
                            .foregroundStyle(Color.indigo)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 6) {
                        Text("\(asleepHours)ω \(asleepRemainingMinutes)λ")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(OrchardColors.text)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text("Deep \(deepMin)λ")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.purple)

                        Text("REM \(remMin)λ")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.cyan)

                        Text("HRV \(hrvVal)ms")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.green)
                    }

                    Text("RHR: \(rhrVal) bpm • \(sleep.recoveryScore)% Readiness • Πλήρες Hypnogram ➔")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.indigo)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer()
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4.5 Fasting (Optional) & Peri-Workout Nutrient Timing Section
    private var fastingAndPeriWorkoutSection: some View {
        let fasting = container.fastingStatus
        let peri = container.periWorkoutStatus
        let currentTemplate = container.plan.template(for: container.selectedDate, selectedTemplateName: container.selectedTemplateKey)
        let isRestDay = (currentTemplate?.trainingSessions ?? []).isEmpty

        return VStack(spacing: 10) {
            // 1. Intermittent Fasting Card (Shown ONLY when enabled)
            if container.isFastingEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(fasting.protocolType.titleGreek, systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.purple)

                        Spacer()

                        Text(fasting.isFasting ? "Νηστεία" : "Παράθυρο Διατροφής")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(fasting.isFasting ? Color.purple.opacity(0.15) : Color.green.opacity(0.15))
                            .foregroundStyle(fasting.isFasting ? Color.purple : Color.green)
                            .clipShape(Capsule())
                    }

                    HStack {
                        Text(fasting.stage.titleGreek)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(OrchardColors.text)

                        Spacer()

                        let hrs = Int(fasting.remainingSeconds) / 3600
                        let mins = (Int(fasting.remainingSeconds) % 3600) / 60
                        Text(fasting.isGoalCompleted ? "Στόχος Ολοκληρώθηκε! 🎉" : "Απομένουν: \(hrs)ω \(mins)λ")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.purple.opacity(0.15))
                                .frame(height: 4)
                            Capsule()
                                .fill(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(fasting.progressFraction), height: 4)
                                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: fasting.progressFraction)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // 2. Peri-Workout Timing Card (Swim Icon & Multi-session aware)
            HStack(spacing: 10) {
                Image(systemName: isRestDay ? "bed.double.fill" : "figure.pool.swim")
                    .font(.system(size: 16))
                    .foregroundStyle(isRestDay ? Color.blue : Color.orange)
                    .frame(width: 32, height: 32)
                    .background((isRestDay ? Color.blue : Color.orange).opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    if isRestDay {
                        Text("Ημέρα Ανάπαυσης & Αποκατάστασης")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(OrchardColors.text)
                        Text("Ξεκούραση, πλήρης ενυδάτωση & αποθήκευση γλυκογόνου.")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text(peri.phase.titleGreek)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(OrchardColors.text)

                            if peri.isAnabolicWindowActive {
                                Text("Αναβολικό 0-45′ ⚡️")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.red.opacity(0.15))
                                    .foregroundStyle(Color.red)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(peri.phase.nutrientFocusGreek)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - 5. "Now / Next" Hero Card (Meals + All Supplements & Attached Items)
    private var timelineEvents: [ScheduledEvent] {
        container.resolvedEvents.enumerated().sorted { (a, b) in
            if a.element.resolvedTime != b.element.resolvedTime {
                return a.element.resolvedTime < b.element.resolvedTime
            }
            return a.offset < b.offset
        }.map(\.element)
    }

    private var nowNextCardSection: some View {
        let pendingEvents = timelineEvents.filter { event in
            !container.logEntries.contains { ($0.itemId == event.itemId || $0.eventKey == event.id) && $0.status == .done }
        }

        let targetEvent = pendingEvents.first(where: { $0.item.isOptional != true }) ?? pendingEvents.first

        return Group {
            if let target = targetEvent {
                nowNextCard(for: target)
            } else if !timelineEvents.isEmpty {
                allMealsCompletedCard
            }
        }
    }

    private func nowNextCard(for event: ScheduledEvent) -> some View {
        let isOverdue = event.item.isOptional != true && Date() > event.resolvedTime
        let timeRemainingString = formattedTimeRemaining(to: event.resolvedTime)
        let isSupplement = event.item.type == .supplement
        let selectedOpt = isSupplement ? nil : container.selectedOption(for: event.item)
        let effectiveMacros = event.item.effectiveMacros(selectedOptionId: selectedOpt?.id)

        return VStack(alignment: .leading, spacing: 14) {
            // Header: Status badge & time
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(isSupplement ? Color.indigo : (isOverdue ? Color.orange : OrchardColors.appleRed))
                        .frame(width: 8, height: 8)

                    Text(isSupplement ? "ΕΠΟΜΕΝΟ ΣΥΜΠΛΗΡΩΜΑ" : (isOverdue ? "ΤΩΡΑ / ΚΑΘΥΣΤΕΡΗΜΕΝΟ" : "ΕΠΟΜΕΝΟ ΓΕΥΜΑ"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isSupplement ? Color.indigo : (isOverdue ? Color.orange : OrchardColors.appleRed))
                        .tracking(0.8)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    (isSupplement ? Color.indigo : (isOverdue ? Color.orange : OrchardColors.appleRed)).opacity(0.12)
                )
                .clipShape(Capsule())

                if event.item.isOptional == true {
                    Text("Προαιρετικό")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(timeRemainingString)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.secondary)
            }

            // Title & Selected Option
            VStack(alignment: .leading, spacing: 4) {
                Text(event.item.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)
                    .fixedSize(horizontal: false, vertical: true)

                if let opt = selectedOpt {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.purple)
                        Text("Επιλογή: \(opt.title)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.purple)
                    }
                }

                if let parentId = event.attachedToItemId {
                    let parentTitle = container.resolvedEvents.first(where: { $0.itemId == parentId })?.item.title ?? "Κύριο Γεύμα"
                    HStack(spacing: 3) {
                        Image(systemName: "link")
                            .font(.system(size: 9))
                        Text("Μαζί με: \(parentTitle)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
                }

                Text("Προγραμματισμένο στις \(formatTime(event.resolvedTime))")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Attached supplements (if meal) or Water & Weekday pills (if supplement)
            if isSupplement {
                HStack(spacing: 6) {
                    if let water = event.item.waterMl, water > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 9))
                            Text("+\(Int(water))ml")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.cyan.opacity(0.15))
                        .foregroundStyle(Color.cyan)
                        .clipShape(Capsule())
                    }

                    if let weekdays = event.item.activeWeekdays, !weekdays.isEmpty {
                        Text("ΜΟΝΟ " + weekdays.map(\.shortGreek).joined(separator: " & "))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            } else if !event.attachedItems.isEmpty {
                HStack(spacing: 6) {
                    ForEach(event.attachedItems) { item in
                        HStack(spacing: 3) {
                            Image(systemName: "pill.fill")
                                .font(.system(size: 10))
                            Text(item.title)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(OrchardColors.leafGreen.opacity(0.15))
                        .foregroundStyle(OrchardColors.leafGreen)
                        .clipShape(Capsule())
                    }
                }
            }

            // Nutrition Chips (for any item with calories or protein)
            if effectiveMacros.kcal > 0 || effectiveMacros.protein > 0 {
                HStack(spacing: 8) {
                    if effectiveMacros.kcal > 0 {
                        macroChip(label: "\(Int(effectiveMacros.kcal)) kcal", icon: "flame.fill", color: OrchardColors.appleRed)
                    }
                    if effectiveMacros.protein > 0 {
                        macroChip(label: "\(Int(effectiveMacros.protein))g P", icon: "figure.strengthtraining.traditional", color: .blue)
                    }
                    if effectiveMacros.carbs > 0 {
                        macroChip(label: "\(Int(effectiveMacros.carbs))g C", icon: "leaf.fill", color: .orange)
                    }
                    if effectiveMacros.fat > 0 {
                        macroChip(label: "\(Int(effectiveMacros.fat))g F", icon: "drop.fill", color: .purple)
                    }
                }
            }

            if let options = event.item.options, !options.isEmpty {
                Button {
                    Haptics.selection()
                    selectedEventForOptions = event
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text("Μενού (\(options.count) επιλογές)")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.12))
                    .foregroundStyle(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // Action Button
            if isSupplement {
                Button {
                    Haptics.success()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        container.logSupplement(event: event)
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Πήρα ✅")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(LinearGradient(colors: [Color.indigo, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.indigo.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Haptics.success()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        container.logMeal(event: event)
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Έφαγα ✅")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [OrchardColors.appleRed, OrchardColors.appleRed.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: OrchardColors.appleRed.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isOverdue ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var allMealsCompletedCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "apple.logo")
                .font(.system(size: 32))
                .foregroundStyle(OrchardColors.appleRed)

            Text("Όλα τα γεύματα & συμπληρώματα ολοκληρώθηκαν! 🍎")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(OrchardColors.text)

            Text("Έχεις καταγράψει όλο το προγραμματισμένο πλάνο της ημέρας.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OrchardColors.leafGreen.opacity(0.12))
        )
    }

    // MARK: - 6. Interactive Timeline Section (Meals + Standalone Supplements)
    private var timelineSection: some View {
        let events = timelineEvents

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ΧΡΟΝΟΔΙΑΓΡΑΜΜΑ ΗΜΕΡΑΣ")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.0)
                Spacer()
                Text("\(events.count) στοιχεία")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)

            if events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Δεν υπάρχουν προγραμματισμένα στοιχεία για σήμερα.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                VStack(spacing: 12) {
                    ForEach(events.indices, id: \.self) { idx in
                        let event = events[idx]
                        let isDone = container.logEntries.contains { ($0.itemId == event.itemId || $0.eventKey == event.id) && $0.status == .done }
                        let isOverdue = !isDone && event.item.isOptional != true && Date() > event.resolvedTime

                        timelineRow(event: event, isDone: isDone, isOverdue: isOverdue)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func timelineRow(event: ScheduledEvent, isDone: Bool, isOverdue: Bool) -> some View {
        let isSupplement = event.item.type == .supplement
        let selectedOpt = isSupplement ? nil : container.selectedOption(for: event.item)
        let effectiveMacros = event.item.effectiveMacros(selectedOptionId: selectedOpt?.id)

        return HStack(alignment: .top, spacing: 12) {
            // Left time indicator & dot
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTime(event.resolvedTime))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isDone ? .secondary : OrchardColors.text)

                Circle()
                    .fill(
                        isDone ? OrchardColors.leafGreen : (isOverdue ? Color.orange : (isSupplement ? Color.indigo : OrchardColors.appleRed))
                    )
                    .frame(width: 10, height: 10)
            }
            .frame(width: 52)
            .padding(.top, 4)

            // Item Card
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            if isSupplement {
                                Image(systemName: "pill.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.indigo)
                            }
                            Text(event.item.title)
                                .font(.system(size: 15, weight: isDone ? .medium : .semibold, design: .rounded))
                                .foregroundStyle(isDone ? .secondary : OrchardColors.text)
                                .strikethrough(isDone, color: .secondary.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let opt = selectedOpt {
                            Text("Επιλογή: \(opt.title)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(isDone ? .secondary : Color.purple)
                        }

                        if let parentId = event.attachedToItemId {
                            let parentTitle = container.resolvedEvents.first(where: { $0.itemId == parentId })?.item.title ?? "Κύριο Γεύμα"
                            HStack(spacing: 3) {
                                Image(systemName: "link")
                                    .font(.system(size: 8.5))
                                Text("Μαζί με: \(parentTitle)")
                                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    if isOverdue {
                        Text("Καθυστερημένο")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    } else if event.item.isOptional == true {
                        Text("Προαιρετικό")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }

                // Badges for supplements or attached supplements
                if isSupplement {
                    HStack(spacing: 6) {
                        if let water = event.item.waterMl, water > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 9))
                                Text("+\(Int(water))ml")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.15))
                            .foregroundStyle(Color.cyan)
                            .clipShape(Capsule())
                        }

                        if let weekdays = event.item.activeWeekdays, !weekdays.isEmpty {
                            Text("ΜΟΝΟ " + weekdays.map(\.shortGreek).joined(separator: " & "))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                } else if !event.attachedItems.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(event.attachedItems) { item in
                            HStack(spacing: 3) {
                                Image(systemName: "pill.fill")
                                    .font(.system(size: 9))
                                Text(item.title)
                                    .font(.system(size: 11, design: .rounded))
                            }
                            .foregroundStyle(OrchardColors.leafGreen)
                        }
                    }
                }

                // Macros & Calories for any item with calories or protein
                if effectiveMacros.kcal > 0 || effectiveMacros.protein > 0 {
                    HStack(spacing: 8) {
                        if effectiveMacros.kcal > 0 {
                            Text("\(Int(effectiveMacros.kcal)) kcal")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(isDone ? .secondary : OrchardColors.appleRed)
                        }
                        if effectiveMacros.protein > 0 {
                            Text("•  \(Int(effectiveMacros.protein))g P")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        if effectiveMacros.carbs > 0 {
                            Text("•  \(Int(effectiveMacros.carbs))g C")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Action Row
                HStack {
                    if let options = event.item.options, !options.isEmpty, !isDone {
                        Button {
                            Haptics.selection()
                            selectedEventForOptions = event
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet.rectangle")
                                Text("Μενού (\(options.count))")
                            }
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.purple.opacity(0.12))
                            .foregroundStyle(Color.purple)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if isDone {
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                Text(isSupplement ? "Πήρες ✅" : "Έφαγες ✅")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(OrchardColors.leafGreen)

                            Button {
                                Haptics.selection()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    container.undoLog(itemId: event.itemId)
                                }
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .padding(6)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    } else if isSupplement {
                        Button {
                            Haptics.success()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                container.logSupplement(event: event)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Πήρα ✅")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.indigo)
                            .foregroundStyle(Color.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            Haptics.success()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                container.logMeal(event: event)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Έφαγα ✅")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(OrchardColors.appleRed)
                            .foregroundStyle(Color.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isOverdue ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers
    private func macroChip(label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.10))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formattedTimeRemaining(to targetDate: Date) -> String {
        let diff = targetDate.timeIntervalSince(Date())
        let absDiff = abs(diff)
        let hours = Int(absDiff / 3600)
        let minutes = Int((absDiff.truncatingRemainder(dividingBy: 3600)) / 60)

        if diff < 0 {
            if hours > 0 {
                return "πριν \(hours)ω \(minutes)λ"
            } else {
                return "πριν \(minutes)λ"
            }
        } else {
            if hours > 0 {
                return "σε \(hours)ω \(minutes)λ"
            } else {
                return "σε \(minutes)λ"
            }
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(AppContainer.shared)
}
