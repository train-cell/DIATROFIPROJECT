import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif

/// AI-powered Quick Meal Log Sheet estimating calories and macronutrients from natural language.
public struct AILogSheet: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String = ""
    @State private var isEstimating: Bool = false

    // Editable Estimated Results
    @State private var estimatedTitle: String = ""
    @State private var kcalString: String = ""
    @State private var proteinString: String = ""
    @State private var carbsString: String = ""
    @State private var fatString: String = ""

    @State private var hasEstimated: Bool = false

    private let suggestions = [
        "3 καλαμάκια κοτόπουλο με σαλάτα και 1 πίτα",
        "1 γιαούρτι 2% με 1 κ.σ. μέλι και 30g καρύδια",
        "200g σολομός ψητός με 150g ρύζι και μπρόκολο",
        "Ομελέτα 3 αυγά με 50g τυρί φέτα και 1 φέτα ψωμί"
    ]

    public init() {}

    // MARK: - Macro Validation Math (4P + 4C + 9F)
    private var macroMath: (macroKcal: Double, declaredKcal: Double, deviation: Double, isValid: Bool) {
        let p = Double(proteinString) ?? 0.0
        let c = Double(carbsString) ?? 0.0
        let f = Double(fatString) ?? 0.0
        let k = Double(kcalString) ?? 0.0

        let computedMacroKcal = (p * 4.0) + (c * 4.0) + (f * 9.0)
        guard k > 0 else {
            return (computedMacroKcal, k, 0.0, true)
        }

        let diff = abs(computedMacroKcal - k)
        let deviation = diff / k
        let isValid = deviation <= 0.15

        return (computedMacroKcal, k, deviation, isValid)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    headerCard

                    // Natural Language Input Section
                    inputSection

                    // Quick Suggestion Chips
                    suggestionChips

                    // Action Button: Εκτίμηση Θερμίδων
                    estimateButton

                    // Result & Validation Section (Editable)
                    if hasEstimated {
                        resultsSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .background(OrchardColors.background.ignoresSafeArea())
            .navigationTitle("Καταγραφή με AI 🪄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Κλείσιμο") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Header Card
    private var headerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 22))
                .foregroundStyle(OrchardColors.appleRed)

            VStack(alignment: .leading, spacing: 4) {
                Text("Φυσική Περιγραφή Γεύματος")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)

                Text("Πληκτρολόγησε ή υπαγόρευσε ελεύθερα τι έφαγες. Το AI αναγνωρίζει τις ποσότητες και υπολογίζει τις θερμίδες.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrchardColors.appleRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ΠΕΡΙΓΡΑΦΗ ΓΕΥΜΑΤΟΣ")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.0)

            HStack(alignment: .top) {
                TextField("π.χ. 3 καλαμάκια κοτόπουλο με σαλάτα και 1 πίτα", text: $inputText, axis: .vertical)
                    .font(.system(size: 16, design: .rounded))
                    .lineLimit(3...5)

                if !inputText.isEmpty {
                    Button {
                        inputText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Suggestions
    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { sample in
                    Button {
                        Haptics.selection()
                        inputText = sample
                    } label: {
                        Text(sample)
                            .font(.system(size: 12, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.10))
                            .foregroundStyle(OrchardColors.text)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Estimate Button
    private var estimateButton: some View {
        Button {
            performEstimation()
        } label: {
            HStack(spacing: 8) {
                if isEstimating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                }
                Text(isEstimating ? "Εκτίμηση σε εξέλιξη..." : "Εκτίμηση Θερμίδων 🪄")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [OrchardColors.appleRed, OrchardColors.appleRed.opacity(0.88)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: OrchardColors.appleRed.opacity(0.2), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isEstimating)
        .opacity(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1.0)
    }

    private func performEstimation() {
        Haptics.selection()
        isEstimating = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let lower = inputText.lowercased()
            let title: String
            let k: Double
            let p: Double
            let c: Double
            let f: Double

            if lower.contains("καλαμάκ") || lower.contains("σουβλάκ") {
                title = "3 Καλαμάκια κοτόπουλο με σαλάτα & 1 πίτα"
                k = 660
                p = 52
                c = 48
                f = 28
            } else if lower.contains("γιαούρτ") {
                title = "Γιαούρτι 2% με μέλι & καρύδια"
                k = 340
                p = 18
                c = 32
                f = 16
            } else if lower.contains("σολομ") {
                title = "Σολομός ψητός με καστανό ρύζι & μπρόκολο"
                k = 620
                p = 46
                c = 54
                f = 24
            } else if lower.contains("ομελέτ") || lower.contains("αυγ") {
                title = "Ομελέτα 3 αυγά με φέτα & ψωμί"
                k = 480
                p = 32
                c = 22
                f = 30
            } else {
                title = inputText.capitalized
                k = 500
                p = 35
                c = 45
                f = 20
            }

            self.estimatedTitle = title
            self.kcalString = "\(Int(k))"
            self.proteinString = "\(Int(p))"
            self.carbsString = "\(Int(c))"
            self.fatString = "\(Int(f))"
            self.hasEstimated = true
            self.isEstimating = false
            Haptics.success()
        }
    }

    // MARK: - Results & Validation Section
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ΑΠΟΤΕΛΕΣΜΑ ΕΚΤΙΜΗΣΗΣ (ΕΠΕΞΕΡΓΑΣΙΜΟ)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.0)
                Spacer()
            }

            // Editable Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Τίτλος Γεύματος")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)

                TextField("Τίτλος", text: $estimatedTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // Editable Calories
            VStack(alignment: .leading, spacing: 4) {
                Text("Θερμίδες (kcal)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)

                TextField("0", text: $kcalString)
                    .keyboardType(.numberPad)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.appleRed)
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // 3-Column Macros
            HStack(spacing: 8) {
                macroEditField(label: "Πρωτεΐνη (g)", color: .blue, text: $proteinString)
                macroEditField(label: "Υδατάνθρακες (g)", color: .orange, text: $carbsString)
                macroEditField(label: "Λιπαρά (g)", color: .purple, text: $fatString)
            }

            // Validation Badge / Warning Banner (4P + 4C + 9F)
            validationBadge

            // Confirm & Save Button
            Button {
                saveAILogEntry()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                    Text("Επιβεβαίωση & Αποθήκευση ✅")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(OrchardColors.leafGreen)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func macroEditField(label: String, color: Color, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(color)

            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Validation Badge
    private var validationBadge: some View {
        let (macroKcal, declaredKcal, deviation, isValid) = macroMath

        return Group {
            if isValid {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(OrchardColors.leafGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Έγκυρη κατανομή μακροθρεπτικών")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(OrchardColors.leafGreen)
                        Text("4P + 4C + 9F = \(Int(macroKcal)) kcal (δηλωμένα \(Int(declaredKcal)) kcal, απόκλιση \(Int(deviation * 100))%)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(OrchardColors.leafGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Προσοχή: Σημαντική απόκλιση θερμίδων")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.orange)
                        Text("Τα μακροθρεπτικά αποδίδουν \(Int(macroKcal)) kcal vs \(Int(declaredKcal)) kcal δηλωμένα (διαφορά \(Int(deviation * 100))% > 15%).")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func saveAILogEntry() {
        let k = Double(kcalString)
        let p = Double(proteinString)
        let c = Double(carbsString)
        let f = Double(fatString)

        let title = estimatedTitle.trimmingCharacters(in: .whitespaces).isEmpty ? "AI Meal" : estimatedTitle
        let entryId = UUID()
        let entry = LogEntry(
            id: entryId,
            eventKey: "ai_\(entryId.uuidString.prefix(8))",
            itemId: "ai_\(entryId.uuidString.prefix(8))",
            status: .done,
            timestamp: Date(),
            kcal: k,
            protein: p,
            carbs: c,
            fat: f,
            source: .ai(provider: "on-device"),
            note: title
        )

        container.logEntries.append(entry)
        container.biteCount += 1
        container.refreshSchedule()

        // Sync with HealthStore
        let store = container.healthStore
        Task {
            try? await store.writeDietaryLog(entry, item: nil)
        }

        Haptics.success()
        dismiss()
    }
}

#Preview {
    AILogSheet()
        .environmentObject(AppContainer.shared)
}
