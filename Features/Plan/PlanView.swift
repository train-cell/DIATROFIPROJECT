import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif

/// Comprehensive 7-Day Cyclical Diet & Workout Plan Explorer.
public struct PlanView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var selectedDayKey: String = "day_1"
    @State private var showImportSheet: Bool = false

    private let dayKeys: [(key: String, label: String, name: String)] = [
        ("day_1", "Ημέρα 1", "Δευτέρα"),
        ("day_2", "Ημέρα 2", "Τρίτη"),
        ("day_3", "Ημέρα 3", "Τετάρτη"),
        ("day_4", "Ημέρα 4", "Πέμπτη"),
        ("day_5", "Ημέρα 5", "Παρασκευή"),
        ("day_6", "Ημέρα 6", "Σάββατο"),
        ("day_7", "Ημέρα 7", "Κυριακή")
    ]

    public init() {}

    private var currentTemplate: DayTemplate? {
        container.plan.templates[selectedDayKey]
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
                    // 1. Day Selector Carousel / Chips
                    dayPickerCarousel

                    // 2. Daily Totals Summary Banner
                    dayMacroTotalsBanner

                    // 3. Training Session Card (if any)
                    if let workout = currentTemplate?.trainingSessions.first {
                        workoutCard(workout: workout)
                    }

                    // 4. Scheduled Meals List
                    mealsListSection

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
        }
    }

    // MARK: - 1. Day Picker Carousel
    private var dayPickerCarousel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ΚΥΚΛΙΚΟ ΠΡΟΓΡΑΜΜΑ 7 ΗΜΕΡΩΝ")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.0)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dayKeys, id: \.key) { day in
                        let isSelected = selectedDayKey == day.key
                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedDayKey = day.key
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(day.label)
                                    .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? Color.white : OrchardColors.text)

                                Text(day.name)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : .secondary)
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

    // MARK: - 3. Workout Card
    private func workoutCard(workout: TrainingSession) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(OrchardColors.appleRed.opacity(0.15))
                    .frame(width: 42, height: 42)

                Image(systemName: "figure.run")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(OrchardColors.appleRed)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Προπόνηση: \(workout.start ?? "17:30")")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)

                Text("Διάρκεια: \(workout.durationMinutes)' • Εκτίμηση: \(Int(workout.estKcal ?? 600)) kcal")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Έντονη")
                .font(.system(size: 11, weight: .bold, design: .rounded))
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

    // MARK: - 4. Scheduled Meals List
    private var mealsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ΠΡΟΓΡΑΜΜΑΤΙΣΜΕΝΑ ΓΕΥΜΑΤΑ")
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
                        mealItemCard(item: item)
                    }
                }
            } else {
                Text("Δεν υπάρχουν καταχωρημένα γεύματα για αυτή την ημέρα.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 14)
            }
        }
    }

    private func mealItemCard(item: PlanItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(timingDescription(for: item.anchor, fallback: item.fallbackTime))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let kcal = item.kcal {
                    Text("\(Int(kcal)) kcal")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.appleRed)
                }
            }

            // Macros Row
            HStack(spacing: 8) {
                if let p = item.protein {
                    macroBadge(label: "\(Int(p))g P", color: .blue)
                }
                if let c = item.carbs {
                    macroBadge(label: "\(Int(c))g C", color: .orange)
                }
                if let f = item.fat {
                    macroBadge(label: "\(Int(f))g F", color: .purple)
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

    private func timingDescription(for anchor: Anchor, fallback: String?) -> String {
        switch anchor {
        case .absolute(let time):
            return "Ώρα: \(time)"
        case .afterWake(let minutes):
            return "\(minutes)' μετά το ξύπνημα"
        case .beforeSleep(let minutes):
            return "\(minutes)' πριν τον ύπνο"
        case .beforeTraining(let minutes):
            return "\(minutes)' πριν την προπόνηση"
        case .afterTraining(let minutes):
            return "\(minutes)' μετά την προπόνηση"
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
