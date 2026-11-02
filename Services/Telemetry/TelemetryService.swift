import Foundation

/// Structured telemetry event record for privacy-preserving local diagnostics.
public struct TelemetryEvent: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var type: String
    public var parameters: [String: String]?

    public init(type: String, parameters: [String: String]? = nil, timestamp: Date = Date()) {
        self.type = type
        self.parameters = parameters
        self.timestamp = timestamp
    }

    // Factory methods for standardized events
    public static var appLaunched: TelemetryEvent {
        TelemetryEvent(type: "appLaunched")
    }

    public static func templateSelected(name: String) -> TelemetryEvent {
        TelemetryEvent(type: "templateSelected", parameters: ["name": name])
    }

    public static func mealLogged(itemId: String, status: String) -> TelemetryEvent {
        TelemetryEvent(type: "mealLogged", parameters: ["itemId": itemId, "status": status])
    }

    public static func notificationDelivered(category: String) -> TelemetryEvent {
        TelemetryEvent(type: "notificationDelivered", parameters: ["category": category])
    }

    public static func notificationTapped(category: String) -> TelemetryEvent {
        TelemetryEvent(type: "notificationTapped", parameters: ["category": category])
    }

    public static func signingCheck(hoursRemaining: Double) -> TelemetryEvent {
        TelemetryEvent(type: "signingCheck", parameters: ["hoursRemaining": String(format: "%.1f", hoursRemaining)])
    }

    public static func aiRequestExecuted(tool: String, durationMs: Double, success: Bool) -> TelemetryEvent {
        TelemetryEvent(type: "aiRequestExecuted", parameters: [
            "tool": tool,
            "durationMs": String(format: "%.1f", durationMs),
            "success": String(success)
        ])
    }

    public static func healthSyncCompleted(samplesCount: Int) -> TelemetryEvent {
        TelemetryEvent(type: "healthSyncCompleted", parameters: ["samplesCount": String(samplesCount)])
    }
}

/// Protocol for local telemetry logging and diagnostics.
public protocol TelemetryServiceProtocol: Sendable {
    func log(event: TelemetryEvent) async
    func exportLogs() async -> URL?
    func getRecentEvents(limit: Int) async -> [TelemetryEvent]
    func clearLogs() async
}

/// Production implementation of privacy-preserving local telemetry.
/// Writes append-only JSONL to Application Support directory with automatic 1000-event rotation.
public actor TelemetryService: TelemetryServiceProtocol {

    public static let shared = TelemetryService()

    private let fileURL: URL
    private let maxCapacity: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL? = nil, maxEventCapacity: Int = 1000) {
        self.maxCapacity = maxEventCapacity

        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        self.encoder = jsonEncoder

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        self.decoder = jsonDecoder

        if let explicitURL = fileURL {
            self.fileURL = explicitURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let orchardDir = appSupport.appendingPathComponent("Orchard", isDirectory: true)
            try? FileManager.default.createDirectory(at: orchardDir, withIntermediateDirectories: true)
            self.fileURL = orchardDir.appendingPathComponent("telemetry.jsonl")
        }
    }

    public func log(event: TelemetryEvent) async {
        guard let data = try? encoder.encode(event),
              var line = String(data: data, encoding: .utf8) else {
            return
        }
        line.append("\n")

        // Ensure parent directory exists
        let parentDir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        if let lineData = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(lineData)
                    try? fileHandle.close()
                }
            } else {
                try? lineData.write(to: fileURL, options: .atomic)
            }
        }

        // Check rotation if capacity exceeded
        rotateLogsIfNeeded()
    }

    public func getRecentEvents(limit: Int = 50) async -> [TelemetryEvent] {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }

        let lines = content.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var events: [TelemetryEvent] = []

        for line in lines {
            if let data = String(line).data(using: .utf8),
               let event = try? decoder.decode(TelemetryEvent.self, from: data) {
                events.append(event)
            }
        }

        if limit > 0 && events.count > limit {
            return Array(events.suffix(limit))
        }
        return events
    }

    public func exportLogs() async -> URL? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return fileURL
    }

    public func clearLogs() async {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func rotateLogsIfNeeded() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return
        }

        let lines = content.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if lines.count > maxCapacity {
            let preservedLines = lines.suffix(maxCapacity)
            let updatedContent = preservedLines.joined(separator: "\n") + "\n"
            try? updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}
