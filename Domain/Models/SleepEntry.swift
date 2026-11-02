import Foundation

/// Sleep record captured in the morning, combining user rating and HealthKit sleep duration.
public struct SleepEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date                       // Morning wake-up date
    public var rating: Int                      // 1...5
    public var tags: [String]
    public var note: String?
    public var asleepMinutes: Int?              // Cached asleep duration synced from HealthKit

    public init(
        id: UUID = UUID(),
        date: Date,
        rating: Int,
        tags: [String] = [],
        note: String? = nil,
        asleepMinutes: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.rating = rating
        self.tags = tags
        self.note = note
        self.asleepMinutes = asleepMinutes
    }
}
