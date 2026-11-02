import Foundation

/// Protocol for LLM providers (Apple On-Device Foundation Models, Cloud API, or Mock).
public protocol LLMProvider: Sendable {
    var id: String { get }
    var name: String { get }
    func isAvailable() async -> Bool
    func generate<T: Decodable & Sendable>(prompt: String, systemPrompt: String, schema: T.Type) async throws -> T
}

/// Errors occurring during LLM inference.
public enum LLMError: Error, LocalizedError, Equatable {
    case unavailable(String)
    case requestFailed(String)
    case decodingFailed(String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let name):
            return "LLM Provider '\(name)' is currently unavailable."
        case .requestFailed(let reason):
            return "LLM request failed: \(reason)"
        case .decodingFailed(let reason):
            return "Failed to decode LLM structured response: \(reason)"
        case .invalidResponse(let reason):
            return "Invalid LLM response: \(reason)"
        }
    }
}
