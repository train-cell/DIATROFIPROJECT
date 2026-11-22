import Foundation

#if canImport(OrchardDomain)
import OrchardDomain
#endif

/// Strongly-typed errors for AI Nutrition Coach operations.
public enum AICoachError: LocalizedError, Equatable {
    case missingAPIKey
    case aiDisabled
    case networkError(String)
    case underlying(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Πρόσθεσε το Gemini API Key σου στις Ρυθμίσεις (BYOK)"
        case .aiDisabled:
            return "Ο AI Βοηθός είναι απενεργοποιημένος στις Ρυθμίσεις"
        case .networkError(let msg):
            return "Σφάλμα δικτύου: \(msg)"
        case .underlying(let msg):
            return msg
        }
    }
}

/// Orchestration service for conversational and quick-estimation AI Nutrition Coach interactions.
public final class AICoachService: @unchecked Sendable {

    private let router: LLMRouter
    private let requiresAPIKey: Bool
    private let explicitAPIKey: String?

    public init(router: LLMRouter, requiresKey: Bool = false, explicitAPIKey: String? = nil) {
        self.router = router
        self.requiresAPIKey = requiresKey
        self.explicitAPIKey = explicitAPIKey
    }

    /// Default live production factory configuring BYOK Gemini with fallback chain.
    public static func makeLive(apiKeyOverride: String? = nil) -> AICoachService {
        let key: String? = {
            if let explicit = apiKeyOverride {
                let trimmed = explicit.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            let stored = KeychainStore.shared.getAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (stored != nil && !stored!.isEmpty) ? stored : nil
        }()

        let preferred = UserDefaults.standard.string(forKey: "orchard_gemini_preferred_model") ?? "auto"
        let gemini = GeminiLLMProvider(apiKey: key, preferredModel: preferred)
        let router = LLMRouter(gemini: gemini, appleOnDevice: nil, cloud: nil, mock: nil)
        return AICoachService(router: router, requiresKey: true, explicitAPIKey: key)
    }

    /// Sends a conversational user message, incorporating chat history and full plan context.
    public func sendMessage(
        _ userMessage: String,
        history: [AICoachChatMessage],
        plan: Plan,
        snapshot: AICoachDailySnapshot
    ) async throws -> AICoachResponse {
        try validateReadiness()

        let systemPrompt = NutritionContextBuilder.buildSystemPrompt(plan: plan, snapshot: snapshot)

        var promptParts: [String] = []
        if !history.isEmpty {
            promptParts.append("ΙΣΤΟΡΙΚΟ ΠΡΟΗΓΟΥΜΕΝΗΣ ΣΥΝΟΜΙΛΙΑΣ:")
            for msg in history.suffix(8) {
                let sender = msg.isUser ? "Χρήστης" : "Coach"
                promptParts.append("\(sender): \(msg.text)")
            }
            promptParts.append("")
        }
        promptParts.append("ΝΕΟ ΜΗΝΥΜΑ ΧΡΗΣΤΗ:")
        promptParts.append(userMessage)

        let fullPrompt = promptParts.joined(separator: "\n")

        do {
            let rawResponse: AICoachResponse = try await router.generate(
                prompt: fullPrompt,
                systemPrompt: systemPrompt,
                schema: AICoachResponse.self
            )
            return AICoachResponseValidator.sanitizeAndHydrate(
                response: rawResponse,
                plan: plan,
                templateKey: snapshot.selectedTemplateKey
            )
        } catch {
            throw mapError(error)
        }
    }

    /// Quick food estimation utility for smart logging sheets (AILogSheet).
    public func estimateQuickFood(
        _ description: String,
        plan: Plan,
        snapshot: AICoachDailySnapshot
    ) async throws -> AICoachResponse {
        try validateReadiness()

        let systemPrompt = NutritionContextBuilder.buildSystemPrompt(plan: plan, snapshot: snapshot)
        let prompt = """
        Εκτίμησε το παρακάτω γεύμα/τρόφιμο και αντιστοίχισέ το στο πρόγραμμα (αν ταιριάζει) ή υπολόγισε εκτιμώμενες θερμίδες και μακροστοιχεία:
        "\(description)"
        """

        do {
            let rawResponse: AICoachResponse = try await router.generate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                schema: AICoachResponse.self
            )
            return AICoachResponseValidator.sanitizeAndHydrate(
                response: rawResponse,
                plan: plan,
                templateKey: snapshot.selectedTemplateKey
            )
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Private Helpers

    private func validateReadiness() throws {
        guard router.isEnabled else {
            throw AICoachError.aiDisabled
        }
        if requiresAPIKey {
            let key = explicitAPIKey ?? KeychainStore.shared.getAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
            if key == nil || key!.isEmpty {
                throw AICoachError.missingAPIKey
            }
        }
    }

    private func mapError(_ error: Error) -> Error {
        if let aiError = error as? AICoachError {
            return aiError
        }
        if let llmError = error as? LLMError {
            switch llmError {
            case .unavailable(let reason):
                if reason.contains("disabled") || reason.contains("Settings") {
                    return AICoachError.aiDisabled
                }
                if reason.contains("No AI provider") {
                    return AICoachError.missingAPIKey
                }
                return AICoachError.underlying(reason)
            case .requestFailed(let reason):
                return AICoachError.networkError(reason)
            case .decodingFailed(let reason), .invalidResponse(let reason):
                return AICoachError.underlying(reason)
            }
        }
        return error
    }
}
