import Foundation

#if canImport(OrchardDomain)
import OrchardDomain
#endif

/// Production LLM provider connecting to Google Gemini API (gemini-2.5-flash)
/// using the user's "Bring Your Own Key" stored securely in the device Keychain.
public struct GeminiLLMProvider: LLMProvider, @unchecked Sendable {
    public let id: String = "gemini"
    public let name: String = "Google Gemini (Bring Your Own Key)"

    private let customApiKey: String?

    public init(apiKey: String? = nil) {
        self.customApiKey = apiKey
    }

    private var resolvedApiKey: String? {
        if let key = customApiKey, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key
        }
        return KeychainStore.shared.getAPIKey()
    }

    public func isAvailable() async -> Bool {
        guard let key = resolvedApiKey, !key.isEmpty else {
            return false
        }
        return true
    }

    public func generate<T: Decodable & Sendable>(
        prompt: String,
        systemPrompt: String,
        schema: T.Type
    ) async throws -> T {
        guard let apiKey = resolvedApiKey, !apiKey.isEmpty else {
            throw LLMError.unavailable("Gemini API key is not configured. Add your key in Settings.")
        }

        let endpointString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpointString) else {
            throw LLMError.requestFailed("Invalid Gemini API endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 25.0

        let fullPrompt = """
        \(systemPrompt)

        IMPORTANT: Output strictly valid JSON matching the requested schema. Do not include markdown codeblocks or explanation.

        User Request:
        \(prompt)
        """

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": fullPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.2
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.requestFailed("Network error connecting to Gemini API: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.requestFailed("Invalid HTTP response from Gemini")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.requestFailed("Gemini API returned status code \(httpResponse.statusCode): \(errorBody)")
        }

        // Parse Gemini Response JSON
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = jsonObject["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let textResponse = firstPart["text"] as? String else {
            throw LLMError.invalidResponse("Could not parse candidates from Gemini response")
        }

        // Clean any stray markdown ticks if present
        let cleanJson = textResponse
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let textData = cleanJson.data(using: .utf8) else {
            throw LLMError.decodingFailed("Failed to encode clean JSON text")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: textData)
        } catch {
            throw LLMError.decodingFailed("Failed to decode model into \(T.self): \(error.localizedDescription). Raw: \(cleanJson)")
        }
    }
}
