import Foundation

/// Result of domain validation checks (AI proposals, plan imports, schedule adjustments).
public enum ValidationResult: Equatable, Sendable {
    case valid
    case warning(reasons: [String])
    case invalid(reasons: [String])

    /// True if the result is valid or has only non-blocking warnings.
    public var isValid: Bool {
        if case .invalid = self { return false }
        return true
    }

    /// All issues (warnings or invalid reasons).
    public var issues: [String] {
        switch self {
        case .valid:
            return []
        case .warning(let reasons):
            return reasons
        case .invalid(let reasons):
            return reasons
        }
    }
}
