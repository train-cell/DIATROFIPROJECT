import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif

public struct LogView: View {
    @EnvironmentObject private var container: AppContainer

    public enum LogCategory: String, CaseIterable, Identifiable {
        case meal = "Γεύμα"
        case supplement = "Συμπλήρωμα"
        case snack = "Σνακ"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .meal: return "fork.knife"
            case .supplement: return "pill.fill"
            case .snack: return "apple.logo"
            }
        }
    }

    @State private var category: LogCategory = .meal
    @State private var title: String = ""
    @State private var kcalString: String = ""
    @State private var proteinString: String = ""
    @State private var carbsString: String = ""
    @State private var fatString: String = ""
    @State private var notes: String = ""
    @State private var selectedEventId: String? = nil
    @State private var showSuccessBanner: Bool = false
    @State private var showAISheet: Bool = false

    public init() {}

    private var suggestions: [String] {
        switch category {
        case .meal:
            return ["Πρωινό", "Μεσημεριανό", "Βραδινό", "Κοτόπουλο & Ρύζι", "Ομελέτα"]
        case .supplement:
            return ["Κρεατίνη (5g)", "Πρωτεΐνη Whey (30g)", "Πολυβιταμίνη", "Ωμέγα 3", "Ηλεκτρολύτες", "Μαγνήσιο", "Βιταμίνη D3"]
        case .snack:
            return ["Μπανάνα", "Γιαούρτι 2% με μέλι", "Ξηροί καρποί (30g)", "Ρυζογκοφρέτες"]
        }
    }

    private func selectSuggestion(_ item: String) {
        title = item
        if category == .supplement {
            if item.contains("Πρωτεΐνη") || item.contains("Whey") {
                kcalString = "120"
                proteinString = "25"
                carbsString = "2"
                fatString = "1"
            } else if item.contains("Κρεατίνη") || item.contains("Ωμέγα") || item.contains("Βιταμίνη") || item.contains("Ηλεκτρολύτες") || item.contains("Μαγνήσιο") || item.contains("Πολυβιταμίνη") {
                kcalString = "0"
                proteinString = "0"
                carbsString = "0"
                fatString = "0"
            }
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Success Banner
                    if showSuccessBanner {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OrchardColors.leafGreen)
                            Text("Η καταγραφή αποθηκεύτηκε επιτυχώς!")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(OrchardColors.text)
                            Spacer()
                        }
                        .padding(12)
                        .background(OrchardColors.leafGreen.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // AI Quick Banner
                    Button {
                        Haptics.selection()
                        showAISheet = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(OrchardColors.appleRed.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(OrchardColors.appleRed)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Καταγραφή με AI 🪄")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(OrchardColors.text)
                                Text("Πληκτρολόγησε ελεύθερα για άμεση εκτίμηση")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(OrchardColors.appleRed.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    // 1. Category Selector
                    categorySelector

                    // 2. Title and Quick Suggestions
                    titleSection

                    // 3. Calories & Macros Section
                    nutritionSection

                    // 4. Link to Scheduled Meal (optional)
                    scheduledMealLinkSection

                    // 5. Notes
                    notesSection

                    // 6. Action Button
                    submitButton

                    // 7. Today's Logged Items
                    todayLoggedEntriesSection
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(OrchardColors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "tab_log"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.selection()
                        showAISheet = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "wand.and.stars")
                            Text("AI")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(OrchardColors.appleRed)
                    }
                }
            }
            .sheet(isPresented: $showAISheet) {
                AILogSheet()
            }
        }
    }

    // MARK: - 1. Category Selector
    private var categorySelector: some View {
        Picker("Κατηγορία", selection: $category) {
            ForEach(LogCategory.allCases) { cat in
                Label(cat.rawValue, systemImage: cat.icon).tag(cat)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: category) { _, _ in
            Haptics.selection()
        }
    }

    // MARK: - 2. Title & Suggestions
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ΠΕΡΙΓΡΑΦΗ")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.0)

            TextField("π.χ. Γιαούρτι με μέλι και καρύδια", text: $title)
                .font(.system(size: 16, design: .rounded))
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Quick suggestion chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { item in
                        Button {
                            Haptics.selection()
                            selectSuggestion(item)
                        } label: {
                            Text(item)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.secondary.opacity(0.12))
                                .foregroundStyle(OrchardColors.text)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 3. Calories & Macros Section
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ΘΕΡΜΙΔΕΣ & ΜΑΚΡΟΘΡΕΠΤΙΚΑ")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.0)

            // Calories Input & Quick Adders
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(OrchardColors.appleRed)
                        Text("Θερμίδες (kcal):")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(OrchardColors.text)
                    }

                    Spacer()

                    TextField("0", text: $kcalString)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.appleRed)
                        .frame(width: 90)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Quick Increment Pills
                HStack(spacing: 8) {
                    ForEach([50, 100, 200, 400], id: \.self) { amount in
                        Button {
                            Haptics.selection()
                            let current = Int(kcalString) ?? 0
                            kcalString = "\(current + amount)"
                        } label: {
                            Text("+\(amount)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(OrchardColors.appleRed.opacity(0.10))
                                .foregroundStyle(OrchardColors.appleRed)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Macros 3-Column Inputs
            HStack(spacing: 10) {
                macroInputField(
                    title: "Πρωτεΐνη",
                    unit: "g",
                    color: .blue,
                    text: $proteinString
                )

                macroInputField(
                    title: "Υδατάνθρακες",
                    unit: "g",
                    color: .orange,
                    text: $carbsString
                )

                macroInputField(
                    title: "Λιπαρά",
                    unit: "g",
                    color: .purple,
                    text: $fatString
                )
            }
        }
    }

    private func macroInputField(
        title: String,
        unit: String,
        color: Color,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(color)

            HStack(spacing: 2) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)
                Text(unit)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - 4. Scheduled Meal Link
    private var scheduledMealLinkSection: some View {
        let pendingMeals = container.resolvedEvents.filter { event in
            event.item.type == .meal && !container.logEntries.contains { $0.itemId == event.itemId && $0.status == .done }
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text("ΣΥΝΔΕΣΗ ΜΕ ΠΡΟΓΡΑΜΜΑ (ΠΡΟΑΙΡΕΤΙΚΟ)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.0)

            Menu {
                Button("Καμία σύνδεση (Εκτός προγράμματος)") {
                    selectedEventId = nil
                }
                ForEach(pendingMeals) { event in
                    Button(event.item.title) {
                        selectedEventId = event.id
                        if title.isEmpty {
                            title = event.item.title
                        }
                        if kcalString.isEmpty, let kcal = event.item.kcal {
                            kcalString = "\(Int(kcal))"
                        }
                        if proteinString.isEmpty, let p = event.item.protein {
                            proteinString = "\(Int(p))"
                        }
                        if carbsString.isEmpty, let c = event.item.carbs {
                            carbsString = "\(Int(c))"
                        }
                        if fatString.isEmpty, let f = event.item.fat {
                            fatString = "\(Int(f))"
                        }
                    }
                }
            } label: {
                HStack {
                    if let selectedId = selectedEventId,
                       let event = pendingMeals.first(where: { $0.id == selectedId }) {
                        Text(event.item.title)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(OrchardColors.text)
                    } else {
                        Text("Εκτός προγράμματος / Νέο")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - 5. Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ΣΗΜΕΙΩΣΕΙΣ")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.0)

            TextField("Προαιρετικές λεπτομέρειες...", text: $notes)
                .font(.system(size: 14, design: .rounded))
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - 6. Submit Button
    private var submitButton: some View {
        Button {
            submitLog()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("Καταγραφή ✅")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [OrchardColors.appleRed, OrchardColors.appleRed.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: OrchardColors.appleRed.opacity(0.25), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty && selectedEventId == nil)
        .opacity((title.trimmingCharacters(in: .whitespaces).isEmpty && selectedEventId == nil) ? 0.6 : 1.0)
    }

    private func submitLog() {
        Haptics.success()

        let kcal = Double(kcalString)
        let protein = Double(proteinString)
        let carbs = Double(carbsString)
        let fat = Double(fatString)

        if let selectedId = selectedEventId,
           let event = container.resolvedEvents.first(where: { $0.id == selectedId }) {
            container.logMeal(
                event: event,
                status: .done,
                kcal: kcal ?? event.item.kcal
            )
        } else {
            let finalTitle = title.trimmingCharacters(in: .whitespaces).isEmpty ? category.rawValue : title
            let itemType: PlanItemType = (category == .supplement) ? .supplement : .meal

            container.addManualLog(
                title: finalTitle,
                type: itemType,
                kcal: kcal,
                protein: protein,
                carbs: carbs,
                fat: fat,
                notes: notes.isEmpty ? nil : notes
            )
        }

        // Reset form
        title = ""
        kcalString = ""
        proteinString = ""
        carbsString = ""
        fatString = ""
        notes = ""
        selectedEventId = nil

        withAnimation {
            showSuccessBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showSuccessBanner = false
            }
        }
    }

    // MARK: - 7. Today's Logged Items Section
    private var todayLoggedEntriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ΣΗΜΕΡΙΝΕΣ ΚΑΤΑΓΡΑΦΕΣ")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.0)
                Spacer()
                Text("\(container.logEntries.count) καταχωρίσεις")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 10)

            if container.logEntries.isEmpty {
                Text("Δεν έχει καταγραφεί κανένα στοιχείο σήμερα.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(container.logEntries.reversed()) { entry in
                        loggedEntryRow(entry: entry)
                    }
                }
            }
        }
    }

    private func loggedEntryRow(entry: LogEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.note ?? entry.itemId)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)

                HStack(spacing: 6) {
                    if let kcal = entry.kcal {
                        Text("\(Int(kcal)) kcal")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(OrchardColors.appleRed)
                    }
                    if let p = entry.protein {
                        Text("• \(Int(p))g P")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    if let c = entry.carbs {
                        Text("• \(Int(c))g C")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    if let f = entry.fat {
                        Text("• \(Int(f))g F")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                Haptics.selection()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    container.deleteLogEntry(id: entry.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(8)
                    .background(Color.red.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    LogView()
        .environmentObject(AppContainer.shared)
}
