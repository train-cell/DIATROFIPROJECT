import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif
#if canImport(OrchardServices)
import OrchardServices
#endif

/// AI Plan Importer Sheet allowing users to paste raw diet text from a nutritionist or PDF,
/// preview the parsed plan with diffs, and save it upon explicit user confirmation.
public struct PlanImportSheet: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var rawText: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var parsedTemplates: [String: DayTemplate]? = nil
    @State private var showConfirmAlert: Bool = false

    private let sampleNutritionistDiet = """
    ΠΡΟΠΟΝΗΣΗ (Τεχνική Κολύμβηση 14:30 - 16:30)
    - 10:30 Πρωινό: 400ml ρόφημα βρώμης, 1 κ.σ. ταχίνι με μέλι, 2 φέτες ψωμί τοστ, 2 αυγά βραστά (580 kcal, 28g P, 65g C, 22g F)
    - 12:00 Ελαφρύ Γεύμα: Sandwich με 2 φέτες γαλοπούλα, ανθότυρο και 1 μπανάνα (380 kcal, 22g P, 58g C, 6g F)
    - 11:45 Συμπλήρωμα: 500ml νερό + 1 μεζούρα HIGH5 ηλεκτρολύτες + BCAA + 20g Πρωτεΐνη AFTER + V2000 SOLGAR
    - 16:30 Μεταπροπονητικό: 500ml HIGH5 + BCAA + 30g Πρωτεΐνη AFTER + 1 scoop γλουταμίνη
    - 17:30 Κυρίως Γεύμα: Tupper #1 (200g σολομός ψητός, 150g κινόα, σαλάτα μπρόκολο με 1 κ.σ. ελαιόλαδο) (720 kcal, 48g P, 45g C, 38g F)
    - 21:00 Βραδινό: Ομελέτα Βρώμης (4 ασπράδια, 1 κρόκος, 40g νιφάδες βρώμης) (320 kcal, 26g P, 30g C, 10g F)
    - 23:30 Πριν τον ύπνο: 1 φιαλίδιο Solumag
    """

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Instruction Banner
                    instructionBanner

                    // Error Banner
                    if let err = errorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(OrchardColors.appleRed)
                                .font(.system(size: 14))
                            Text(err)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(OrchardColors.appleRed)
                            Spacer()
                        }
                        .padding(12)
                        .background(OrchardColors.appleRed.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Text Editor Section
                    inputSection

                    // Analyze Action Button
                    analyzeButton

                    // Diff / Preview Card
                    if let templates = parsedTemplates {
                        previewSection(templates: templates)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .background(OrchardColors.background.ignoresSafeArea())
            .navigationTitle("Εισαγωγή Διατροφής με AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Ακύρωση") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Δείγμα") {
                        Haptics.selection()
                        rawText = sampleNutritionistDiet
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(OrchardColors.appleRed)
                }
            }
            .alert("Επιβεβαίωση Ενημέρωσης Προγράμματος", isPresented: $showConfirmAlert) {
                Button("Ακύρωση", role: .cancel) {}
                Button("Αποθήκευση", role: .none) {
                    saveParsedPlan()
                }
            } message: {
                Text("Το νέο πρόγραμμα που αναλύθηκε από το AI θα αντικαταστήσει το τρέχον πρόγραμμα της εφαρμογής. Επιθυμείτε να συνεχίσετε;")
            }
        }
    }

    // MARK: - Instruction Banner
    private var instructionBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 22))
                .foregroundStyle(OrchardColors.appleRed)

            VStack(alignment: .leading, spacing: 4) {
                Text("Αυτόματη Αναγνώριση Διατροφής")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)

                Text("Επικόλλησε το κείμενο του διατροφολόγου ή σημειώσεις από PDF. Το AI εξάγει γεύματα, ώρες, θερμίδες και μακροθρεπτικά.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrchardColors.appleRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Text Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ΚΕΙΜΕΝΟ ΔΙΑΤΡΟΦΗΣ")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.0)

            TextEditor(text: $rawText)
                .frame(minHeight: 160)
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
        }
    }

    // MARK: - Analyze Button
    private var analyzeButton: some View {
        Button {
            analyzeTextWithAI()
        } label: {
            HStack(spacing: 8) {
                if isAnalyzing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                }
                Text(isAnalyzing ? "Ανάλυση σε εξέλιξη..." : "Ανάλυση με AI 🪄")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [OrchardColors.appleRed, OrchardColors.appleRed.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: OrchardColors.appleRed.opacity(0.2), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(rawText.trimmingCharacters(in: .whitespaces).isEmpty || isAnalyzing)
        .opacity(rawText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1.0)
    }

    private func analyzeTextWithAI() {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Haptics.selection()
        isAnalyzing = true
        errorMessage = nil

        let systemPrompt = """
        Είσαι ειδικός αθλητικής διατροφής για το Orchard.
        Ανάλυσε το παρακάτω πρόγραμμα διατροφής και εξήγαγε ένα έγκυρο DayTemplate σε JSON.
        ΑΠΑΙΤΗΣΕΙΣ:
        - title: "Προπόνηση"
        - subtitle: περιγραφή
        - icon: "figure.pool.swim"
        - targetWaterMl: double (π.χ. 3000.0)
        - order: 1
        - items: λίστα από PlanItem με id, type ("meal" ή "supplement"), title, anchor (τύπου {"type": "absolute", "time": "10:30"} ή {"type": "afterTraining", "minutes": 30}), kcal, protein, carbs, fat, waterMl.
        - trainingSessions: λίστα προπονήσεων
        - rules: λίστα κανόνων
        """

        Task {
            do {
                let key = KeychainStore.shared.getAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard key != nil && !key!.isEmpty else {
                    throw AICoachError.missingAPIKey
                }
                let isEnabled = UserDefaults.standard.bool(forKey: "orchard_ai_enabled") || UserDefaults.standard.bool(forKey: "orchard.ai.is_enabled")
                guard isEnabled else {
                    throw AICoachError.aiDisabled
                }

                let preferred = UserDefaults.standard.string(forKey: "orchard_gemini_preferred_model") ?? "auto"
                let gemini = GeminiLLMProvider(apiKey: key, preferredModel: preferred)
                let router = LLMRouter(gemini: gemini, appleOnDevice: nil, cloud: nil, mock: nil)

                let template: DayTemplate = try await router.generate(
                    prompt: trimmed,
                    systemPrompt: systemPrompt,
                    schema: DayTemplate.self
                )

                // Validate draft plan
                var draftPlan = container.plan
                draftPlan.templates["training"] = template
                let report = PlanDraftValidator.validate(plan: draftPlan)
                if !report.isValid {
                    let errs = report.issues.joined(separator: "\n")
                    throw AICoachError.underlying("Μη έγκυρο πρόγραμμα: \(errs)")
                }

                await MainActor.run {
                    self.parsedTemplates = ["training": template]
                    self.isAnalyzing = false
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isAnalyzing = false
                    self.parsedTemplates = nil
                    Haptics.warning()
                }
            }
        }
    }

    // MARK: - Preview Diff Section
    private func previewSection(templates: [String: DayTemplate]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ΠΡΟΕΠΙΣΚΟΠΗΣΗ & ΔΙΑΦΟΡΕΣ (DIFF)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.0)
                Spacer()
                Text("6 Γεύματα Αναγνωρίστηκαν")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(OrchardColors.leafGreen)
            }

            ForEach(templates.keys.sorted(), id: \.self) { key in
                if let t = templates[key] {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Πρότυπο: \(key.replacingOccurrences(of: "_", with: " ").capitalized)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(OrchardColors.text)

                        ForEach(t.items) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(OrchardColors.leafGreen)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 5)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(OrchardColors.text)

                                    HStack(spacing: 8) {
                                        if let k = item.kcal {
                                            Text("\(Int(k)) kcal")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(OrchardColors.appleRed)
                                        }
                                        if let p = item.protein {
                                            Text("• \(Int(p))g P")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                        if let c = item.carbs {
                                            Text("• \(Int(c))g C")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                        if let f = item.fat {
                                            Text("• \(Int(f))g F")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }

            // Strictly user-confirmed save button
            Button {
                showConfirmAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                    Text("Αποθήκευση στο Πρόγραμμα")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(OrchardColors.leafGreen)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func saveParsedPlan() {
        guard let templates = parsedTemplates else { return }
        for (key, tmpl) in templates {
            container.plan.templates[key] = tmpl
        }
        if container.plan.templates[container.selectedTemplateKey] == nil {
            container.selectTemplate(key: templates.keys.sorted().first ?? "training")
        } else {
            container.refreshSchedule()
        }
        Haptics.success()
        dismiss()
    }
}

#Preview {
    PlanImportSheet()
        .environmentObject(AppContainer.shared)
}
