import Foundation

/// Priority-based router for directing AI prompts to the optimal available LLM provider.
/// Follows priority: Apple On-Device -> Cloud Provider -> Deterministic Mock Fallback.
public final class LLMRouter: @unchecked Sendable {

    private let appleOnDevice: (any LLMProvider)?
    private let cloud: (any LLMProvider)?
    private let mock: (any LLMProvider)?
    private let isEnabledOverride: Bool?

    public init(
        appleOnDevice: (any LLMProvider)? = AppleOnDeviceProvider(),
        cloud: (any LLMProvider)? = CloudLLMProvider(),
        mock: (any LLMProvider)? = MockLLMProvider(),
        isEnabled: Bool? = nil
    ) {
        self.appleOnDevice = appleOnDevice
        self.cloud = cloud
        self.mock = mock
        self.isEnabledOverride = isEnabled
    }

    /// True if the user has enabled AI features (respects settings kill-switch).
    public var isEnabled: Bool {
        if let explicit = isEnabledOverride {
            return explicit
        }
        // Defaults to true unless explicitly disabled in UserDefaults
        if UserDefaults.standard.object(forKey: "orchard.ai.is_enabled") != nil {
            return UserDefaults.standard.bool(forKey: "orchard.ai.is_enabled")
        }
        return true
    }

    /// Selects the highest-priority active provider.
    public func activeProvider() async -> (any LLMProvider)? {
        guard isEnabled else { return nil }

        if let onDevice = appleOnDevice, await onDevice.isAvailable() {
            return onDevice
        }

        if let cloudProvider = cloud, await cloudProvider.isAvailable() {
            return cloudProvider
        }

        if let mockProvider = mock, await mockProvider.isAvailable() {
            return mockProvider
        }

        return nil
    }

    /// Generates structured output using the best available provider.
    public func generate<T: Decodable & Sendable>(
        prompt: String,
        systemPrompt: String = "You are Orchard's nutrition assistant.",
        schema: T.Type
    ) async throws -> T {
        guard isEnabled else {
            throw LLMError.unavailable("AI assistant is disabled by user in Settings.")
        }

        guard let provider = await activeProvider() else {
            throw LLMError.unavailable("No AI provider is currently available.")
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            let result = try await provider.generate(prompt: prompt, systemPrompt: systemPrompt, schema: schema)
            let durationMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            await TelemetryService.shared.log(
                event: .aiRequestExecuted(tool: provider.id, durationMs: durationMs, success: true)
            )

            return result
        } catch {
            let durationMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            await TelemetryService.shared.log(
                event: .aiRequestExecuted(tool: provider.id, durationMs: durationMs, success: false)
            )
            throw error
        }
    }
}
