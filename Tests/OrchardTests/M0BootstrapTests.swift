import XCTest

final class M0BootstrapTests: XCTestCase {
    func testPlanSampleJsonIsDecodable() throws {
        // Look for plan.sample.json relative to tests or bundle
        let testFileUrl = URL(fileURLWithPath: #filePath)
        let rootDir = testFileUrl.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let planSampleUrl = rootDir.appendingPathComponent("Resources/plan.sample.json")

        XCTAssertTrue(FileManager.default.fileExists(atPath: planSampleUrl.path), "plan.sample.json must exist at Resources/plan.sample.json")

        let data = try Data(contentsOf: planSampleUrl)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = jsonObject as? [String: Any] else {
            XCTFail("plan.sample.json must be a valid JSON dictionary")
            return
        }

        XCTAssertEqual(dict["version"] as? Int, 1)
        XCTAssertNotNil(dict["settings"])
        XCTAssertNotNil(dict["weekly"])
        XCTAssertNotNil(dict["templates"])
    }
}
