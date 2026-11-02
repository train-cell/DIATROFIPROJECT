import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif

public struct TodayView: View {
    @EnvironmentObject private var container: AppContainer

    // List of day template chips: Ημέρα 1 to 7 + Ανάπαυση
    private let templateChips: [(id: String, label: String, summary: String)] = [
        ("day_1", "Ημέρα 1", "Κοτόπουλο & Αραβική"),
        ("day_2", "Ημέρα 2", "Φασολάκια & Κοτόπουλο"),
        ("day_3", "Ημέρα 3", "Ταχίνι & Γιουβέτσι"),
        ("day_4", "Ημέρα 4", "Φακές & Αυγά"),
        ("day_5", "Ημέρα 5", "Μακαρόνια με Κιμά"),
        ("day_6", "Ημέρα 6", "Ψάρι & Θαλασσινά"),
        ("day_7", "Ημέρα 7", "Porridge & Μπριζόλα"),
        ("rest", "Ανάπαυση", "Ημέρα Ξεκούρασης")
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    // 1. Morning Template Picker Chips
                    templatePickerSection

                    // 2. Hero Apple Progress View
                    heroAppleSection

                    // 3. "Now / Next" Hero Card
                    nowNextCardSection

                    // 4. Interactive Timeline of Today's Meals
                    timelineSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 36)
            }
            .background(OrchardColors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "tab_today"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.impact(.light)
                        container.refreshSchedule()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(OrchardColors.appleRed)
                    }
                }
            }
        }
    }

    // MARK: - 1. Morning Template Picker Section
    private var templatePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ΕΠΙΛΟΓΗ ΗΜΕΡΑΣ (ΕΩΣ 2 ΦΟΡΕΣ / 14 ΗΜΕΡΕΣ)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                Spacer()
            }
            .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(templateChips, id: \.id) { chip in
                        let isSelected = container.selectedTemplateKey == chip.id
                        let usage = container.usageCountInLast14Days(templateKey: chip.id)
                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                container.selectTemplate(key: chip.id)
                            }
                        } label: {
                            VStack(spacing: 3) {
                                HStack(spacing: 4) {
                                    Text(chip.label)
                                        .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(isSelected ? Color.white : OrchardColors.text)

                                    if chip.id != "rest" {
                                        Text("\(usage)/2")
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(isSelected ? Color.white.opacity(0.25) : (usage >= 2 ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.15)))
                                            .foregroundStyle(isSelected ? Color.white : (usage >= 2 ? Color.orange : .secondary))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(chip.summary)
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
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
                .padding(.vertical, 2)
                .padding(.horizontal, 2)
            }

            // Dedicated Active Day Confirmation Banner
            if let activeChip = templateChips.first(where: { $0.id == container.selectedTemplateKey }) {
                let usage = container.usageCountInLast14Days(templateKey: activeChip.id)
                let remaining = max(0, 2 - usage)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(OrchardColors.leafGreen)
                            .font(.system(size: 13))
                        Text("Ενεργό: Ακολουθείς **όλο το πρόγραμμα** της **\(activeChip.label)** (\(activeChip.summary)).")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(OrchardColors.text)
                        Spacer()
                    }
                    if activeChip.id != "rest" {
                        Text(remaining == 1 ? "ℹ️ Μπορείς να την επιλέξεις ακόμη 1 φορά στις επόμενες 14 ημέρες." : (remaining == 0 ? "⚠️ Συμπληρώθηκαν και οι 2 φορές των 14 ημερών για αυτή τη μέρα." : "ℹ️ Απομένουν 2 επιλογές στις επόμενες 14 ημέρες."))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 21)
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

    // MARK: - 3. "Now / Next" Hero Card
    private var nowNextCardSection: some View {
        let mealEvents = container.resolvedEvents.filter { $0.item.type == .meal }
        let pendingEvents = mealEvents.filter { event in
            !container.logEntries.contains { $0.itemId == event.itemId && $0.status == .done }
        }

        return Group {
            if let targetEvent = pendingEvents.first {
                nowNextCard(for: targetEvent)
            } else if !mealEvents.isEmpty {
                allMealsCompletedCard
            }
        }
    }

    private func nowNextCard(for event: ScheduledEvent) -> some View {
        let isOverdue = Date() > event.resolvedTime
        let timeRemainingString = formattedTimeRemaining(to: event.resolvedTime)

        return VStack(alignment: .leading, spacing: 14) {
            // Header: Status badge & time
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(isOverdue ? Color.orange : OrchardColors.appleRed)
                        .frame(width: 8, height: 8)

                    Text(isOverdue ? "ΤΩΡΑ / ΚΑΘΥΣΤΕΡΗΜΕΝΟ" : "ΕΠΟΜΕΝΟ ΓΕΥΜΑ")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isOverdue ? Color.orange : OrchardColors.appleRed)
                        .tracking(0.8)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    (isOverdue ? Color.orange : OrchardColors.appleRed).opacity(0.12)
                )
                .clipShape(Capsule())

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(timeRemainingString)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.secondary)
            }

            // Meal Title & Time
            VStack(alignment: .leading, spacing: 4) {
                Text(event.item.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Προγραμματισμένο στις \(formatTime(event.resolvedTime))")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Attached supplements
            if !event.attachedItems.isEmpty {
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

            // Nutrition Chips
            HStack(spacing: 8) {
                if let kcal = event.item.kcal {
                    macroChip(label: "\(Int(kcal)) kcal", icon: "flame.fill", color: OrchardColors.appleRed)
                }
                if let protein = event.item.protein {
                    macroChip(label: "\(Int(protein))g P", icon: "figure.strengthtraining.traditional", color: .blue)
                }
                if let carbs = event.item.carbs {
                    macroChip(label: "\(Int(carbs))g C", icon: "leaf.fill", color: .orange)
                }
                if let fat = event.item.fat {
                    macroChip(label: "\(Int(fat))g F", icon: "drop.fill", color: .purple)
                }
            }

            // 1-Tap "Έφαγα ✅" Button
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

            Text("Όλα τα γεύματα ολοκληρώθηκαν! 🍎")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(OrchardColors.text)

            Text("Έχεις καταγράψει όλα τα προγραμματισμένα γεύματα της ημέρας.")
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

    // MARK: - 4. Interactive Timeline Section
    private var timelineSection: some View {
        let mealEvents = container.resolvedEvents.filter { $0.item.type == .meal }

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ΧΡΟΝΟΔΙΑΓΡΑΜΜΑ ΓΕΥΜΑΤΩΝ")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.0)
                Spacer()
                Text("\(mealEvents.count) γεύματα")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)

            if mealEvents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Δεν υπάρχουν προγραμματισμένα γεύματα για σήμερα.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                VStack(spacing: 12) {
                    ForEach(mealEvents.indices, id: \.self) { idx in
                        let event = mealEvents[idx]
                        let isEaten = container.logEntries.contains { $0.itemId == event.itemId && $0.status == .done }
                        let isOverdue = !isEaten && Date() > event.resolvedTime

                        timelineRow(event: event, isEaten: isEaten, isOverdue: isOverdue)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func timelineRow(event: ScheduledEvent, isEaten: Bool, isOverdue: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Left time indicator & dot
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTime(event.resolvedTime))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isEaten ? .secondary : OrchardColors.text)

                Circle()
                    .fill(
                        isEaten ? OrchardColors.leafGreen : (isOverdue ? Color.orange : OrchardColors.appleRed)
                    )
                    .frame(width: 10, height: 10)
            }
            .frame(width: 52)
            .padding(.top, 4)

            // Meal Card
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(event.item.title)
                        .font(.system(size: 15, weight: isEaten ? .medium : .semibold, design: .rounded))
                        .foregroundStyle(isEaten ? .secondary : OrchardColors.text)
                        .strikethrough(isEaten, color: .secondary.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    if isOverdue {
                        Text("Καθυστερημένο")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                // Attached supplements
                if !event.attachedItems.isEmpty {
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

                // Macros & Calories
                HStack(spacing: 8) {
                    if let kcal = event.item.kcal {
                        Text("\(Int(kcal)) kcal")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(isEaten ? .secondary : OrchardColors.appleRed)
                    }
                    if let protein = event.item.protein {
                        Text("•  \(Int(protein))g P")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    if let carbs = event.item.carbs {
                        Text("•  \(Int(carbs))g C")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                // Action Row
                HStack {
                    Spacer()

                    if isEaten {
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                Text("Έφαγες ✅")
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
