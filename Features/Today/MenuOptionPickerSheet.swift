import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif

/// Clean native SwiftUI Sheet allowing athletes to select modular meal choices (e.g., Tuppers, Sandwiches, Breakfasts).
public struct MenuOptionPickerSheet: View {
    public let event: ScheduledEvent
    @ObservedObject public var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    public init(event: ScheduledEvent, container: AppContainer) {
        self.event = event
        self.container = container
    }

    private var options: [PlanOption] {
        event.item.options ?? []
    }

    private var currentSelectedOptionId: String? {
        container.selectedOption(for: event.item)?.id
    }

    /// Preserves distinct categories in original order
    private var categorizedOptions: [(category: String, options: [PlanOption])] {
        var categoryMap: [String: [PlanOption]] = [:]
        var categoryOrder: [String] = []

        for opt in options {
            let cat = opt.category ?? "Επιλογές"
            if categoryMap[cat] == nil {
                categoryMap[cat] = []
                categoryOrder.append(cat)
            }
            categoryMap[cat]?.append(opt)
        }

        return categoryOrder.compactMap { cat in
            guard let list = categoryMap[cat] else { return nil }
            return (category: cat, options: list)
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Banner
                    headerBanner

                    if options.isEmpty {
                        emptyState
                    } else {
                        // Options by Category
                        ForEach(categorizedOptions, id: \.category) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.category.uppercased())
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.8)
                                    .padding(.horizontal, 4)

                                VStack(spacing: 10) {
                                    ForEach(section.options) { option in
                                        optionRow(option: option)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .background(OrchardColors.background.ignoresSafeArea())
            .navigationTitle("Επιλογή Μενού")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Κλείσιμο") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(OrchardColors.appleRed)
                }
            }
        }
    }

    // MARK: - Header Banner
    private var headerBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "list.bullet.rectangle.portrait.fill")
                .font(.system(size: 22))
                .foregroundStyle(OrchardColors.appleRed)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.item.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)

                Text("Επίλεξε μία από τις \(options.count) εναλλακτικές επιλογές. Τα μακροθρεπτικά και οι θερμίδες υπολογίζονται αυτόματα.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrchardColors.appleRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Δεν υπάρχουν εναλλακτικές επιλογές για αυτό το γεύμα.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Option Row Card
    private func optionRow(option: PlanOption) -> some View {
        let isSelected = currentSelectedOptionId == option.id

        return VStack(alignment: .leading, spacing: 10) {
            // Top: Selection Indicator & Title
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? OrchardColors.leafGreen : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(OrchardColors.leafGreen)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.system(size: 14, weight: isSelected ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(OrchardColors.text)
                        .fixedSize(horizontal: false, vertical: true)

                    if let details = option.details, !details.isEmpty {
                        Text(details)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }

            // Macros & Estimated Badge
            HStack(spacing: 8) {
                if let kcal = option.kcal {
                    Text("\(Int(kcal)) kcal")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.appleRed)
                }
                if let p = option.protein {
                    Text("•  \(Int(p))g P")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                if let c = option.carbs {
                    Text("•  \(Int(c))g C")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                if let f = option.fat {
                    Text("•  \(Int(f))g F")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if option.isEstimatedMacros {
                    Text("~εκτίμηση")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
            }

            Divider()
                .padding(.vertical, 2)

            // Action Buttons Row
            HStack(spacing: 10) {
                // 1-Tap Select Only
                Button {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        container.selectOption(option, for: event.item)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isSelected ? "checkmark" : "hand.tap")
                        Text(isSelected ? "Επιλεγμένο" : "Επιλογή")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(isSelected ? OrchardColors.leafGreen.opacity(0.15) : Color.secondary.opacity(0.10))
                    .foregroundStyle(isSelected ? OrchardColors.leafGreen : OrchardColors.text)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                // Select & Log Meal
                Button {
                    Haptics.success()
                    container.selectOption(option, for: event.item)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        container.logMeal(event: event, selectedOption: option)
                    }
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Επιλογή & Καταγραφή")
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(OrchardColors.appleRed)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? OrchardColors.leafGreen.opacity(0.6) : Color.secondary.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                container.selectOption(option, for: event.item)
            }
        }
    }
}
