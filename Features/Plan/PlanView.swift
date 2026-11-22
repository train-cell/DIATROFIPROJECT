import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif

extension Weekday {
    fileprivate var shortGreekName: String {
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

/// Dynamic Day Mode & Cyclic Diet Plan Explorer.
public struct PlanView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var selectedDayKey: String = ""
    @State private var showImportSheet: Bool = false
    @State private var expandedItemIds: Set<String> = []

    public init() {}

    private var sortedTemplates: [(key: String, template: DayTemplate)] {
        container.plan.templates.map { ($0.key, $0.value) }
            .sorted { ($0.template.order ?? 999, $0.key) < ($1.template.order ?? 999, $1.key) }
    }

    private var activeKey: String {
        if !selectedDayKey.isEmpty && container.plan.templates[selectedDayKey] != nil {
            return selectedDayKey
        }
        return container.selectedTemplateKey
    }

    private var currentTemplate: DayTemplate? {
        container.plan.templates[activeKey] ?? sortedTemplates.first?.template
    }

    private var totalDayKcal: Double {
        currentTemplate?.items.reduce(0.0) { $0 + ($1.kcal ?? 0.0) } ?? 0.0
    }

    private var totalDayProtein: Double {
        currentTemplate?.items.reduce(0.0) { $0 + ($1.protein ?? 0.0) } ?? 0.0
    }

    private var totalDayCarbs: Double {
        currentTemplate?.items.reduce(0.0) { $0 + ($1.carbs ?? 0.0) } ?? 0.0
    }

    private var totalDayFat: Double {
        currentTemplate?.items.reduce(0.0) { $0 + ($1.fat ?? 0.0) } ?? 0.0
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Dynamic Day Selector Carousel
                    dayPickerCarousel

                    // 2. Daily Totals Summary Banner
                    dayMacroTotalsBanner

                    // 3. Training Sessions (All sessions, 1 or 2)
                    if let sessions = currentTemplate?.trainingSessions, !sessions.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(sessions.indices, id: \.self) { idx in
                                workoutCard(workout: sessions[idx], index: idx + 1, total: sessions.count)
                            }
                        }
                    }

                    // 4. Scheduled Meals & Supplements List
                    itemsListSection

                    // 5. Day Rules (Avoid / Prefer)
                    if let rules = currentTemplate?.rules, !rules.isEmpty {
                        rulesSection(rules: rules)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(OrchardColors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "tab_plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.selection()
                        showImportSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                            Text("AI Εισαγωγή")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(OrchardColors.appleRed)
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                PlanImportSheet()
            }
            .onAppear {
                if selectedDayKey.isEmpty {
                    selectedDayKey = container.selectedTemplateKey
                }
            }
        }
    }

    // MARK: - 1. Dynamic Day Picker Carousel
    private var dayPickerCarousel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ΠΡΟΓΡΑΜΜΑΤΑ ΗΜΕΡΑΣ (TEMPLATES)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.0)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sortedTemplates, id: \.key) { item in
                        let key = item.key
                        let template = item.template
                        let isSelected = activeKey == key
                        let title = template.title ?? key
                        let subtitle = template.subtitle ?? ""
                        let iconName = template.icon ?? (template.trainingSessions.isEmpty ? "bed.double.fill" : "figure.pool.swim")

                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedDayKey = key
                            }
                        } label: {
                            VStack(spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: iconName)
                                        .font(.system(size: 11))
                                    Text(title)
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                }
                                .foregroundStyle(isSelected ? Color.white : OrchardColors.text)

                                if !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(.system(size: 9.5, design: .rounded))
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
            }
        }
    }

    // MARK: - 2. Daily Totals Summary Banner
    private var dayMacroTotalsBanner: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ΣΥΝΟΛΙΚΟΣ ΣΤΟΧΟΣ ΗΜΕΡΑΣ")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)

                    Text("\(Int(totalDayKcal)) kcal")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.appleRed)
                }

                Spacer()

                HStack(spacing: 8) {
                    macroSummaryPill(title: "Πρωτεΐνη", value: "\(Int(totalDayProtein))g", color: .blue)
                    macroSummaryPill(title: "Υδατάνθρακες", value: "\(Int(totalDayCarbs))g", color: .orange)
                    macroSummaryPill(title: "Λιπαρά", value: "\(Int(totalDayFat))g", color: .purple)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func macroSummaryPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - 3. Workout Card (Swim & Multi-session aware)
    private func workoutCard(workout: TrainingSession, index: Int, total: Int) -> some View {
        let label = total > 1 ? "Προπόνηση #\(index): \(workout.start ?? "14:30")" : "Προπόνηση: \(workout.start ?? "14:30")"

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(OrchardColors.appleRed.opacity(0.15))
                    .frame(width: 42, height: 42)

                Image(systemName: "figure.pool.swim")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(OrchardColors.appleRed)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)

                Text("Διάρκεια: \(workout.durationMinutes)' • Εκτίμηση: \(Int(workout.estKcal ?? 600)) kcal")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Τεχνική Κολύμβηση")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(OrchardColors.appleRed.opacity(0.12))
                .foregroundStyle(OrchardColors.appleRed)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 4. Scheduled Meals & Supplements List
    private var itemsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ΠΡΟΓΡΑΜΜΑΤΙΣΜΕΝΑ ΣΤΟΙΧΕΙΑ")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.0)

                Spacer()

                Text("\(currentTemplate?.items.count ?? 0) στοιχεία")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let items = currentTemplate?.items, !items.isEmpty {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        planItemCard(item: item)
                    }
                }
            } else {
                Text("Δεν υπάρχουν καταχωρημένα στοιχεία για αυτή την ημέρα.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 14)
            }
        }
    }

    private func planItemCard(item: PlanItem) -> some View {
        let isSupplement = item.type == .supplement
        let isExpanded = expandedItemIds.contains(item.id)
        let hasOptions = (item.options?.count ?? 0) > 0

        return VStack(alignment: .leading, spacing: 8) {
            // Header Row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if isSupplement {
                            Image(systemName: "pill.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.indigo)
                        }
                        Text(item.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(OrchardColors.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(timingDescription(for: item.anchor, fallback: item.fallbackTime))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let kcal = item.kcal, kcal > 0 {
                    Text("\(Int(kcal)) kcal")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.appleRed)
                }
            }

            // Badges Row
            HStack(spacing: 6) {
                if item.isOptional == true {
                    Text("Προαιρετικό")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }

                if let water = item.waterMl, water > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9))
                        Text("+\(Int(water))ml")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.15))
                    .foregroundStyle(Color.cyan)
                    .clipShape(Capsule())
                }

                if let weekdays = item.activeWeekdays, !weekdays.isEmpty {
                    Text("ΜΟΝΟ " + weekdays.map(\.shortGreekName).joined(separator: " & "))
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }

                Spacer()
            }

            // Macros Row
            if !isSupplement && (item.protein != nil || item.carbs != nil || item.fat != nil) {
                HStack(spacing: 8) {
                    if let p = item.protein, p > 0 {
                        macroBadge(label: "\(Int(p))g P", color: .blue)
                    }
                    if let c = item.carbs, c > 0 {
                        macroBadge(label: "\(Int(c))g C", color: .orange)
                    }
                    if let f = item.fat, f > 0 {
                        macroBadge(label: "\(Int(f))g F", color: .purple)
                    }
                }
            }

            // Expandable Options List (if any)
            if hasOptions, let options = item.options {
                Divider()
                    .padding(.top, 2)

                Button {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        if isExpanded {
                            expandedItemIds.remove(item.id)
                        } else {
                            expandedItemIds.insert(item.id)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(options.count) Εναλλακτικές Επιλογές Μενού")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Spacer()
                        Text(isExpanded ? "Απόκρυψη" : "Προβολή")
                            .font(.system(size: 11, design: .rounded))
                    }
                    .foregroundStyle(Color.purple)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(options) { opt in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(opt.title)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(OrchardColors.text)
                                    Spacer()
                                    if let kcal = opt.kcal {
                                        Text("\(Int(kcal)) kcal")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundStyle(OrchardColors.appleRed)
                                    }
                                }

                                if let details = opt.details, !details.isEmpty {
                                    Text(details)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 6) {
                                    if let p = opt.protein { Text("P: \(Int(p))g").font(.system(size: 10)).foregroundStyle(.blue) }
                                    if let c = opt.carbs { Text("C: \(Int(c))g").font(.system(size: 10)).foregroundStyle(.orange) }
                                    if let f = opt.fat { Text("F: \(Int(f))g").font(.system(size: 10)).foregroundStyle(.purple) }
                                    if opt.isEstimatedMacros {
                                        Text("• ~εκτίμηση")
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func macroBadge(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func timingDescription(for anchor: OrchardDomain.Anchor, fallback: String?) -> String {
        switch anchor {
        case .absolute(let time):
            return "Ώρα: \(time)"
        case .afterWake(let minutes):
            return minutes == 0 ? "Με το ξύπνημα" : "\(minutes)' μετά το ξύπνημα"
        case .beforeSleep(let minutes):
            return "\(minutes)' πριν τον ύπνο"
        case .beforeTraining(let minutes):
            return "\(minutes)' πριν την προπόνηση"
        case .afterTraining(let minutes):
            return minutes == 0 ? "Αμέσως μετά την προπόνηση" : "\(minutes)' μετά την προπόνηση"
        case .withItem(let parentId):
            return "Μαζί με: \(parentId)"
        }
    }

    // MARK: - 5. Day Rules Section
    private func rulesSection(rules: [Rule]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ΟΔΗΓΙΕΣ & ΚΑΝΟΝΕΣ ΗΜΕΡΑΣ")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.0)

            VStack(spacing: 8) {
                ForEach(rules.indices, id: \.self) { idx in
                    let rule = rules[idx]
                    HStack(spacing: 8) {
                        Image(systemName: rule.type == .prefer ? "checkmark.seal.fill" : "exclamationmark.octagon.fill")
                            .foregroundStyle(rule.type == .prefer ? OrchardColors.leafGreen : Color.orange)

                        Text(rule.text)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(OrchardColors.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

#Preview {
    PlanView()
        .environmentObject(AppContainer.shared)
}
