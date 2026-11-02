import Foundation

/// Deterministic mock LLM provider returning realistic structured responses for unit testing and offline preview.
public final class MockLLMProvider: LLMProvider, @unchecked Sendable {
    public let id: String = "mock"
    public let name: String = "Orchard Deterministic Mock"

    public var isMockAvailable: Bool = true
    public var customJSONResponse: String?

    public init(isAvailable: Bool = true, customJSONResponse: String? = nil) {
        self.isMockAvailable = isAvailable
        self.customJSONResponse = customJSONResponse
    }

    public func isAvailable() async -> Bool {
        return isMockAvailable
    }

    public func generate<T: Decodable & Sendable>(
        prompt: String,
        systemPrompt: String,
        schema: T.Type
    ) async throws -> T {
        guard isMockAvailable else {
            throw LLMError.unavailable(name)
        }

        // 1. If explicit custom JSON is configured, use it
        if let customJSON = customJSONResponse,
           let customData = customJSON.data(using: .utf8) {
            return try JSONDecoder().decode(T.self, from: customData)
        }

        // 2. Synthesize structured response based on schema expectations
        let jsonDict: [String: Any]
        let lower = prompt.lowercased()

        if lower.contains("chicken") || lower.contains("κοτόπουλο") {
            jsonDict = [
                "title": "Κοτόπουλο με Ρύζι",
                "kcal": 520.0,
                "protein": 45.0,
                "carbs": 60.0,
                "fat": 8.0,
                "confidence": 0.95
            ]
        } else if lower.contains("salad") || lower.contains("σαλάτα") {
            jsonDict = [
                "title": "Πράσινη Σαλάτα με Ελαιόλαδο",
                "kcal": 220.0,
                "protein": 4.0,
                "carbs": 12.0,
                "fat": 18.0,
                "confidence": 0.90
            ]
        } else if lower.contains("plan") || lower.contains("πρόγραμμα") {
            jsonDict = [
                "narrative": "Εξαιρετική συνέπεια στην εβδομάδα, ολοκλήρωσες 18 από 21 γεύματα (85.7%).",
                "summary": "Συνέχισε δυναμικά."
            ]
        } else {
            jsonDict = [
                "title": prompt.isEmpty ? "Εκτίμηση Γεύματος" : prompt,
                "kcal": 450.0,
                "protein": 30.0,
                "carbs": 50.0,
                "fat": 12.0,
                "confidence": 0.85
            ]
        }

        let data = try JSONSerialization.data(withJSONObject: jsonDict)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LLMError.decodingFailed(error.localizedDescription)
        }
    }
}
