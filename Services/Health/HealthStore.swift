import Foundation
#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(OrchardDomain)
import OrchardDomain
#endif

// MARK: - HealthStore Errors

public enum HealthStoreError: Error, LocalizedError, Equatable {
    case healthDataUnavailable
    case notAuthorized
    case sampleNotFound
    case queryFailed(String)
    case underlying(String)

    public var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Apple Health data is unavailable on this device."
        case .notAuthorized:
            return "HealthKit permissions were not granted."
        case .sampleNotFound:
            return "The requested HealthKit sample was not found."
        case .queryFailed(let msg):
            return "HealthKit query failed: \(msg)"
        case .underlying(let msg):
            return msg
        }
    }
}

// MARK: - HealthStore Protocol

public protocol HealthStoreProtocol: Sendable {
    /// Requests user authorization for reading workouts & energy, and writing dietary entries.
    func requestAuthorization() async throws -> Bool

    /// Reads recorded workouts in the specified date range.
    func readWorkouts(from startDate: Date, to endDate: Date) async throws -> [TrainingSession]

    /// Reads basal and active energy burned in the specified date range.
    func readEnergyBurned(from startDate: Date, to endDate: Date) async throws -> EnergyBurned

    /// Reads basal and active energy burned for a single calendar day.
    func readEnergyBurned(for date: Date, calendar: Calendar) async throws -> EnergyBurned

    /// Writes a dietary LogEntry (calories and macros) to Apple Health.
    /// Uses idempotent metadata sync identifier: `HKMetadataKeySyncIdentifier = "orchard.<logEntryId>"`.
    /// Note: Orchard NEVER writes active energy burned to avoid double-counting Apple Watch data.
    @discardableResult
    func writeDietaryLog(_ entry: LogEntry, item: PlanItem?) async throws -> String

    /// Deletes the dietary log matching the sync identifier from HealthKit (Undo functionality).
    func deleteDietaryLog(syncIdentifier: String) async throws

    /// Deletes the dietary log corresponding to the specified LogEntry UUID (Undo functionality).
    func deleteDietaryLog(for entryId: UUID) async throws
}

extension HealthStoreProtocol {
    public func readEnergyBurned(for date: Date, calendar: Calendar = .current) async throws -> EnergyBurned {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return EnergyBurned()
        }
        return try await readEnergyBurned(from: startOfDay, to: endOfDay)
    }

    public func deleteDietaryLog(for entryId: UUID) async throws {
        try await deleteDietaryLog(syncIdentifier: "orchard.\(entryId.uuidString)")
    }
}

// MARK: - Fake Health Store (In-Memory for Previews & Unit Tests)

/// An in-memory dietary sample stored by `FakeHealthStore`.
public struct FakeDietarySample: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var syncIdentifier: String
    public var date: Date
    public var kcal: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    public var logEntryId: UUID

    public init(
        id: UUID = UUID(),
        syncIdentifier: String,
        date: Date,
        kcal: Double,
        protein: Double = 0.0,
        carbs: Double = 0.0,
        fat: Double = 0.0,
        logEntryId: UUID
    ) {
        self.id = id
        self.syncIdentifier = syncIdentifier
        self.date = date
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.logEntryId = logEntryId
    }
}

/// Thread-safe in-memory mock HealthStore actor for previews, simulator, and unit tests.
public actor FakeHealthStore: HealthStoreProtocol {
    public var isAvailable: Bool
    public var isAuthorized: Bool
    public var shouldFailAuthorization: Bool

    public private(set) var savedSamples: [FakeDietarySample]
    public var mockWorkouts: [TrainingSession]
    public var mockEnergyBurned: EnergyBurned
    public var mockEnergyBurnedByDate: [Date: EnergyBurned]

    // Call tracking
    public private(set) var requestAuthorizationCalls: Int
    public private(set) var writeDietaryLogCalls: Int
    public private(set) var deleteDietaryLogCalls: Int

    public init(
        isAvailable: Bool = true,
        isAuthorized: Bool = true,
        shouldFailAuthorization: Bool = false,
        mockWorkouts: [TrainingSession] = [],
        mockEnergyBurned: EnergyBurned = EnergyBurned(),
        mockEnergyBurnedByDate: [Date: EnergyBurned] = [:]
    ) {
        self.isAvailable = isAvailable
        self.isAuthorized = isAuthorized
        self.shouldFailAuthorization = shouldFailAuthorization
        self.mockWorkouts = mockWorkouts
        self.mockEnergyBurned = mockEnergyBurned
        self.mockEnergyBurnedByDate = mockEnergyBurnedByDate
        self.savedSamples = []
        self.requestAuthorizationCalls = 0
        self.writeDietaryLogCalls = 0
        self.deleteDietaryLogCalls = 0
    }

    public func setShouldFailAuthorization(_ value: Bool) {
        self.shouldFailAuthorization = value
    }

    public func setIsAuthorized(_ value: Bool) {
        self.isAuthorized = value
    }

    public func setMockWorkouts(_ workouts: [TrainingSession]) {
        self.mockWorkouts = workouts
    }

    public func setMockEnergyBurned(_ energy: EnergyBurned) {
        self.mockEnergyBurned = energy
    }

    public func setSavedSamples(_ samples: [FakeDietarySample]) {
        self.savedSamples = samples
    }

    public func requestAuthorization() async throws -> Bool {
        requestAuthorizationCalls += 1
        if shouldFailAuthorization {
            throw HealthStoreError.notAuthorized
        }
        return isAuthorized
    }

    public func readWorkouts(from startDate: Date, to endDate: Date) async throws -> [TrainingSession] {
        guard isAuthorized else { throw HealthStoreError.notAuthorized }
        return mockWorkouts.filter { session in
            guard let start = session.startDate else { return false }
            return start >= startDate && start <= endDate
        }
    }

    public func readEnergyBurned(from startDate: Date, to endDate: Date) async throws -> EnergyBurned {
        guard isAuthorized else { throw HealthStoreError.notAuthorized }
        if let match = mockEnergyBurnedByDate.first(where: { $0.key >= startDate && $0.key <= endDate }) {
            return match.value
        }
        return mockEnergyBurned
    }

    public func readEnergyBurned(for date: Date, calendar: Calendar = .current) async throws -> EnergyBurned {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return EnergyBurned()
        }
        return try await readEnergyBurned(from: startOfDay, to: endOfDay)
    }

    @discardableResult
    public func writeDietaryLog(_ entry: LogEntry, item: PlanItem? = nil) async throws -> String {
        writeDietaryLogCalls += 1
        guard isAuthorized else { throw HealthStoreError.notAuthorized }

        let syncId = "orchard.\(entry.id.uuidString)"

        // Idempotency: Always replace any existing sample with this sync identifier
        savedSamples.removeAll { $0.syncIdentifier == syncId }

        // Skipped meals do not add dietary samples
        if entry.status == .skipped {
            return syncId
        }

        let macros = CalorieEngine.consumedMacros(for: entry, baseItem: item)
        if macros.kcal == 0 && macros.protein == 0 && macros.carbs == 0 && macros.fat == 0 {
            return syncId
        }

        let sample = FakeDietarySample(
            syncIdentifier: syncId,
            date: entry.timestamp,
            kcal: macros.kcal,
            protein: macros.protein,
            carbs: macros.carbs,
            fat: macros.fat,
            logEntryId: entry.id
        )
        savedSamples.append(sample)
        return syncId
    }

    public func deleteDietaryLog(syncIdentifier: String) async throws {
        deleteDietaryLogCalls += 1
        savedSamples.removeAll { $0.syncIdentifier == syncIdentifier }
    }

    public func deleteDietaryLog(for entryId: UUID) async throws {
        try await deleteDietaryLog(syncIdentifier: "orchard.\(entryId.uuidString)")
    }
}

// MARK: - Production HealthKit Store

#if canImport(HealthKit)
/// Production HealthKit adapter for iOS and watchOS.
public final class HealthKitStore: HealthStoreProtocol, @unchecked Sendable {
    private let healthStore: HKHealthStore

    public init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    public static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthStoreError.healthDataUnavailable
        }

        guard let dietaryEnergyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
              let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein),
              let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates),
              let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal),
              let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let basalEnergyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else {
            throw HealthStoreError.underlying("Unable to create HealthKit quantity types.")
        }

        let workoutType = HKObjectType.workoutType()

        // Write types: Dietary nutrition only.
        // NOTE: Orchard NEVER writes activeEnergyBurned. This prevents double-counting Apple Watch activity.
        let typesToShare: Set<HKSampleType> = [
            dietaryEnergyType,
            proteinType,
            carbsType,
            fatType
        ]

        // Read types: Workouts and burned energy.
        let typesToRead: Set<HKObjectType> = [
            workoutType,
            activeEnergyType,
            basalEnergyType
        ]

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    public func readWorkouts(from startDate: Date, to endDate: Date) async throws -> [TrainingSession] {
        guard HKHealthStore.isHealthDataAvailable() else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                let sessions = workouts.map { workout -> TrainingSession in
                    let kcal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                    let durationMin = Int(workout.duration / 60.0)
                    let title = Self.formatWorkoutTitle(type: workout.workoutActivityType)

                    return TrainingSession(
                        id: workout.uuid.uuidString,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        durationMinutes: durationMin,
                        estKcal: kcal,
                        actualKcal: kcal,
                        isActual: true,
                        title: title
                    )
                }
                continuation.resume(returning: sessions)
            }
            healthStore.execute(query)
        }
    }

    public func readEnergyBurned(from startDate: Date, to endDate: Date) async throws -> EnergyBurned {
        guard HKHealthStore.isHealthDataAvailable() else {
            return EnergyBurned()
        }

        async let active = querySum(for: .activeEnergyBurned, unit: .kilocalorie(), start: startDate, end: endDate)
        async let basal = querySum(for: .basalEnergyBurned, unit: .kilocalorie(), start: startDate, end: endDate)

        let (activeKcal, basalKcal) = try await (active, basal)
        return EnergyBurned(basalKcal: basalKcal, activeKcal: activeKcal)
    }

    private func querySum(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0.0
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let sum = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }

    @discardableResult
    public func writeDietaryLog(_ entry: LogEntry, item: PlanItem? = nil) async throws -> String {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthStoreError.healthDataUnavailable
        }

        let syncId = "orchard.\(entry.id.uuidString)"

        // Idempotency: Remove any existing samples for this sync identifier first
        try await deleteDietaryLog(syncIdentifier: syncId)

        if entry.status == .skipped {
            return syncId
        }

        let macros = CalorieEngine.consumedMacros(for: entry, baseItem: item)
        if macros.kcal == 0 && macros.protein == 0 && macros.carbs == 0 && macros.fat == 0 {
            return syncId
        }

        let metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: syncId,
            HKMetadataKeySyncVersion: 1
        ]

        var samplesToSave: [HKSample] = []

        if macros.kcal > 0, let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: macros.kcal)
            let sample = HKQuantitySample(type: energyType, quantity: energyQuantity, start: entry.timestamp, end: entry.timestamp, metadata: metadata)
            samplesToSave.append(sample)
        }

        if macros.protein > 0, let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            let quantity = HKQuantity(unit: .gram(), doubleValue: macros.protein)
            let sample = HKQuantitySample(type: proteinType, quantity: quantity, start: entry.timestamp, end: entry.timestamp, metadata: metadata)
            samplesToSave.append(sample)
        }

        if macros.carbs > 0, let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            let quantity = HKQuantity(unit: .gram(), doubleValue: macros.carbs)
            let sample = HKQuantitySample(type: carbsType, quantity: quantity, start: entry.timestamp, end: entry.timestamp, metadata: metadata)
            samplesToSave.append(sample)
        }

        if macros.fat > 0, let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            let quantity = HKQuantity(unit: .gram(), doubleValue: macros.fat)
            let sample = HKQuantitySample(type: fatType, quantity: quantity, start: entry.timestamp, end: entry.timestamp, metadata: metadata)
            samplesToSave.append(sample)
        }

        guard !samplesToSave.isEmpty else {
            return syncId
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.save(samplesToSave) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: syncId)
                }
            }
        }
    }

    public func deleteDietaryLog(syncIdentifier: String) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }

        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, value: syncIdentifier)
        let sampleTypes: [HKSampleType] = [
            HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            HKQuantityType.quantityType(forIdentifier: .dietaryProtein),
            HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates),
            HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal)
        ].compactMap { $0 }

        for sampleType in sampleTypes {
            let samples = try await querySamples(for: sampleType, predicate: predicate)
            if !samples.isEmpty {
                try await deleteSamples(samples)
            }
        }
    }

    private func querySamples(for sampleType: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    private func deleteSamples(_ samples: [HKSample]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.delete(samples) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private static func formatWorkoutTitle(type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength Training"
        case .walking: return "Walking"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .crossTraining: return "Cross Training"
        case .pilates: return "Pilates"
        case .boxing: return "Boxing"
        case .martialArts: return "Martial Arts"
        default: return "Workout"
        }
    }
}
#endif
