import Foundation

/// Sanitizes, validates, and deterministically hydrates AI Coach responses
/// using the source-of-truth active Plan schema (50/50 Physics / AI boundary).
public enum AICoachResponseValidator {

    /// Ensures all LLM actions contain deterministic macros and water from the Plan,
    /// clamps negative values to zero, and guarantees non-empty Greek responses.
    public static func sanitizeAndHydrate(
        response: AICoachResponse,
        plan: Plan,
        templateKey: String
    ) -> AICoachResponse {
        var reply = response.replyGreek.trimmingCharacters(in: .whitespacesAndNewlines)
        if reply.isEmpty {
            reply = "Καταγράφηκε επιτυχώς στο διατροφικό σου πλάνο!"
        }

        let hydratedActions = response.suggestedActions.map { action -> AICoachLogAction in
            var a = action

            // 1. Clamping negative, NaN, and Infinite values
            if let k = a.kcal { a.kcal = (k.isNaN || k.isInfinite) ? 0.0 : max(0.0, k) }
            if let p = a.protein { a.protein = (p.isNaN || p.isInfinite) ? 0.0 : max(0.0, p) }
            if let c = a.carbs { a.carbs = (c.isNaN || c.isInfinite) ? 0.0 : max(0.0, c) }
            if let f = a.fat { a.fat = (f.isNaN || f.isInfinite) ? 0.0 : max(0.0, f) }
            if let w = a.waterMl { a.waterMl = (w.isNaN || w.isInfinite) ? 0.0 : max(0.0, w) }

            // 2. Deterministic Hydration from PlanItem / PlanOption if itemId is provided
            if let itemId = a.itemId {
                let targetTemplate = plan.templates[templateKey]
                let matchedItem = targetTemplate?.items.first { $0.id == itemId }
                    ?? plan.templates.values.flatMap(\.items).first { $0.id == itemId }

                if let item = matchedItem {
                    // Try to resolve matching PlanOption first (exact or normalized ID)
                    if let optId = a.selectedOptionId {
                        let matchedOption = item.options?.first(where: {
                            $0.id == optId ||
                            $0.id.replacingOccurrences(of: "_opt_", with: "_") == optId ||
                            optId.replacingOccurrences(of: "tupper_", with: "tupper_opt_") == $0.id ||
                            optId.replacingOccurrences(of: "sw_", with: "sw_opt_") == $0.id
                        })

                        if let option = matchedOption {
                            if a.kcal == nil || a.kcal == 0 { a.kcal = option.kcal }
                            if a.protein == nil || a.protein == 0 { a.protein = option.protein }
                            if a.carbs == nil || a.carbs == 0 { a.carbs = option.carbs }
                            if a.fat == nil || a.fat == 0 { a.fat = option.fat }
                        }
                    }

                    // Fallback to PlanItem macros
                    if a.kcal == nil || a.kcal == 0 { a.kcal = item.kcal }
                    if a.protein == nil || a.protein == 0 { a.protein = item.protein }
                    if a.carbs == nil || a.carbs == 0 { a.carbs = item.carbs }
                    if a.fat == nil || a.fat == 0 { a.fat = item.fat }

                    // Hydrate water from PlanItem
                    if a.waterMl == nil, let itemWater = item.waterMl {
                        a.waterMl = itemWater
                    }
                }
            }

            // Post-hydration clamp to guarantee safe non-negative, finite numbers
            if let k = a.kcal { a.kcal = (k.isNaN || k.isInfinite) ? 0.0 : max(0.0, k) }
            if let p = a.protein { a.protein = (p.isNaN || p.isInfinite) ? 0.0 : max(0.0, p) }
            if let c = a.carbs { a.carbs = (c.isNaN || c.isInfinite) ? 0.0 : max(0.0, c) }
            if let f = a.fat { a.fat = (f.isNaN || f.isInfinite) ? 0.0 : max(0.0, f) }
            if let w = a.waterMl { a.waterMl = (w.isNaN || w.isInfinite) ? 0.0 : max(0.0, w) }

            return a
        }

        return AICoachResponse(replyGreek: reply, suggestedActions: hydratedActions)
    }
}
