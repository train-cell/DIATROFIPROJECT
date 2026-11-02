import Foundation

/// Pure Swift loader for decoding `Plan` models from JSON data or files.
public struct PlanLoader {

    public enum LoaderError: Error, LocalizedError {
        case fileNotFound(String)
        case decodingFailed(Error)

        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "Plan JSON file not found at path: \(path)"
            case .decodingFailed(let error):
                return "Failed to decode Plan JSON: \(error.localizedDescription)"
            }
        }
    }

    /// Decodes a Plan from raw JSON Data.
    public static func loadPlan(from data: Data) throws -> Plan {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(Plan.self, from: data)
        } catch {
            throw LoaderError.decodingFailed(error)
        }
    }

    /// Decodes a Plan from a file URL.
    public static func loadPlan(from fileURL: URL) throws -> Plan {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw LoaderError.fileNotFound(fileURL.path)
        }
        let data = try Data(contentsOf: fileURL)
        return try loadPlan(from: data)
    }

    /// Decodes a Plan from a file path string.
    public static func loadPlan(fromFilePath path: String) throws -> Plan {
        let url = URL(fileURLWithPath: path)
        return try loadPlan(from: url)
    }
}
