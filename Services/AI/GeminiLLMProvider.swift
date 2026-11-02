import Foundation

#if canImport(OrchardDomain)
import OrchardDomain
#endif

/// Information describing a Gemini free-tier model in the fallback chain.
public struct GeminiModelInfo: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let descriptionGreek: String
    public let category: String
    public let tier: String
    public let rpmFree: Int

    public init(
        id: String,
        displayName: String,
        descriptionGreek: String,
        category: String,
        tier: String,
        rpmFree: Int
    ) {
        self.id = id
        self.displayName = displayName
        self.descriptionGreek = descriptionGreek
        self.category = category
        self.tier = tier
        self.rpmFree = rpmFree
    }
}

/// Result of an automated connection and fallback chain verification.
public struct ConnectionTestResult: Sendable, Codable, Equatable {
    public let isSuccess: Bool
    public let successfulModel: String?
    public let latencyMs: Double
    public let attemptedModels: [String]
    public let fallbackOccurred: Bool
    public let message: String

    public init(
        isSuccess: Bool,
        successfulModel: String?,
        latencyMs: Double,
        attemptedModels: [String],
        fallbackOccurred: Bool,
        message: String
    ) {
        self.isSuccess = isSuccess
        self.successfulModel = successfulModel
        self.latencyMs = latencyMs
        self.attemptedModels = attemptedModels
        self.fallbackOccurred = fallbackOccurred
        self.message = message
    }
}

/// Production LLM provider connecting to Google Gemini API using the user's
/// "Bring Your Own Key" (stored securely in Keychain) with an automated Fallback Chain
/// covering all available Flash, Flash-Lite, and Pro generations (3.x, 2.5, 2.0, 1.5)
/// available on Google AI Studio.
public struct GeminiLLMProvider: LLMProvider, @unchecked Sendable {
    public let id: String = "gemini"
    public let name: String = "Google Gemini (Bring Your Own Key)"

    /// Standard fallback chain of all free-tier and frontier models available in Google AI Studio.
    /// Follows priority: 3.x Frontier Flash/Lite/Pro -> 2.5 Flash/Lite/Pro -> 2.0 Flash/Lite -> 1.5 Workhorse/8B/Pro.
    public static let defaultFreeModelChain: [String] = [
        // Gemini 3.x Family
        "gemini-3.7-flash",
        "gemini-3.5-flash",
        "gemini-3.5-flash-lite",
        "gemini-3.1-pro",
        // Gemini 2.5 Family
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite",
        "gemini-2.5-pro",
        // Gemini 2.0 Family
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite",
        // Gemini 1.5 Family
        "gemini-1.5-flash",
        "gemini-1.5-flash-8b",
        "gemini-1.5-pro"
    ]

    /// Metadata describing each supported model across 3.x, 2.5, 2.0, and 1.5 families.
    public static let availableModelMetadata: [GeminiModelInfo] = [
        // Gemini 3.x Family
        GeminiModelInfo(
            id: "gemini-3.7-flash",
            displayName: "Gemini 3.7 Flash",
            descriptionGreek: "Frontier 3.7 Flash με κορυφαία ταχύτητα, multimodal κατανόηση & σύγχρονη συλλογιστική.",
            category: "Gemini 3.x Series",
            tier: "Free Tier (Google AI Studio)",
            rpmFree: 15
        ),
        GeminiModelInfo(
            id: "gemini-3.5-flash",
            displayName: "Gemini 3.5 Flash",
            descriptionGreek: "Προηγμένο Flash 3.5 για άμεση, υψηλής ακρίβειας κατανόηση γευμάτων & μακροστοιχείων.",
            category: "Gemini 3.x Series",
            tier: "Free Tier (Google AI Studio)",
            rpmFree: 15
        ),
        GeminiModelInfo(
            id: "gemini-3.5-flash-lite",
            displayName: "Gemini 3.5 Flash Lite",
            descriptionGreek: "Υπερ-ελαφρύ & ταχύτατο Flash-Lite 3.5 για μηδενικό latency και υψηλό throughput.",
            category: "Gemini 3.x Series",
            tier: "Free Tier (Google AI Studio)",
            rpmFree: 30
        ),
        GeminiModelInfo(
            id: "gemini-3.1-pro",
            displayName: "Gemini 3.1 Pro",
            descriptionGreek: "Frontier Pro 3.1 για σύνθετες διατροφικές συσχετίσεις και βαθιά λογική.",
            category: "Gemini 3.x Series",
            tier: "Free Tier (Google AI Studio)",
            rpmFree: 5
        ),

        // Gemini 2.5 Family
        GeminiModelInfo(
            id: "gemini-2.5-flash",
            displayName: "Gemini 2.5 Flash",
            descriptionGreek: "Καθιερωμένο flagship 2.5 Flash με ισορροπημένη απόδοση και ταχύτητα.",
            category: "Gemini 2.5 Series",
            tier: "Free Tier (Google AI Studio)",
            rpmFree: 15
        ),
        GeminiModelInfo(
            id: "gemini-2.5-flash-lite",
            displayName: "Gemini 2.5 Flash Lite",
            descriptionGreek: "Lightweight 2.5 Flash-Lite με άμεση απόκριση και χαμηλή κατανάλωση πόρων.",
            category: "Gemini 2.5 Series",
            tier: "Free Tier (Google AI Studio)",
            rpmFree: 30
        ),
        GeminiModelInfo(
            id: "gemini-2.5-pro",
            displayName: "Gemini 2.5 Pro",
            descriptionGreek: "Frontier Pro 2.5 για εξειδικευμένους υπολογισμούς μακροστοιχείων & ανάλυση.",
            category: "Gemini 2.5 Series",
            tier: "Free Tier (Google AI Studio)",
            rpmFree: 5
        ),

        // Gemini 2.0 Family
        GeminiModelInfo(
            id: "gemini-2.0-flash",
            displayName: "Gemini 2.0 Flash",
            descriptionGreek: "Standard 2.0 Flash μοντέλο ευρείας διαθεσιμότητας.",
            category: "Gemini 2.0 Series",
            tier: "Free Tier (Google AI Studio)",
            rpmFree: 15
        ),
        GeminiModelInfo(
            id: "gemini-2.0-flash-lite",
            displayName: "Gemini 2.0 Flash Lite",
            descriptionGreek: "Lite 2.0 έκδοση για άμεση εξυπηρέτηση όταν υπάρχει συμφόρηση.",
            category: "Gemini 2.0 Series",
            tier: "Free Tier (Google AI Studio)",
            rpmFree: 30
        ),

        // Gemini 1.5 Family
        GeminiModelInfo(
            id: "gemini-1.5-flash",
            displayName: "Gemini 1.5 Flash",
            descriptionGreek: "Το διαχρονικό workhorse της Google με αποδεδειγμένη μέγιστη σταθερότητα.",
            category: "Gemini 1.5 Series",
            tier: "Free Tier (Google AI Studio)",
            rpmFree: 15
        ),
        GeminiModelInfo(
            id: "gemini-1.5-flash-8b",
            displayName: "Gemini 1.5 Flash 8B",
            descriptionGreek: "8-Billion parameter lightweight μοντέλο για ταχύτατη εφεδρεία.",
            category: "Gemini 1.5 Series",
            tier: "Free Tier (Google AI Studio)",
            rpmFree: 15
        ),
        GeminiModelInfo(
            id: "gemini-1.5-pro",
            displayName: "Gemini 1.5 Pro",
            descriptionGreek: "Frontier Pro 1.5 ως το απόλυτο safety-net fallback.",
            category: "Gemini 1.5 Series",
            tier: "Free Tier (Google AI Studio)",
            rpmFree: 2
        )
    ]

    public let modelChain: [String]
    private let customApiKey: String?
    private let urlSession: URLSession

    public init(
        apiKey: String? = nil,
        preferredModel: String? = nil,
        modelChain: [String] = GeminiLLMProvider.defaultFreeModelChain,
        session: URLSession = .shared
    ) {
        self.customApiKey = apiKey
        self.urlSession = session

        let baseChain = modelChain.isEmpty ? GeminiLLMProvider.defaultFreeModelChain : modelChain

        // If user configured a preferred model, place it at the front of the fallback chain
        let resolvedPreferred: String? = {
            if let explicit = preferredModel, !explicit.isEmpty, explicit != "auto" {
                return explicit
            }
            if let saved = UserDefaults.standard.string(forKey: "orchard_gemini_preferred_model"),
               !saved.isEmpty, saved != "auto" {
                return saved
            }
            return nil
        }()

        if let preferred = resolvedPreferred {
            var chain = [preferred]
            for m in baseChain where m != preferred {
                chain.append(m)
            }
            self.modelChain = chain
        } else {
            self.modelChain = baseChain
        }
    }

    public var resolvedApiKey: String? {
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

    // MARK: - Generation via Multi-Model Fallback Chain
    public func generate<T: Decodable & Sendable>(
        prompt: String,
        systemPrompt: String,
        schema: T.Type
    ) async throws -> T {
        guard let apiKey = resolvedApiKey, !apiKey.isEmpty else {
            throw LLMError.unavailable("Gemini API key is not configured. Add your key in Settings.")
        }

        var attemptHistory: [(model: String, status: Int?, message: String)] = []

        for (index, model) in modelChain.enumerated() {
            let start = CFAbsoluteTimeGetCurrent()
            do {
                let decoded = try await executeSingleModelRequest(
                    model: model,
                    apiKey: apiKey,
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    schema: schema
                )

                let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
                await TelemetryService.shared.log(
                    event: .aiRequestExecuted(tool: "gemini-\(model)", durationMs: durationMs, success: true)
                )

                #if DEBUG
                if index > 0 {
                    print("⚡ Gemini fallback succeeded on '\(model)' after \(index) failure(s).")
                }
                #endif

                return decoded
            } catch let error as GeminiModelError {
                let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
                await TelemetryService.shared.log(
                    event: .aiRequestExecuted(tool: "gemini-\(model)", durationMs: durationMs, success: false)
                )

                attemptHistory.append((model: model, status: error.statusCode, message: error.message))

                // Fast-fail if API key itself is unauthorized or invalid
                if error.isFatalAuthError {
                    throw LLMError.unavailable("Gemini API Key rejected: \(error.message)")
                }

                // Fallback to next model in chain for 429 (rate limit), 503 (overload), 404 (not enabled yet), etc.
                continue
            } catch {
                let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
                await TelemetryService.shared.log(
                    event: .aiRequestExecuted(tool: "gemini-\(model)", durationMs: durationMs, success: false)
                )
                attemptHistory.append((model: model, status: nil, message: error.localizedDescription))
                continue
            }
        }

        let summary = attemptHistory.map { entry in
            let statusText = entry.status.map { "HTTP \($0): " } ?? ""
            return "\(entry.model) (\(statusText)\(entry.message))"
        }.joined(separator: " | ")

        throw LLMError.requestFailed("All \(modelChain.count) models in Gemini fallback chain failed: [\(summary)]")
    }

    // MARK: - Connection & Chain Diagnostic Test
    private struct PingCheck: Codable, Sendable {
        let status: String?
    }

    public func testConnection() async throws -> ConnectionTestResult {
        guard let apiKey = resolvedApiKey, !apiKey.isEmpty else {
            return ConnectionTestResult(
                isSuccess: false,
                successfulModel: nil,
                latencyMs: 0,
                attemptedModels: [],
                fallbackOccurred: false,
                message: "Δεν βρέθηκε Gemini API Key στο Keychain. Παρακαλώ εισάγετε το κλειδί σας."
            )
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        var attempted: [String] = []

        for (index, model) in modelChain.enumerated() {
            attempted.append(model)
            let pingStart = CFAbsoluteTimeGetCurrent()
            do {
                _ = try await executeSingleModelRequest(
                    model: model,
                    apiKey: apiKey,
                    prompt: "Respond with JSON: {\"status\":\"ok\"}",
                    systemPrompt: "You are a test ping service. Return valid JSON only.",
                    schema: PingCheck.self
                )
                let totalLatency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                let singleLatency = (CFAbsoluteTimeGetCurrent() - pingStart) * 1000.0
                let fallbackUsed = index > 0

                let msg: String
                if fallbackUsed {
                    msg = "Επιτυχής σύνδεση μέσω Fallback στο '\(model)' (\(Int(singleLatency))ms). Προηγούμενα μοντέλα: \(attempted.dropLast().joined(separator: ", "))."
                } else {
                    msg = "Επιτυχής άμεση σύνδεση με το κύριο μοντέλο '\(model)' (\(Int(singleLatency))ms)."
                }

                return ConnectionTestResult(
                    isSuccess: true,
                    successfulModel: model,
                    latencyMs: totalLatency,
                    attemptedModels: attempted,
                    fallbackOccurred: fallbackUsed,
                    message: msg
                )
            } catch let error as GeminiModelError {
                if error.isFatalAuthError {
                    return ConnectionTestResult(
                        isSuccess: false,
                        successfulModel: nil,
                        latencyMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0,
                        attemptedModels: attempted,
                        fallbackOccurred: false,
                        message: "Το API Key απορρίφθηκε από το Gemini: \(error.message)"
                    )
                }
                continue
            } catch {
                continue
            }
        }

        return ConnectionTestResult(
            isSuccess: false,
            successfulModel: nil,
            latencyMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0,
            attemptedModels: attempted,
            fallbackOccurred: true,
            message: "Όλα τα μοντέλα της αλυσίδας (\(attempted.joined(separator: ", "))) απέτυχαν."
        )
    }

    // MARK: - Internal HTTP Request Executor
    private func executeSingleModelRequest<T: Decodable & Sendable>(
        model: String,
        apiKey: String,
        prompt: String,
        systemPrompt: String,
        schema: T.Type
    ) async throws -> T {
        let endpointString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpointString) else {
            throw GeminiModelError(statusCode: nil, message: "Invalid URL for model \(model)", isFatalAuthError: false)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20.0

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
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw GeminiModelError(
                statusCode: nil,
                message: "Network error: \(error.localizedDescription)",
                isFatalAuthError: false
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiModelError(statusCode: nil, message: "Non-HTTP response", isFatalAuthError: false)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            let isFatal = (httpResponse.statusCode == 400 && errorBody.contains("API_KEY_INVALID")) ||
                          (httpResponse.statusCode == 403 && (errorBody.contains("PERMISSION_DENIED") || errorBody.contains("API key not valid")))

            throw GeminiModelError(
                statusCode: httpResponse.statusCode,
                message: errorBody,
                isFatalAuthError: isFatal
            )
        }

        // Parse Gemini Response JSON
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = jsonObject["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let textResponse = firstPart["text"] as? String else {
            throw GeminiModelError(statusCode: httpResponse.statusCode, message: "Malformed candidates in Gemini response", isFatalAuthError: false)
        }

        // Clean any markdown code ticks if present
        let cleanJson = textResponse
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let textData = cleanJson.data(using: .utf8) else {
            throw GeminiModelError(statusCode: httpResponse.statusCode, message: "Cannot encode UTF8", isFatalAuthError: false)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: textData)
        } catch {
            throw GeminiModelError(
                statusCode: httpResponse.statusCode,
                message: "Decoding failed for \(T.self): \(error.localizedDescription). Raw: \(cleanJson)",
                isFatalAuthError: false
            )
        }
    }
}

/// Internal model error tracking HTTP status codes and fatal auth issues.
public struct GeminiModelError: Error, Sendable {
    public let statusCode: Int?
    public let message: String
    public let isFatalAuthError: Bool

    public init(statusCode: Int?, message: String, isFatalAuthError: Bool) {
        self.statusCode = statusCode
        self.message = message
        self.isFatalAuthError = isFatalAuthError
    }
}
