import XCTest
@testable import OrchardDomain
@testable import OrchardServices

final class AICoachDomainTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDate(year: Int = 2026, month: Int = 11, day: Int = 2, hour: Int = 12, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }

    private func loadRealPlan() throws -> Plan {
        let currentFileUrl = URL(fileURLWithPath: #filePath)
        let rootDir = currentFileUrl.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let realPlanUrl = rootDir.appendingPathComponent("plan.json")
        let data = try Data(contentsOf: realPlanUrl)
        return try JSONDecoder().decode(Plan.self, from: data)
    }

    // MARK: - 1. NutritionContextBuilder Tests

    func testSystemPromptContainsFullPlanAndSettings() throws {
        let plan = try loadRealPlan()
        let mondayDate = makeDate(year: 2026, month: 11, day: 2, hour: 10, minute: 30) // Monday

        let resolvedEvents = ScheduleResolver.resolve(date: mondayDate, plan: plan, calendar: calendar)

        let snapshot = AICoachDailySnapshot(
            date: mondayDate,
            weekday: .mon,
            selectedTemplateKey: "training",
            resolvedEvents: resolvedEvents,
            logEntries: [],
            waterIntakeMl: 500.0,
            targetWaterMl: 3000.0,
            selectedOptionIds: ["sandwich": "sw_opt_1"]
        )

        let prompt = NutritionContextBuilder.buildSystemPrompt(plan: plan, snapshot: snapshot)

        // Must contain athlete settings & plan label
        XCTAssertTrue(prompt.contains(plan.settings.sport ?? "Τεχνική Κολύμβηση"))
        XCTAssertTrue(prompt.contains("10:30"), "Must include wake time")
        XCTAssertTrue(prompt.contains("23:30"), "Must include bed time")
        XCTAssertTrue(prompt.contains("3000"), "Must include target water")

        // Must contain all 5 templates
        XCTAssertTrue(prompt.contains("training"))
        XCTAssertTrue(prompt.contains("double_training"))
        XCTAssertTrue(prompt.contains("pre_race"))
        XCTAssertTrue(prompt.contains("race_day"))
        XCTAssertTrue(prompt.contains("rest"))

        // Must contain key protocol supplements & meals
        XCTAssertTrue(prompt.contains("SOLGAR") || prompt.contains("v2000"))
        XCTAssertTrue(prompt.contains("HIGH5"))
        XCTAssertTrue(prompt.contains("AFTER"))
        XCTAssertTrue(prompt.contains("FERRO SANOL"))
        XCTAssertTrue(prompt.contains("Solumag"))
        XCTAssertTrue(prompt.contains("Ομελέτα Βρώμης") || prompt.contains("tupper1"))

        // Must contain current snapshot state
        XCTAssertTrue(prompt.contains("500") && prompt.contains("3000"), "Must state 500ml / 3000ml water intake")
        XCTAssertTrue(prompt.contains("Monday") || prompt.contains("Δευτέρα"), "Must state current day")
        XCTAssertTrue(prompt.contains("JSON"), "Must specify JSON output schema contract")
    }

    func testSystemPromptHighlightsFerroSanolOnlyOnWednesdayAndFriday() throws {
        let plan = try loadRealPlan()

        // Monday snapshot
        let mondayDate = makeDate(year: 2026, month: 11, day: 2) // Monday
        let mondaySnapshot = AICoachDailySnapshot(
            date: mondayDate,
            weekday: .mon,
            selectedTemplateKey: "training",
            resolvedEvents: ScheduleResolver.resolve(date: mondayDate, plan: plan, calendar: calendar),
            logEntries: [],
            waterIntakeMl: 0,
            targetWaterMl: 3000,
            selectedOptionIds: [:]
        )
        let mondayPrompt = NutritionContextBuilder.buildSystemPrompt(plan: plan, snapshot: mondaySnapshot)
        XCTAssertTrue(mondayPrompt.contains("Τετάρτη") && mondayPrompt.contains("Παρασκευή"), "Must indicate Ferro Sanol is only Wed/Fri")

        // Wednesday snapshot
        let wednesdayDate = makeDate(year: 2026, month: 11, day: 4) // Wednesday
        let wednesdaySnapshot = AICoachDailySnapshot(
            date: wednesdayDate,
            weekday: .wed,
            selectedTemplateKey: "training",
            resolvedEvents: ScheduleResolver.resolve(date: wednesdayDate, plan: plan, calendar: calendar),
            logEntries: [],
            waterIntakeMl: 1000,
            targetWaterMl: 3000,
            selectedOptionIds: [:]
        )
        let wednesdayPrompt = NutritionContextBuilder.buildSystemPrompt(plan: plan, snapshot: wednesdaySnapshot)
        XCTAssertTrue(wednesdayPrompt.contains("ΣΗΜΕΡΑ") || wednesdayPrompt.contains("Τετάρτη"), "Must explicitly mention Ferro Sanol active today")
    }

    // MARK: - 2. AICoachResponseValidator Tests

    func testSanitizeAndHydratePopulatesMissingMacrosFromPlanOption() throws {
        let plan = try loadRealPlan()

        let rawResponse = AICoachResponse(
            replyGreek: "Κατέγραψα το ταπεράκι με τον ψητό σολομό!",
            suggestedActions: [
                AICoachLogAction(
                    id: "act_1",
                    kind: .meal,
                    itemId: "tupper1",
                    selectedOptionId: "tupper_opt_3", // Σολομός 180-200g
                    title: "Tupper #1 με Σολομό",
                    kcal: nil, // Missing from LLM
                    protein: nil,
                    carbs: nil,
                    fat: nil,
                    waterMl: nil,
                    notes: "Φρέσκος σολομός"
                )
            ]
        )

        let hydrated = AICoachResponseValidator.sanitizeAndHydrate(
            response: rawResponse,
            plan: plan,
            templateKey: "training"
        )

        XCTAssertEqual(hydrated.suggestedActions.count, 1)
        let action = hydrated.suggestedActions[0]
        XCTAssertEqual(action.itemId, "tupper1")
        XCTAssertEqual(action.selectedOptionId, "tupper_opt_3")
        XCTAssertEqual(action.kcal, 560.0, "Must hydrate kcal from tupper_opt_3 option (560 kcal)")
        XCTAssertEqual(action.protein, 54.0, "Must hydrate protein from tupper_opt_3 option (54g)")
        XCTAssertEqual(action.carbs, 6.0, "Must hydrate carbs from tupper_opt_3 option (6g)")
        XCTAssertEqual(action.fat, 36.0, "Must hydrate fat from tupper_opt_3 option (36g)")
    }

    func testSanitizeAndHydratePopulatesWaterFromPlanItem() throws {
        let plan = try loadRealPlan()

        let rawResponse = AICoachResponse(
            replyGreek: "Κατέγραψα το μετα-προπονητικό shake!",
            suggestedActions: [
                AICoachLogAction(
                    id: "act_shake",
                    kind: .supplement,
                    itemId: "post_workout_shake",
                    selectedOptionId: nil,
                    title: "Μετα-προπονητικό Shake",
                    kcal: nil,
                    protein: nil,
                    carbs: nil,
                    fat: nil,
                    waterMl: nil, // Missing from LLM
                    notes: nil
                )
            ]
        )

        let hydrated = AICoachResponseValidator.sanitizeAndHydrate(
            response: rawResponse,
            plan: plan,
            templateKey: "training"
        )

        let action = hydrated.suggestedActions[0]
        XCTAssertEqual(action.waterMl, 500.0, "Must hydrate waterMl = 500ml from post_workout_shake PlanItem")
        XCTAssertEqual(action.protein, 30.0, "Must hydrate protein = 30g from post_workout_shake PlanItem")
        XCTAssertEqual(action.kcal, 130.0, "Must hydrate kcal = 130 from post_workout_shake PlanItem")
    }

    func testSanitizeAndHydrateClampsNegativeValuesAndFixesEmptyReply() throws {
        let plan = try loadRealPlan()

        let rawResponse = AICoachResponse(
            replyGreek: "   ", // Empty whitespace reply
            suggestedActions: [
                AICoachLogAction(
                    id: "act_neg",
                    kind: .meal,
                    itemId: nil,
                    selectedOptionId: nil,
                    title: "Custom snack",
                    kcal: -50.0,
                    protein: -10.0,
                    carbs: -5.0,
                    fat: -2.0,
                    waterMl: -250.0,
                    notes: nil
                )
            ]
        )

        let hydrated = AICoachResponseValidator.sanitizeAndHydrate(
            response: rawResponse,
            plan: plan,
            templateKey: "training"
        )

        XCTAssertFalse(hydrated.replyGreek.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let action = hydrated.suggestedActions[0]
        XCTAssertEqual(action.kcal, 0.0)
        XCTAssertEqual(action.protein, 0.0)
        XCTAssertEqual(action.carbs, 0.0)
        XCTAssertEqual(action.fat, 0.0)
        XCTAssertEqual(action.waterMl, 0.0)
    }

    func testSanitizeAndHydrateClampsNaNAndInfinity() throws {
        let plan = try loadRealPlan()

        let rawResponse = AICoachResponse(
            replyGreek: "Έλεγχος NaN / Infinity",
            suggestedActions: [
                AICoachLogAction(
                    id: "act_nan",
                    kind: .meal,
                    itemId: nil,
                    selectedOptionId: nil,
                    title: "Dangerous values",
                    kcal: Double.nan,
                    protein: Double.infinity,
                    carbs: -Double.infinity,
                    fat: Double.nan,
                    waterMl: Double.infinity,
                    notes: nil
                )
            ]
        )

        let hydrated = AICoachResponseValidator.sanitizeAndHydrate(
            response: rawResponse,
            plan: plan,
            templateKey: "training"
        )

        let action = hydrated.suggestedActions[0]
        XCTAssertEqual(action.kcal, 0.0, "NaN kcal must be sanitized to 0.0")
        XCTAssertEqual(action.protein, 0.0, "Infinity protein must be sanitized to 0.0")
        XCTAssertEqual(action.carbs, 0.0, "-Infinity carbs must be sanitized to 0.0")
        XCTAssertEqual(action.fat, 0.0, "NaN fat must be sanitized to 0.0")
        XCTAssertEqual(action.waterMl, 0.0, "Infinity waterMl must be sanitized to 0.0")
    }

    func testChatMessageAppliedLogIdsRoundTrip() throws {
        let message = AICoachChatMessage(
            id: UUID(),
            isUser: false,
            text: "Πρόταση γεύματος",
            timestamp: Date(),
            suggestedActions: [],
            appliedActionIds: ["act_1"],
            appliedLogIds: ["act_1": "manual_12345"],
            modelUsed: "gemini-2.5-flash"
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(AICoachChatMessage.self, from: data)

        XCTAssertEqual(decoded.appliedActionIds, ["act_1"])
        XCTAssertEqual(decoded.appliedLogIds["act_1"], "manual_12345")
    }

    // MARK: - 3. AICoachService Tests

    final class StubLLMProvider: LLMProvider, @unchecked Sendable {
        let id: String = "stub_test"
        let name: String = "Stub Test Provider"
        var isAvailableFlag: Bool = true
        var cannedResponse: String = "{}"

        func isAvailable() async -> Bool { isAvailableFlag }

        func generate<T: Decodable & Sendable>(prompt: String, systemPrompt: String, schema: T.Type) async throws -> T {
            let data = cannedResponse.data(using: .utf8)!
            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    func testAICoachServiceThrowsMissingAPIKeyWhenKeyIsNil() async throws {
        let service = AICoachService.makeLive(apiKeyOverride: nil)
        let plan = try loadRealPlan()
        let snapshot = AICoachDailySnapshot(
            date: Date(),
            weekday: .mon,
            selectedTemplateKey: "training",
            resolvedEvents: [],
            logEntries: [],
            waterIntakeMl: 0,
            targetWaterMl: 3000,
            selectedOptionIds: [:]
        )

        // Make sure no API key is in keychain for this test
        KeychainStore.shared.saveAPIKey("")

        do {
            _ = try await service.sendMessage("Έφαγα ένα τοστ", history: [], plan: plan, snapshot: snapshot)
            XCTFail("Must throw AICoachError.missingAPIKey when API key is missing")
        } catch let error as AICoachError {
            XCTAssertEqual(error, AICoachError.missingAPIKey)
            XCTAssertTrue(error.localizedDescription.contains("Gemini API Key"))
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }

    func testAICoachServiceThrowsWhenAIDisabledInSettings() async throws {
        let stub = StubLLMProvider()
        let router = LLMRouter(gemini: stub, appleOnDevice: nil, cloud: nil, mock: nil, isEnabled: false)
        let service = AICoachService(router: router)

        let plan = try loadRealPlan()
        let snapshot = AICoachDailySnapshot(
            date: Date(),
            weekday: .mon,
            selectedTemplateKey: "training",
            resolvedEvents: [],
            logEntries: [],
            waterIntakeMl: 0,
            targetWaterMl: 3000,
            selectedOptionIds: [:]
        )

        do {
            _ = try await service.sendMessage("Έφαγα ένα μήλο", history: [], plan: plan, snapshot: snapshot)
            XCTFail("Must throw when AI is disabled")
        } catch let error as AICoachError {
            XCTAssertEqual(error, AICoachError.aiDisabled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAICoachServiceSuccessfullyGeneratesAndHydratesResponse() async throws {
        let stub = StubLLMProvider()
        stub.cannedResponse = """
        {
            "replyGreek": "Τέλεια επιλογή για ενέργεια! Κατέγραψα το δεκατιανό sandwich.",
            "suggestedActions": [
                {
                    "id": "act_sandwich",
                    "kind": "meal",
                    "itemId": "sandwich",
                    "selectedOptionId": "sw_opt_1",
                    "title": "Sandwich Cottage & Γαλοπούλα",
                    "kcal": null,
                    "protein": null,
                    "carbs": null,
                    "fat": null,
                    "waterMl": null,
                    "notes": "Επιλογή 1"
                }
            ]
        }
        """

        let router = LLMRouter(gemini: stub, appleOnDevice: nil, cloud: nil, mock: nil, isEnabled: true)
        let service = AICoachService(router: router)

        let plan = try loadRealPlan()
        let snapshot = AICoachDailySnapshot(
            date: Date(),
            weekday: .mon,
            selectedTemplateKey: "training",
            resolvedEvents: ScheduleResolver.resolve(date: Date(), plan: plan, calendar: calendar),
            logEntries: [],
            waterIntakeMl: 250,
            targetWaterMl: 3000,
            selectedOptionIds: [:]
        )

        let response = try await service.sendMessage(
            "Έφαγα το sandwich #1 με cottage και γαλοπούλα",
            history: [],
            plan: plan,
            snapshot: snapshot
        )

        XCTAssertTrue(response.replyGreek.contains("sandwich"))
        XCTAssertEqual(response.suggestedActions.count, 1)

        let action = response.suggestedActions[0]
        XCTAssertEqual(action.itemId, "sandwich")
        XCTAssertEqual(action.selectedOptionId, "sw_opt_1")
        XCTAssertEqual(action.kcal, 340.0, "Hydrated from sw_opt_1")
        XCTAssertEqual(action.protein, 26.0, "Hydrated from sw_opt_1")
    }

    func testEstimateQuickFoodProducesHydratedAction() async throws {
        let stub = StubLLMProvider()
        stub.cannedResponse = """
        {
            "replyGreek": "Εκτίμηση για ομελέτα βρώμης: ~380 kcal.",
            "suggestedActions": [
                {
                    "id": "act_omelet",
                    "kind": "meal",
                    "itemId": "tupper1",
                    "selectedOptionId": "tupper_omelet_pre",
                    "title": "Ομελέτα Βρώμης (Προ-άσκησης)",
                    "kcal": 380.0,
                    "protein": 34.0,
                    "carbs": 44.0,
                    "fat": 7.0,
                    "waterMl": null,
                    "notes": "Αλμυρή ομελέτα βρώμης"
                }
            ]
        }
        """

        let router = LLMRouter(gemini: stub, appleOnDevice: nil, cloud: nil, mock: nil, isEnabled: true)
        let service = AICoachService(router: router)

        let plan = try loadRealPlan()
        let snapshot = AICoachDailySnapshot(
            date: Date(),
            weekday: .mon,
            selectedTemplateKey: "training",
            resolvedEvents: [],
            logEntries: [],
            waterIntakeMl: 0,
            targetWaterMl: 3000,
            selectedOptionIds: [:]
        )

        let response = try await service.estimateQuickFood("Ομελέτα βρώμης με 4 ασπράδια και 40g βρώμη", plan: plan, snapshot: snapshot)
        XCTAssertEqual(response.suggestedActions.count, 1)
        XCTAssertEqual(response.suggestedActions[0].kcal, 380.0)
    }
}
