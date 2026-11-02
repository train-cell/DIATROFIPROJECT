import XCTest
@testable import OrchardServices

private final class GeminiMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandlers: [String: (URLRequest) -> (HTTPURLResponse, Data)] = [:]
    nonisolated(unsafe) static var requestsReceived: [String] = []

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url?.absoluteString else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.requestsReceived.append(url)

        // Find matching handler by model substring in URL
        var handlerFound = false
        for (pattern, handler) in Self.requestHandlers {
            if url.contains(pattern) {
                let (response, data) = handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
                handlerFound = true
                break
            }
        }

        if !handlerFound {
            let errorData = "{\"error\": {\"message\": \"No mock handler for URL\"}}".data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: errorData)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

private struct TestAiNutrition: Codable, Equatable, Sendable {
    let meal: String
    let calories: Double
}

final class GeminiFallbackChainTests: XCTestCase {

    private var customSession: URLSession!

    override func setUp() {
        super.setUp()
        GeminiMockURLProtocol.requestHandlers = [:]
        GeminiMockURLProtocol.requestsReceived = []

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [GeminiMockURLProtocol.self]
        customSession = URLSession(configuration: config)
    }

    override func tearDown() {
        GeminiMockURLProtocol.requestHandlers = [:]
        GeminiMockURLProtocol.requestsReceived = []
        customSession = nil
        super.tearDown()
    }

    private func makeSuccessResponse(url: URL, json: String) -> (HTTPURLResponse, Data) {
        let wrapped = """
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  {
                    "text": "\(json.replacingOccurrences(of: "\"", with: "\\\""))"
                  }
                ]
              }
            }
          ]
        }
        """
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (response, wrapped.data(using: .utf8)!)
    }

    private func makeErrorResponse(url: URL, status: Int, message: String) -> (HTTPURLResponse, Data) {
        let body = "{\"error\": {\"code\": \(status), \"message\": \"\(message)\"}}"
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (response, body.data(using: .utf8)!)
    }

    // MARK: - Test 1: Immediate Success On First Model
    func testImmediateSuccessOnFirstModel() async throws {
        let models = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash"]
        GeminiMockURLProtocol.requestHandlers["gemini-2.5-flash"] = { req in
            self.makeSuccessResponse(url: req.url!, json: "{\"meal\": \"Chicken\", \"calories\": 450}")
        }

        let provider = GeminiLLMProvider(
            apiKey: "AIzaSy_TEST_KEY",
            modelChain: models,
            session: customSession
        )

        let result = try await provider.generate(
            prompt: "Chicken meal",
            systemPrompt: "Nutrition assistant",
            schema: TestAiNutrition.self
        )

        XCTAssertEqual(result.meal, "Chicken")
        XCTAssertEqual(result.calories, 450)
        XCTAssertEqual(GeminiMockURLProtocol.requestsReceived.count, 1)
        XCTAssertTrue(GeminiMockURLProtocol.requestsReceived[0].contains("gemini-2.5-flash"))
    }

    // MARK: - Test 2: Fallback On 429 Rate Limit
    func testFallbackToSecondModelOn429RateLimit() async throws {
        let models = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash"]

        // First model hits 429 quota exhaustion
        GeminiMockURLProtocol.requestHandlers["gemini-2.5-flash"] = { req in
            self.makeErrorResponse(url: req.url!, status: 429, message: "RESOURCE_EXHAUSTED: Rate limit exceeded")
        }

        // Second model responds successfully
        GeminiMockURLProtocol.requestHandlers["gemini-2.0-flash"] = { req in
            self.makeSuccessResponse(url: req.url!, json: "{\"meal\": \"Beef\", \"calories\": 600}")
        }

        let provider = GeminiLLMProvider(
            apiKey: "AIzaSy_TEST_KEY",
            modelChain: models,
            session: customSession
        )

        let result = try await provider.generate(
            prompt: "Beef meal",
            systemPrompt: "Nutrition assistant",
            schema: TestAiNutrition.self
        )

        XCTAssertEqual(result.meal, "Beef")
        XCTAssertEqual(result.calories, 600)
        XCTAssertEqual(GeminiMockURLProtocol.requestsReceived.count, 2)
        XCTAssertTrue(GeminiMockURLProtocol.requestsReceived[0].contains("gemini-2.5-flash"))
        XCTAssertTrue(GeminiMockURLProtocol.requestsReceived[1].contains("gemini-2.0-flash"))
    }

    // MARK: - Test 3: Multiple Failures Chain (429, 503, 404) -> 4th Model Recovers
    func testMultipleFailuresChainSurvivesAndSucceeds() async throws {
        let models = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.0-flash-lite", "gemini-1.5-flash"]

        GeminiMockURLProtocol.requestHandlers["gemini-2.5-flash"] = { req in
            self.makeErrorResponse(url: req.url!, status: 429, message: "RESOURCE_EXHAUSTED")
        }
        GeminiMockURLProtocol.requestHandlers["gemini-2.0-flash"] = { req in
            self.makeErrorResponse(url: req.url!, status: 503, message: "UNAVAILABLE: Model overloaded")
        }
        GeminiMockURLProtocol.requestHandlers["gemini-2.0-flash-lite"] = { req in
            self.makeErrorResponse(url: req.url!, status: 404, message: "NOT_FOUND: Model not enabled in region")
        }
        GeminiMockURLProtocol.requestHandlers["gemini-1.5-flash"] = { req in
            self.makeSuccessResponse(url: req.url!, json: "{\"meal\": \"Salmon\", \"calories\": 520}")
        }

        let provider = GeminiLLMProvider(
            apiKey: "AIzaSy_TEST_KEY",
            modelChain: models,
            session: customSession
        )

        let result = try await provider.generate(
            prompt: "Salmon dinner",
            systemPrompt: "Nutrition assistant",
            schema: TestAiNutrition.self
        )

        XCTAssertEqual(result.meal, "Salmon")
        XCTAssertEqual(result.calories, 520)
        XCTAssertEqual(GeminiMockURLProtocol.requestsReceived.count, 4)
    }

    // MARK: - Test 4: All Models Fail Throws Consolidated Diagnostic
    func testAllModelsFailThrowsConsolidatedError() async {
        let models = ["gemini-2.5-flash", "gemini-2.0-flash"]

        GeminiMockURLProtocol.requestHandlers["gemini-2.5-flash"] = { req in
            self.makeErrorResponse(url: req.url!, status: 429, message: "Quota exceeded")
        }
        GeminiMockURLProtocol.requestHandlers["gemini-2.0-flash"] = { req in
            self.makeErrorResponse(url: req.url!, status: 503, message: "Server down")
        }

        let provider = GeminiLLMProvider(
            apiKey: "AIzaSy_TEST_KEY",
            modelChain: models,
            session: customSession
        )

        do {
            _ = try await provider.generate(
                prompt: "Tuna",
                systemPrompt: "Nutrition",
                schema: TestAiNutrition.self
            )
            XCTFail("Should have thrown error when all models in chain fail")
        } catch let LLMError.requestFailed(msg) {
            XCTAssertTrue(msg.contains("All 2 models in Gemini fallback chain failed"))
            XCTAssertTrue(msg.contains("gemini-2.5-flash"))
            XCTAssertTrue(msg.contains("gemini-2.0-flash"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Test 5: Fatal Auth Error Fast Fails Without Wasting Retries
    func testFatalAuthErrorFastFails() async {
        let models = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash"]

        GeminiMockURLProtocol.requestHandlers["gemini-2.5-flash"] = { req in
            self.makeErrorResponse(url: req.url!, status: 400, message: "API_KEY_INVALID: Key does not exist")
        }

        let provider = GeminiLLMProvider(
            apiKey: "INVALID_KEY",
            modelChain: models,
            session: customSession
        )

        do {
            _ = try await provider.generate(
                prompt: "Tuna",
                systemPrompt: "Nutrition",
                schema: TestAiNutrition.self
            )
            XCTFail("Should fail immediately on invalid API key")
        } catch let LLMError.unavailable(msg) {
            XCTAssertTrue(msg.contains("Gemini API Key rejected"))
            // Only 1 request should be attempted because key is bad!
            XCTAssertEqual(GeminiMockURLProtocol.requestsReceived.count, 1)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Test 6: Connection Test Diagnostic
    func testConnectionDiagnosticDetectsFallback() async throws {
        let models = ["gemini-2.5-flash", "gemini-2.0-flash"]

        GeminiMockURLProtocol.requestHandlers["gemini-2.5-flash"] = { req in
            self.makeErrorResponse(url: req.url!, status: 429, message: "Rate limit")
        }
        GeminiMockURLProtocol.requestHandlers["gemini-2.0-flash"] = { req in
            self.makeSuccessResponse(url: req.url!, json: "{\"status\": \"ok\"}")
        }

        let provider = GeminiLLMProvider(
            apiKey: "AIzaSy_VALID",
            modelChain: models,
            session: customSession
        )

        let diagnostic = try await provider.testConnection()
        XCTAssertTrue(diagnostic.isSuccess)
        XCTAssertTrue(diagnostic.fallbackOccurred)
        XCTAssertEqual(diagnostic.successfulModel, "gemini-2.0-flash")
        XCTAssertEqual(diagnostic.attemptedModels, ["gemini-2.5-flash", "gemini-2.0-flash"])
        XCTAssertTrue(diagnostic.message.contains("Fallback στο 'gemini-2.0-flash'"))
    }

    // MARK: - Test 7: Gemini 3.x Family Prioritization & Fallback Chain
    func testGemini3FamilyPrioritizationAndFallback() async throws {
        // Given: 3.7 hits 429, 3.5 hits 503, 3.5-flash-lite succeeds
        GeminiMockURLProtocol.requestHandlers["gemini-3.7-flash"] = { req in
            self.makeErrorResponse(url: req.url!, status: 429, message: "RESOURCE_EXHAUSTED")
        }
        GeminiMockURLProtocol.requestHandlers["gemini-3.5-flash"] = { req in
            self.makeErrorResponse(url: req.url!, status: 503, message: "UNAVAILABLE")
        }
        GeminiMockURLProtocol.requestHandlers["gemini-3.5-flash-lite"] = { req in
            self.makeSuccessResponse(url: req.url!, json: "{\"meal\": \"Oats & Whey\", \"calories\": 380}")
        }

        let provider = GeminiLLMProvider(
            apiKey: "AIzaSy_VALID_KEY",
            session: customSession
        )

        // Verify default chain starts with 3.7, 3.5, 3.5-lite, 3.1-pro
        XCTAssertEqual(provider.modelChain.first, "gemini-3.7-flash")
        XCTAssertTrue(provider.modelChain.contains("gemini-3.5-flash"))
        XCTAssertTrue(provider.modelChain.contains("gemini-3.5-flash-lite"))
        XCTAssertTrue(provider.modelChain.contains("gemini-3.1-pro"))
        XCTAssertTrue(provider.modelChain.contains("gemini-2.5-pro"))

        let result = try await provider.generate(
            prompt: "Oats and whey breakfast",
            systemPrompt: "Nutrition",
            schema: TestAiNutrition.self
        )

        XCTAssertEqual(result.meal, "Oats & Whey")
        XCTAssertEqual(result.calories, 380)
        XCTAssertEqual(GeminiMockURLProtocol.requestsReceived.count, 3)
        XCTAssertTrue(GeminiMockURLProtocol.requestsReceived[0].contains("gemini-3.7-flash"))
        XCTAssertTrue(GeminiMockURLProtocol.requestsReceived[1].contains("gemini-3.5-flash"))
        XCTAssertTrue(GeminiMockURLProtocol.requestsReceived[2].contains("gemini-3.5-flash-lite"))
    }

    // MARK: - Test 8: Preferred Model Configuration Moves Directly to Head of Chain
    func testPreferredModelConfigurationMovesDirectlyToHeadOfChain() {
        let provider = GeminiLLMProvider(
            apiKey: "AIzaSy_KEY",
            preferredModel: "gemini-2.5-pro",
            session: customSession
        )

        XCTAssertEqual(provider.modelChain.first, "gemini-2.5-pro")
        // Check no duplicates and other models are present
        XCTAssertEqual(provider.modelChain.filter { $0 == "gemini-2.5-pro" }.count, 1)
        XCTAssertEqual(provider.modelChain.count, GeminiLLMProvider.defaultFreeModelChain.count)
        XCTAssertEqual(provider.modelChain[1], "gemini-3.7-flash")
    }
}
