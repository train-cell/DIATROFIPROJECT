import XCTest
@testable import OrchardDomain
@testable import OrchardServices

final class SigningGuardTests: XCTestCase {

    func testParseExpirationDateFromProvisioningData() throws {
        // Construct mock binary CMS envelope with embedded XML plist
        let plistString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>AppIDName</key>
            <string>Orchard</string>
            <key>ExpirationDate</key>
            <date>2026-11-09T20:00:00Z</date>
            <key>Name</key>
            <string>iOS Team Provisioning Profile: com.skyd3n.orchard</string>
        </dict>
        </plist>
        """

        var fakeData = Data([0x30, 0x82, 0x05, 0x00]) // fake CMS header bytes
        fakeData.append(plistString.data(using: .utf8)!)
        fakeData.append(Data([0x00, 0x00, 0x00]))

        let parsedDate = SigningGuard.parseExpirationDate(from: fakeData)
        XCTAssertNotNil(parsedDate)

        let formatter = ISO8601DateFormatter()
        let expectedDate = formatter.date(from: "2026-11-09T20:00:00Z")
        XCTAssertEqual(parsedDate, expectedDate)
    }

    func testFallbackToSevenDaysWhenProvisioningMissing() {
        let referenceNow = Date(timeIntervalSince1970: 1700000000)
        let guardInstance = SigningGuard(
            provisioningPath: "/non/existent/path/embedded.mobileprovision",
            referenceDate: referenceNow
        )

        // Expected expiry is referenceDate + 7 days (604800 seconds)
        let expectedExpiry = referenceNow.addingTimeInterval(7 * 86400)
        XCTAssertEqual(guardInstance.expirationDate.timeIntervalSince1970, expectedExpiry.timeIntervalSince1970, accuracy: 1.0)
    }

    func testWarningLevels() {
        let now = Date(timeIntervalSince1970: 1700000000)

        // 1. More than 24h remaining -> .none
        let guardNormal = SigningGuard(customExpirationDate: now.addingTimeInterval(48 * 3600), referenceDate: now)
        XCTAssertEqual(guardNormal.warningLevel, .none)
        XCTAssertEqual(guardNormal.daysRemaining, 2)

        // 2. 20h remaining -> .warn24h
        let guard24h = SigningGuard(customExpirationDate: now.addingTimeInterval(20 * 3600), referenceDate: now)
        XCTAssertEqual(guard24h.warningLevel, .warn24h)
        XCTAssertEqual(guard24h.hoursRemaining, 20)

        // 3. 1.5h remaining -> .critical2h
        let guard2h = SigningGuard(customExpirationDate: now.addingTimeInterval(90 * 60), referenceDate: now)
        XCTAssertEqual(guard2h.warningLevel, .critical2h)

        // 4. Expired -> .expired
        let guardExpired = SigningGuard(customExpirationDate: now.addingTimeInterval(-60), referenceDate: now)
        XCTAssertEqual(guardExpired.warningLevel, .expired)
        XCTAssertTrue(guardExpired.isExpired)
    }

    func testExpiryAlertSpecsGeneration() {
        let now = Date(timeIntervalSince1970: 1700000000)
        let expiry = now.addingTimeInterval(48 * 3600) // 48h in future
        let guardInstance = SigningGuard(customExpirationDate: expiry, referenceDate: now)

        let alerts = guardInstance.makeExpiryAlertSpecs(now: now)
        XCTAssertEqual(alerts.count, 2)

        // T-24h alert
        XCTAssertEqual(alerts[0].identifier, SigningGuard.alert24hIdentifier)
        XCTAssertEqual(alerts[0].fireDate, expiry.addingTimeInterval(-24 * 3600))
        XCTAssertEqual(alerts[0].category, NotificationCategory.signingAlert.rawValue)

        // T-2h alert
        XCTAssertEqual(alerts[1].identifier, SigningGuard.alert2hIdentifier)
        XCTAssertEqual(alerts[1].fireDate, expiry.addingTimeInterval(-2 * 3600))
        XCTAssertEqual(alerts[1].category, NotificationCategory.signingAlert.rawValue)
    }

    func testExpiryAlertsSuppressPastNotifications() {
        let now = Date(timeIntervalSince1970: 1700000000)
        // Only 10h remaining (T-24h is in the past, T-2h is in the future)
        let expiry = now.addingTimeInterval(10 * 3600)
        let guardInstance = SigningGuard(customExpirationDate: expiry, referenceDate: now)

        let alerts = guardInstance.makeExpiryAlertSpecs(now: now)
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts[0].identifier, SigningGuard.alert2hIdentifier)
        XCTAssertEqual(alerts[0].fireDate, expiry.addingTimeInterval(-2 * 3600))
    }
}
