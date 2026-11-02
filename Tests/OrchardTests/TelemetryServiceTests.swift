import XCTest
@testable import OrchardServices

final class TelemetryServiceTests: XCTestCase {

    func testLogAndRetrieveTelemetryEvents() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logFile = tempDir.appendingPathComponent("telemetry.jsonl")
        let service = TelemetryService(fileURL: logFile)

        await service.log(event: .appLaunched)
        await service.log(event: .templateSelected(name: "training"))
        await service.log(event: .mealLogged(itemId: "breakfast", status: "done"))
        await service.log(event: .healthSyncCompleted(samplesCount: 4))

        let events = await service.getRecentEvents(limit: 10)
        XCTAssertEqual(events.count, 4)

        XCTAssertEqual(events[0].type, "appLaunched")
        XCTAssertEqual(events[1].type, "templateSelected")
        XCTAssertEqual(events[1].parameters?["name"], "training")
        XCTAssertEqual(events[2].type, "mealLogged")
        XCTAssertEqual(events[3].type, "healthSyncCompleted")
    }

    func testRotationAt1000Events() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logFile = tempDir.appendingPathComponent("telemetry_rotate.jsonl")
        let service = TelemetryService(fileURL: logFile, maxEventCapacity: 10)

        // Log 15 events
        for i in 1...15 {
            await service.log(event: .notificationDelivered(category: "cat_\(i)"))
        }

        let events = await service.getRecentEvents(limit: 100)
        XCTAssertEqual(events.count, 10, "Should be capped at maxEventCapacity")
        // Oldest events (1..5) should have been pruned, newest should be cat_15
        XCTAssertEqual(events.last?.parameters?["category"], "cat_15")
    }

    func testExportAndClearLogs() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logFile = tempDir.appendingPathComponent("telemetry_export.jsonl")
        let service = TelemetryService(fileURL: logFile)

        await service.log(event: .signingCheck(hoursRemaining: 48.0))

        let exportUrl = await service.exportLogs()
        XCTAssertNotNil(exportUrl)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportUrl!.path))

        await service.clearLogs()
        let eventsAfterClear = await service.getRecentEvents(limit: 10)
        XCTAssertEqual(eventsAfterClear.count, 0)
    }
}
