import Foundation

/// Production URLSession provider for Cloud LLMs (OpenAI, Anthropic, or local Ollama).
public final class CloudLLMProvider: LLMProvider, @unchecked Sendable {
    public let id: String = "cloud"
    public let name: String = "Cloud AI Provider"

    private let customApiKey: String?
    private let endpointURL: URL
    private let modelName: String
    private let keychainStore: KeychainStore
    private let urlSession: URLSession

    public init(
        apiKey: String? = nil,
        endpointURL: URL = URL(string: "https://api.openai.com/v1/chat/completions")!,
        modelName: String = "gpt-4o-mini",
        keychainStore: KeychainStore = KeychainStore(),
        urlSession: URLSession = .shared
    ) {
        self.customApiKey = apiKey
        self.endpointURL = endpointURL
        self.modelName = modelName
        self.keychainStore = keychainStore
        self.urlSession = urlSession
    }

    private var activeAPIKey: String? {
        if let explicit = customApiKey, !explicit.trimmingCharacters(in: .whitespaces).isEmpty {
            return explicit
        }
        return keychainStore.getAPIKey()
    }

    public func isAvailable() async -> Bool {
        guard let key = activeAPIKey, !key.isEmpty else {
            return false
        }
        return true
    }

    public func generate<T: Decodable & Sendable>(
        prompt: String,
        systemPrompt: String,
        schema: T.Type
    ) async throws -> T {
        guard let apiKey = activeAPIKey, !apiKey.isEmpty else {
            throw LLMError.unavailable("Cloud API key not configured in Keychain")
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "model": modelName,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": "\(systemPrompt)\nYou MUST return valid JSON adhering strictly to the requested schema."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.2
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP status error"
            throw LLMError.requestFailed(errorText)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let contentString = message["content"] as? String,
              let contentData = contentString.data(using: .utf8) else {
            throw LLMError.invalidResponse("Malformed OpenAI API response payload")
        }

        do {
            return try JSONDecoder().decode(T.self, from: contentData)
        } catch {
            throw LLMError.decodingFailed(error.localizedDescription)
        }
    }
}
