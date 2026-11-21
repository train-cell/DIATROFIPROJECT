import Foundation

/// Pure deterministic validator for imported or AI-generated plan drafts.
public struct PlanDraftValidator {

    /// Validates a Plan structure for internal consistency and valid time formats.
    public static func validate(plan: Plan) -> ValidationResult {
        var reasons: [String] = []

        // 1. Settings time formats & hydration target
        if !isValidTime(plan.settings.wake) {
            reasons.append("Invalid wake time format: '\(plan.settings.wake)'. Must be HH:mm")
        }
        if !isValidTime(plan.settings.bed) {
            reasons.append("Invalid bed time format: '\(plan.settings.bed)'. Must be HH:mm")
        }
        if plan.settings.targetWaterMl <= 0 {
            reasons.append("Settings targetWaterMl must be greater than 0: \(plan.settings.targetWaterMl)")
        }

        // 2. Templates existence
        if plan.templates.isEmpty {
            reasons.append("Plan must contain at least one day template")
        }

        // 3. Template item consistency
        for (templateName, template) in plan.templates {
            if let tw = template.targetWaterMl, tw <= 0 {
                reasons.append("Template '\(templateName)' targetWaterMl must be greater than 0: \(tw)")
            }

            var itemIds: Set<String> = []

            for item in template.items {
                // Non-empty ID & title
                if item.id.trimmingCharacters(in: .whitespaces).isEmpty {
                    reasons.append("Template '\(templateName)' contains an item with an empty ID")
                }
                if item.title.trimmingCharacters(in: .whitespaces).isEmpty {
                    reasons.append("Template '\(templateName)' item '\(item.id)' has an empty title")
                }

                // Unique ID check
                if itemIds.contains(item.id) {
                    reasons.append("Template '\(templateName)' contains duplicate item ID: '\(item.id)'")
                }
                itemIds.insert(item.id)

                // Fallback time format check
                if let fallback = item.fallbackTime, !isValidTime(fallback) {
                    reasons.append("Template '\(templateName)' item '\(item.id)' has invalid fallbackTime: '\(fallback)'")
                }

                // Absolute anchor time format check
                if case .absolute(let time) = item.anchor, !isValidTime(time) {
                    reasons.append("Template '\(templateName)' item '\(item.id)' has invalid absolute time: '\(time)'")
                }

                // Plan options validation
                if let options = item.options, !options.isEmpty {
                    var optionIds: Set<String> = []
                    var optionTitles: Set<String> = []
                    for option in options {
                        if option.id.trimmingCharacters(in: .whitespaces).isEmpty {
                            reasons.append("Template '\(templateName)' item '\(item.id)' contains an option with an empty ID")
                        }
                        if option.title.trimmingCharacters(in: .whitespaces).isEmpty {
                            reasons.append("Template '\(templateName)' item '\(item.id)' option '\(option.id)' has an empty title")
                        }
                        if optionIds.contains(option.id) {
                            reasons.append("Template '\(templateName)' item '\(item.id)' contains duplicate option ID: '\(option.id)'")
                        }
                        optionIds.insert(option.id)

                        if optionTitles.contains(option.title) {
                            reasons.append("Template '\(templateName)' item '\(item.id)' contains duplicate option title: '\(option.title)'")
                        }
                        optionTitles.insert(option.title)
                    }
                }
            }

            // withItem dangling reference check
            for item in template.items {
                if case .withItem(let parentId) = item.anchor {
                    if !itemIds.contains(parentId) {
                        reasons.append("Template '\(templateName)' item '\(item.id)' references non_existent_meal '\(parentId)'")
                    }
                }
            }

            // Training sessions time format
            for session in template.trainingSessions {
                if let start = session.start, !isValidTime(start) {
                    reasons.append("Template '\(templateName)' training session has invalid start time: '\(start)'")
                }
            }
        }

        if !reasons.isEmpty {
            return .invalid(reasons: reasons)
        }

        return .valid
    }

    private static func isValidTime(_ timeString: String) -> Bool {
        let parts = timeString.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return false }
        let hour = parts[0]
        let minute = parts[1]
        return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59
    }
}
