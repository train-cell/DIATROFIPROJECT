import XCTest
@testable import OrchardServices

struct TestFoodResponse: Codable, Equatable, Sendable {
    let title: String
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

final class LLMRouterTests: XCTestCase {

    func testMockProviderGeneratesStructuredResponse() async throws {
        let mock = MockLLMProvider()
        let isAvailable = await mock.isAvailable()
        XCTAssertTrue(isAvailable)

        let response = try await mock.generate(
            prompt: "Chicken and rice",
            systemPrompt: "Estimate calories and macros",
            schema: TestFoodResponse.self
        )

        XCTAssertFalse(response.title.isEmpty)
        XCTAssertGreaterThan(response.kcal, 0)
    }

    func testRouterPriorityFallback() async throws {
        // Given: on-device unavailable, cloud unavailable (no key), mock available
        let onDevice = AppleOnDeviceProvider(forceAvailable: false)
        let cloud = CloudLLMProvider(apiKey: nil)
        let mock = MockLLMProvider()

        let router = LLMRouter(
            appleOnDevice: onDevice,
            cloud: cloud,
            mock: mock,
            isEnabled: true
        )

        let active = await router.activeProvider()
        XCTAssertEqual(active?.id, "mock")

        let response = try await router.generate(
            prompt: "Salad",
            systemPrompt: "Nutrition",
            schema: TestFoodResponse.self
        )
        XCTAssertGreaterThan(response.kcal, 0)
    }

    func testRouterRespectsDisabledKillswitch() async {
        let mock = MockLLMProvider()
        let router = LLMRouter(
            mock: mock,
            isEnabled: false
        )

        do {
            _ = try await router.generate(
                prompt: "Steak",
                systemPrompt: "Nutrition",
                schema: TestFoodResponse.self
            )
            XCTFail("Should throw when AI is disabled")
        } catch {
            // Expected
        }
    }

    func testKeychainStoreSaveAndRetrieve() {
        let store = KeychainStore(inMemory: true)
        let testKey = "sk-test-12345678"

        store.saveAPIKey(testKey)
        XCTAssertEqual(store.getAPIKey(), testKey)

        store.deleteAPIKey()
        XCTAssertNil(store.getAPIKey())
    }
}
