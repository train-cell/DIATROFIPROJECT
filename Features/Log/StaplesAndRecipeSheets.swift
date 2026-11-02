import SwiftUI
#if canImport(OrchardDomain)
import OrchardDomain
#endif

// MARK: - 1. Staples & Barcode Lookup Sheet
public struct StaplesLookupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery: String = ""
    @State private var selectedGrams: Double = 150.0
    @State private var barcodeInput: String = ""
    @State private var scannedMessage: String? = nil

    public var onSelect: (String, Double, Double, Double, Double) -> Void

    public init(onSelect: @escaping (String, Double, Double, Double, Double) -> Void) {
        self.onSelect = onSelect
    }

    private var filteredItems: [StapleFoodItem] {
        StapleFoodLibrary.search(query: searchQuery)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Barcode Simulator Banner
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BARCODE SCANNER (ΠΡΟΣΟΜΟΙΩΣΗ)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)

                        HStack {
                            TextField("Εισάγετε EAN / Barcode...", text: $barcodeInput)
                                .font(.system(size: 13, design: .rounded))
                                .textFieldStyle(.plain)
                                .keyboardType(.numberPad)

                            Button {
                                Haptics.selection()
                                if let found = StapleFoodLibrary.lookup(barcode: barcodeInput) {
                                    scannedMessage = "Βρέθηκε: \(found.nameGreek)!"
                                    let m = found.macros(forGrams: selectedGrams)
                                    onSelect(found.nameGreek, m.kcal, m.p, m.c, m.f)
                                    dismiss()
                                } else {
                                    scannedMessage = "Δεν βρέθηκε προϊόν με αυτό το barcode."
                                }
                            } label: {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        if let msg = scannedMessage {
                            Text(msg)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Gram portion selector
                    HStack {
                        Text("Ποσότητα:")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(OrchardColors.text)
                        Spacer()
                        Text("\(Int(selectedGrams)) g")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.purple)
                    }
                    .padding(.horizontal, 4)

                    Slider(value: $selectedGrams, in: 20...500, step: 5)
                        .tint(.purple)

                    // Search field
                    TextField("Αναζήτηση καθαρών staples (π.χ. κοτόπουλο, βρώμη)...", text: $searchQuery)
                        .font(.system(size: 13, design: .rounded))
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // Items list
                    VStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            let m = item.macros(forGrams: selectedGrams)
                            Button {
                                Haptics.impact(.light)
                                onSelect(item.nameGreek, m.kcal, m.p, m.c, m.f)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.nameGreek)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(OrchardColors.text)
                                        Text("\(Int(m.kcal)) kcal • P: \(String(format: "%.1f", m.p))g • C: \(String(format: "%.1f", m.c))g • F: \(String(format: "%.1f", m.f))g")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(OrchardColors.appleRed)
                                }
                                .padding(12)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(OrchardColors.background.ignoresSafeArea())
            .navigationTitle("Αθλητικά Staples & Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Κλείσιμο") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 2. Custom Recipe Builder Sheet
public struct RecipeBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recipeTitle: String = "Power Proats (Βρώμη + Whey)"
    @State private var servings: Int = 1
    @State private var ingredients: [RecipeIngredient] = [
        RecipeIngredient.fromStaple(item: StapleFoodLibrary.lookup(barcode: "5201001000108")!, grams: 80.0), // Oats
        RecipeIngredient.fromStaple(item: StapleFoodLibrary.lookup(barcode: "5201001000104")!, grams: 35.0), // Whey
        RecipeIngredient.fromStaple(item: StapleFoodLibrary.lookup(barcode: "5201001000113")!, grams: 20.0)  // PB
    ]

    public var onSave: (CustomRecipe) -> Void

    public init(onSave: @escaping (CustomRecipe) -> Void) {
        self.onSave = onSave
    }

    private var currentRecipe: CustomRecipe {
        CustomRecipe(titleGreek: recipeTitle, servings: servings, ingredients: ingredients)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Recipe Name & Servings
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ΣΤΟΙΧΕΙΑ ΣΥΝΤΑΓΗΣ")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)

                        TextField("Όνομα Συνταγής", text: $recipeTitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .padding(10)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Stepper("Μερίδες: \(servings)", value: $servings, in: 1...8)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Aggregate Macro Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ΜΑΚΡΟΣΥΣΤΑΤΙΚΑ ΑΝΑ ΜΕΡΙΔΑ (1/\(servings))")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(Int(currentRecipe.perServingKcal)) kcal")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(OrchardColors.text)
                                Text("Θερμίδες")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("\(String(format: "%.1f", currentRecipe.perServingProtein))g")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.blue)
                                Text("Πρωτεΐνη")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("\(String(format: "%.1f", currentRecipe.perServingCarbs))g")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                                Text("Υδατ/κες")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(String(format: "%.1f", currentRecipe.perServingFats))g")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.purple)
                                Text("Λιπαρά")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Ingredients List
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ΣΥΣΤΑΤΙΚΑ ΜΕΡΙΔΑΣ (\(ingredients.count))")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)

                        ForEach(ingredients) { ing in
                            let g = Int(ing.grams)
                            let k = Int(ing.kcal)
                            let p = Int(ing.protein)
                            let c = Int(ing.carbs)
                            let f = Int(ing.fats)
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ing.nameGreek)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(OrchardColors.text)
                                    Text("\(g)g • \(k) kcal (P: \(p)g C: \(c)g F: \(f)g)")
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Submit Button
                    Button {
                        Haptics.success()
                        onSave(currentRecipe)
                        dismiss()
                    } label: {
                        Text("Αποθήκευση Συνταγής στο Πρόγραμμα")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(OrchardColors.appleRed)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(16)
            }
            .background(OrchardColors.background.ignoresSafeArea())
            .navigationTitle("Custom Recipe Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Κλείσιμο") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 3. Digestive Wellness Sheet
public struct DigestiveWellnessSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var satiety: SatietyScore = .pleasantlySatisfied
    @State private var energy: EnergyLevel = .steady
    @State private var selectedSymptoms: Set<DigestSymptom> = [.optimal]
    @State private var note: String = ""

    public var onSave: (DigestiveLog) -> Void

    public init(onSave: @escaping (DigestiveLog) -> Void) {
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Satiety
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ΚΟΡΕΣΜΟΣ & ΠΕΙΝΑ")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)

                        Picker("Κορεσμός", selection: $satiety) {
                            Text("1 - Πείνα").tag(SatietyScore.hungry)
                            Text("3 - Ιδανικό").tag(SatietyScore.pleasantlySatisfied)
                            Text("4 - Πλήρης").tag(SatietyScore.full)
                            Text("5 - Βαρυστομαχιά").tag(SatietyScore.stuffed)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Energy Level
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ΕΠΙΠΕΔΟ ΕΝΕΡΓΕΙΑΣ ΜΕΤΑ ΤΟ ΓΕΥΜΑ")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)

                        Picker("Ενέργεια", selection: $energy) {
                            Text("1 - Food Coma").tag(EnergyLevel.foodComa)
                            Text("3 - Σταθερή").tag(EnergyLevel.steady)
                            Text("5 - Peak Vitality").tag(EnergyLevel.peakAthletic)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Symptoms
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ΣΥΜΠΤΩΜΑΤΑ ΠΕΨΗΣ")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)

                        ForEach(DigestSymptom.allCases, id: \.self) { sym in
                            Button {
                                Haptics.selection()
                                if selectedSymptoms.contains(sym) {
                                    selectedSymptoms.remove(sym)
                                } else {
                                    selectedSymptoms.insert(sym)
                                }
                            } label: {
                                HStack {
                                    Text(sym.titleGreek)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(OrchardColors.text)
                                    Spacer()
                                    if selectedSymptoms.contains(sym) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(10)
                                .background(Color.secondary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Save
                    Button {
                        Haptics.success()
                        let log = DigestiveLog(
                            mealEventId: "manual_log",
                            satiety: satiety,
                            energy: energy,
                            symptoms: Array(selectedSymptoms),
                            notes: note.isEmpty ? nil : note
                        )
                        onSave(log)
                        dismiss()
                    } label: {
                        Text("Αποθήκευση Αξιολόγησης Πέψης")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.teal)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(16)
            }
            .background(OrchardColors.background.ignoresSafeArea())
            .navigationTitle("Ημερολόγιο Πέψης & Κορεσμού")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Κλείσιμο") { dismiss() }
                }
            }
        }
    }
}
