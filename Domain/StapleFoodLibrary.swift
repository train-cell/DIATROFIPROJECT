import Foundation

/// Cronometer & MyFitnessPal-style offline athletic staple food database and barcode lookup.
/// Zero-latency, zero-network instant search for high-protein, clean bodybuilding staples.
public enum FoodCategory: String, Codable, Sendable, CaseIterable {
    case leanProtein = "protein"
    case complexCarb = "carbs"
    case healthyFat = "fat"
    case vegetable = "vegetable"
    case supplement = "supplement"

    public var titleGreek: String {
        switch self {
        case .leanProtein: return "Καθαρή Πρωτεΐνη"
        case .complexCarb: return "Σύνθετοι Υδατάνθρακες"
        case .healthyFat: return "Καλά Λιπαρά"
        case .vegetable: return "Λαχανικά & Ίνες"
        case .supplement: return "Συμπλήρωμα"
        }
    }
}

public struct StapleFoodItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var nameGreek: String
    public var category: FoodCategory
    public var referenceGrams: Double   // e.g. 100g
    public var kcal: Double
    public var protein: Double
    public var carbs: Double
    public var fats: Double
    public var fiber: Double
    public var barcode: String

    public init(
        id: String,
        nameGreek: String,
        category: FoodCategory,
        referenceGrams: Double = 100.0,
        kcal: Double,
        protein: Double,
        carbs: Double,
        fats: Double,
        fiber: Double,
        barcode: String
    ) {
        self.id = id
        self.nameGreek = nameGreek
        self.category = category
        self.referenceGrams = referenceGrams
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.fiber = fiber
        self.barcode = barcode
    }

    /// Computes scaled macros for an arbitrary portion in grams.
    public func macros(forGrams grams: Double) -> (kcal: Double, p: Double, c: Double, f: Double, fiber: Double) {
        guard referenceGrams > 0 else { return (0, 0, 0, 0, 0) }
        let scale = grams / referenceGrams
        return (
            kcal: round(kcal * scale * 10.0) / 10.0,
            p: round(protein * scale * 10.0) / 10.0,
            c: round(carbs * scale * 10.0) / 10.0,
            f: round(fats * scale * 10.0) / 10.0,
            fiber: round(fiber * scale * 10.0) / 10.0
        )
    }
}

public enum StapleFoodLibrary {
    public static let items: [StapleFoodItem] = [
        StapleFoodItem(id: "chk_brst", nameGreek: "Στήθος Κοτόπουλο (Ψητό)", category: .leanProtein, kcal: 165, protein: 31.0, carbs: 0.0, fats: 3.6, fiber: 0.0, barcode: "5201001000101"),
        StapleFoodItem(id: "egg_white", nameGreek: "Ασπράδι Αυγού (Παστεριωμένο)", category: .leanProtein, kcal: 52, protein: 11.0, carbs: 0.7, fats: 0.2, fiber: 0.0, barcode: "5201001000102"),
        StapleFoodItem(id: "whole_egg", nameGreek: "Αυγό Ολόκληρο (Βραστό/Ποσέ)", category: .leanProtein, kcal: 143, protein: 12.6, carbs: 0.8, fats: 9.5, fiber: 0.0, barcode: "5201001000103"),
        StapleFoodItem(id: "whey_iso", nameGreek: "Whey Protein Isolate (100g)", category: .leanProtein, kcal: 370, protein: 86.0, carbs: 2.5, fats: 1.5, fiber: 0.0, barcode: "5201001000104"),
        StapleFoodItem(id: "beef_tenderloin", nameGreek: "Μοσχαρίσιο Φιλέτο (Άπαχο)", category: .leanProtein, kcal: 179, protein: 26.0, carbs: 0.0, fats: 7.6, fiber: 0.0, barcode: "5201001000105"),
        StapleFoodItem(id: "salmon_fillet", nameGreek: "Φιλέτο Σολομού (Ωμέγα-3)", category: .leanProtein, kcal: 208, protein: 20.0, carbs: 0.0, fats: 13.0, fiber: 0.0, barcode: "5201001000106"),
        StapleFoodItem(id: "greek_yogurt_0", nameGreek: "Ελληνικό Στραγγιστό Γιαούρτι 0%", category: .leanProtein, kcal: 57, protein: 10.3, carbs: 4.0, fats: 0.0, fiber: 0.0, barcode: "5201001000107"),
        StapleFoodItem(id: "rolled_oats", nameGreek: "Νιφάδες Βρώμης (Ολικής)", category: .complexCarb, kcal: 379, protein: 13.2, carbs: 67.7, fats: 6.5, fiber: 10.1, barcode: "5201001000108"),
        StapleFoodItem(id: "cream_of_rice", nameGreek: "Cream of Rice (Άλευρο Ρυζιού)", category: .complexCarb, kcal: 360, protein: 7.0, carbs: 80.0, fats: 1.0, fiber: 1.5, barcode: "5201001000109"),
        StapleFoodItem(id: "basmati_rice", nameGreek: "Ρύζι Basmati (Βρασμένο)", category: .complexCarb, kcal: 130, protein: 2.7, carbs: 28.0, fats: 0.3, fiber: 0.4, barcode: "5201001000110"),
        StapleFoodItem(id: "sweet_potato", nameGreek: "Γλυκοπατάτα (Ψητή)", category: .complexCarb, kcal: 90, protein: 2.0, carbs: 20.7, fats: 0.2, fiber: 3.3, barcode: "5201001000111"),
        StapleFoodItem(id: "extra_virgin_olive_oil", nameGreek: "Έξτρα Παρθένο Ελαιόλαδο", category: .healthyFat, kcal: 884, protein: 0.0, carbs: 0.0, fats: 100.0, fiber: 0.0, barcode: "5201001000112"),
        StapleFoodItem(id: "peanut_butter", nameGreek: "Φυστικοβούτυρο 100% Φυσικό", category: .healthyFat, kcal: 588, protein: 25.0, carbs: 20.0, fats: 50.0, fiber: 8.0, barcode: "5201001000113"),
        StapleFoodItem(id: "almonds_raw", nameGreek: "Ωμά Αμύγδαλα (Ανάλατα)", category: .healthyFat, kcal: 579, protein: 21.2, carbs: 21.6, fats: 49.9, fiber: 12.5, barcode: "5201001000114"),
        StapleFoodItem(id: "steamed_broccoli", nameGreek: "Μπρόκολο στον Ατμό", category: .vegetable, kcal: 35, protein: 2.4, carbs: 7.2, fats: 0.4, fiber: 3.3, barcode: "5201001000115")
    ]

    /// Searches items by Greek title or ID.
    public static func search(query: String) -> [StapleFoodItem] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return items }
        return items.filter { item in
            item.nameGreek.lowercased().contains(clean) ||
            item.id.lowercased().contains(clean) ||
            item.category.rawValue.lowercased().contains(clean)
        }
    }

    /// Finds item by exact EAN/UPC barcode string.
    public static func lookup(barcode: String) -> StapleFoodItem? {
        let clean = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.first { $0.barcode == clean }
    }
}
