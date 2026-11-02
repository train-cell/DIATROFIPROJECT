import Foundation
#if canImport(OrchardDomain)
import OrchardDomain
#endif

/// Warning level for developer signing certificate expiration.
public enum SigningWarningLevel: String, Sendable, Equatable {
    case none
    case warn24h
    case critical2h
    case expired
}

/// Monitors the 7-day personal Apple ID sideloading certificate expiration.
/// Reads `embedded.mobileprovision` to notify the user before the app fails to launch.
public struct SigningGuard: Sendable {

    public static let alert24hIdentifier = "signing.expiry.24h"
    public static let alert2hIdentifier = "signing.expiry.2h"

    public let expirationDate: Date
    private let referenceDate: Date

    public init(
        provisioningPath: String? = nil,
        customExpirationDate: Date? = nil,
        referenceDate: Date = Date()
    ) {
        self.referenceDate = referenceDate

        if let custom = customExpirationDate {
            self.expirationDate = custom
            return
        }

        let path = provisioningPath ?? Bundle.main.path(forResource: "embedded", ofType: "mobileprovision")
        if let validPath = path,
           let data = try? Data(contentsOf: URL(fileURLWithPath: validPath)),
           let parsedExpiry = Self.parseExpirationDate(from: data) {
            self.expirationDate = parsedExpiry
        } else {
            // Fallback: 7 days from reference date (personal Apple ID certificate lifetime)
            self.expirationDate = referenceDate.addingTimeInterval(7 * 86400)
        }
    }

    /// Time remaining until expiration in seconds.
    public func timeRemaining(relativeTo date: Date = Date()) -> TimeInterval {
        return expirationDate.timeIntervalSince(date)
    }

    /// Full days remaining.
    public var daysRemaining: Int {
        let remaining = timeRemaining(relativeTo: referenceDate)
        return max(0, Int(remaining / 86400))
    }

    /// Full hours remaining.
    public var hoursRemaining: Int {
        let remaining = timeRemaining(relativeTo: referenceDate)
        return max(0, Int(remaining / 3600))
    }

    /// True if the certificate has already expired.
    public var isExpired: Bool {
        return timeRemaining(relativeTo: referenceDate) <= 0
    }

    /// Current warning classification based on remaining time.
    public var warningLevel: SigningWarningLevel {
        let remaining = timeRemaining(relativeTo: referenceDate)
        if remaining <= 0 {
            return .expired
        } else if remaining <= 2 * 3600 {
            return .critical2h
        } else if remaining <= 24 * 3600 {
            return .warn24h
        } else {
            return .none
        }
    }

    /// Generates local notification specs for T-24h and T-2h alerts.
    public func makeExpiryAlertSpecs(now: Date = Date()) -> [NotificationSpec] {
        var alerts: [NotificationSpec] = []

        let t24hDate = expirationDate.addingTimeInterval(-24 * 3600)
        if t24hDate > now {
            alerts.append(
                NotificationSpec(
                    identifier: Self.alert24hIdentifier,
                    fireDate: t24hDate,
                    category: NotificationCategory.signingAlert.rawValue,
                    title: "Orchard Signing Expiry (24h)",
                    body: "Your personal developer certificate expires in 24 hours. Connect your iPhone and re-sign from Xcode.",
                    isTimeSensitive: true,
                    itemId: "signing_alert"
                )
            )
        }

        let t2hDate = expirationDate.addingTimeInterval(-2 * 3600)
        if t2hDate > now {
            alerts.append(
                NotificationSpec(
                    identifier: Self.alert2hIdentifier,
                    fireDate: t2hDate,
                    category: NotificationCategory.signingAlert.rawValue,
                    title: "Orchard Signing Expiry Critical (2h)",
                    body: "Your personal certificate expires in 2 hours! Re-sign immediately from Xcode to avoid app shutdown.",
                    isTimeSensitive: true,
                    itemId: "signing_alert"
                )
            )
        }

        return alerts
    }

    /// Extracts the ExpirationDate from raw mobileprovision binary data by carving the inner XML plist.
    public static func parseExpirationDate(from data: Data) -> Date? {
        guard let xmlStartRange = data.range(of: Data("<?xml".utf8)),
              let xmlEndRange = data.range(of: Data("</plist>".utf8), options: .backwards, in: xmlStartRange.lowerBound..<data.count) else {
            return nil
        }

        let plistData = data.subdata(in: xmlStartRange.lowerBound..<xmlEndRange.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let expirationDate = plist["ExpirationDate"] as? Date else {
            return nil
        }

        return expirationDate
    }
}
