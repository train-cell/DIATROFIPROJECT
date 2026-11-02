import Foundation

/// MyFitnessPal-style Custom Recipe & Macro Combo Builder.
/// Allows athletes to combine multiple staple ingredients into composite high-protein meals
/// with automatic per-serving macro and calorie aggregation.
public struct RecipeIngredient: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var foodId: String
    public var nameGreek: String
    public var grams: Double
    public var kcal: Double
    public var protein: Double
    public var carbs: Double
    public var fats: Double
    public var fiber: Double

    public init(
        id: UUID = UUID(),
        foodId: String,
        nameGreek: String,
        grams: Double,
        kcal: Double,
        protein: Double,
        carbs: Double,
        fats: Double,
        fiber: Double
    ) {
        self.id = id
        self.foodId = foodId
        self.nameGreek = nameGreek
        self.grams = grams
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.fiber = fiber
    }

    public static func fromStaple(item: StapleFoodItem, grams: Double) -> RecipeIngredient {
        let m = item.macros(forGrams: grams)
        return RecipeIngredient(
            foodId: item.id,
            nameGreek: item.nameGreek,
            grams: grams,
            kcal: m.kcal,
            protein: m.p,
            carbs: m.c,
            fats: m.f,
            fiber: m.fiber
        )
    }
}

public struct CustomRecipe: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var titleGreek: String
    public var servings: Int
    public var ingredients: [RecipeIngredient]

    public init(
        id: UUID = UUID(),
        titleGreek: String,
        servings: Int = 1,
        ingredients: [RecipeIngredient] = []
    ) {
        self.id = id
        self.titleGreek = titleGreek
        self.servings = max(1, servings)
        self.ingredients = ingredients
    }

    public var totalGrams: Double {
        ingredients.reduce(0.0) { $0 + $1.grams }
    }

    public var totalKcal: Double {
        round(ingredients.reduce(0.0) { $0 + $1.kcal } * 10.0) / 10.0
    }

    public var totalProtein: Double {
        round(ingredients.reduce(0.0) { $0 + $1.protein } * 10.0) / 10.0
    }

    public var totalCarbs: Double {
        round(ingredients.reduce(0.0) { $0 + $1.carbs } * 10.0) / 10.0
    }

    public var totalFats: Double {
        round(ingredients.reduce(0.0) { $0 + $1.fats } * 10.0) / 10.0
    }

    public var totalFiber: Double {
        round(ingredients.reduce(0.0) { $0 + $1.fiber } * 10.0) / 10.0
    }

    // Per-serving breakdown
    public var perServingKcal: Double {
        round((totalKcal / Double(servings)) * 10.0) / 10.0
    }

    public var perServingProtein: Double {
        round((totalProtein / Double(servings)) * 10.0) / 10.0
    }

    public var perServingCarbs: Double {
        round((totalCarbs / Double(servings)) * 10.0) / 10.0
    }

    public var perServingFats: Double {
        round((totalFats / Double(servings)) * 10.0) / 10.0
    }

    /// Converts this custom recipe into a standard PlanItem.
    public func toPlanItem(id: String, anchor: Anchor) -> PlanItem {
        PlanItem(
            id: id,
            type: .meal,
            title: titleGreek,
            anchor: anchor,
            kcal: perServingKcal,
            protein: perServingProtein,
            carbs: perServingCarbs,
            fat: perServingFats
        )
    }
}
