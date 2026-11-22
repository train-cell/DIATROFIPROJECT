import XCTest

final class OrchardE2EUITests: XCTestCase {
    private var app: XCUIApplication!

    enum TabName {
        case today, log, insights, plan, settings

        var greek: String {
            switch self {
            case .today: return "Σήμερα"
            case .log: return "Καταγραφή"
            case .insights: return "Στατιστικά"
            case .plan: return "Πρόγραμμα"
            case .settings: return "Ρυθμίσεις"
            }
        }

        var english: String {
            switch self {
            case .today: return "Today"
            case .log: return "Log"
            case .insights: return "Insights"
            case .plan: return "Plan"
            case .settings: return "Settings"
            }
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(el)", "-AppleLocale", "el_GR"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "App failed to launch")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation & Scroll Helpers
    @MainActor
    private func navigateToTab(_ tab: TabName) {
        let greekBtn = app.tabBars.buttons[tab.greek]
        let englishBtn = app.tabBars.buttons[tab.english]

        if greekBtn.exists {
            greekBtn.tap()
        } else if englishBtn.exists {
            englishBtn.tap()
        } else if greekBtn.waitForExistence(timeout: 3) {
            greekBtn.tap()
        } else if englishBtn.waitForExistence(timeout: 3) {
            englishBtn.tap()
        } else {
            let idx: Int
            switch tab {
            case .today: idx = 0
            case .log: idx = 1
            case .insights: idx = 2
            case .plan: idx = 3
            case .settings: idx = 4
            }
            let btn = app.tabBars.buttons.element(boundBy: idx)
            if btn.waitForExistence(timeout: 3) {
                btn.tap()
            }
        }
    }

    @MainActor
    private func isWithinScreen(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        let windowBounds = app.windows.firstMatch.frame
        return frame.minX >= 10 && frame.maxX <= (windowBounds.width - 10) && frame.minY >= 50 && frame.maxY <= (windowBounds.height - 50)
    }

    @MainActor
    private func tapDayTemplateChip(matching labelSubstring: String) {
        let chip = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", labelSubstring)).firstMatch
        guard chip.waitForExistence(timeout: 5) else {
            XCTFail("Template chip matching '\(labelSubstring)' not found")
            return
        }

        let window = app.windows.firstMatch
        let windowWidth = window.frame.width

        for _ in 0..<6 {
            let frame = chip.frame
            if frame.minX >= 15 && frame.maxX <= (windowWidth - 15) {
                chip.tap()
                return
            }

            let y = (frame.midY > 80 && frame.midY < 350) ? frame.midY : 170.0
            if frame.minX < 15 {
                // Scrolled too far right -> drag right to reveal left items
                let start = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 60, dy: y))
                let end = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: windowWidth - 60, dy: y))
                start.press(forDuration: 0.05, thenDragTo: end)
            } else {
                // Scrolled too far left -> drag left to reveal right items
                let start = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: windowWidth - 60, dy: y))
                let end = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 60, dy: y))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
        }

        chip.tap()
    }

    @MainActor
    private func resetWaterIfActive() {
        let predicateBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'βέλος' OR label CONTAINS[c] 'counterclockwise' OR label CONTAINS[c] 'arrow' OR label CONTAINS[c] 'επαναφορά'")).firstMatch
        if predicateBtn.exists {
            predicateBtn.tap()
            return
        }

        let high5Btn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'HIGH5+BCAA'")).firstMatch
        guard high5Btn.exists else { return }
        let high5Frame = high5Btn.frame
        let trailingButtons = app.buttons.allElementsBoundByIndex.filter { btn in
            abs(btn.frame.midY - high5Frame.midY) < 15 && btn.frame.minX > high5Frame.maxX
        }
        if let resetBtn = trailingButtons.first {
            resetBtn.tap()
        }
    }

    @MainActor
    private func isSwitchOn(_ element: XCUIElement) -> Bool {
        if let str = element.value as? String {
            return str == "1" || str.lowercased() == "on"
        }
        if let num = element.value as? NSNumber {
            return num.boolValue
        }
        return String(describing: element.value) == "1"
    }

    @MainActor
    private func gentleScrollDown() {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    @MainActor
    private func scrollDownToFind(predicate: NSPredicate, maxScrolls: Int = 4) -> XCUIElement {
        let element = app.staticTexts.matching(predicate).firstMatch
        if element.exists {
            return element
        }
        for _ in 0..<maxScrolls {
            gentleScrollDown()
            if element.exists {
                return element
            }
        }
        return element
    }

    // MARK: - Flow 1: Today — Default State & Hydration
    @MainActor
    func testFlow1_TodayDefaultStateAndHydration() throws {
        navigateToTab(.today)

        // 1. Verify default Day Mode: "Προπόνηση (Τεχνική Κολύμβηση)"
        let trainingChip = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Προπόνηση'")).firstMatch
        XCTAssertTrue(trainingChip.waitForExistence(timeout: 5), "Training day chip should exist")

        // 2. Verify Hydration target: 3.0 L or 3,0 L
        let hydrationHeader = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '3.0' OR label CONTAINS '3,0'")).firstMatch
        XCTAssertTrue(hydrationHeader.waitForExistence(timeout: 5), "Hydration target 3.0 L should be displayed")

        // 3. Verify Supps count indicator exists
        let suppsLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Supps'")).firstMatch
        XCTAssertTrue(suppsLabel.waitForExistence(timeout: 5), "Supps indicator should be displayed")

        // 4. Verify Fasting card is HIDDEN by default
        let fastingCardTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '16/8 Fasting' OR label CONTAINS 'Νηστεία' OR label CONTAINS 'Παράθυρο Διατροφής'")).firstMatch
        XCTAssertFalse(fastingCardTitle.exists, "Fasting card should be hidden by default")

        // 5. Ensure starting clean at 0.00 L
        resetWaterIfActive()

        // Test Hydration buttons: +500 ml and HIGH5+BCAA
        let plus500Btn = app.buttons["+500 ml"]
        XCTAssertTrue(plus500Btn.waitForExistence(timeout: 3), "+500 ml button should exist")
        plus500Btn.tap()

        let high5Btn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'HIGH5+BCAA'")).firstMatch
        XCTAssertTrue(high5Btn.waitForExistence(timeout: 3), "HIGH5+BCAA button should exist")
        high5Btn.tap()

        // 6. Verify water increased to 1.00 / 3.00 L (or 1,00 / 3,00 L in Greek locale)
        let waterCurrent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1.00' OR label CONTAINS '1,00' OR label CONTAINS '1.0' OR label CONTAINS '1,0'")).firstMatch
        XCTAssertTrue(waterCurrent.waitForExistence(timeout: 4), "Water intake should reach 1.00 L")

        // 7. Reset water intake
        resetWaterIfActive()
        let waterReset = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '0.00' OR label CONTAINS '0,00'")).firstMatch
        XCTAssertTrue(waterReset.waitForExistence(timeout: 4), "Water intake should reset to 0.00 L")
    }

    // MARK: - Flow 2: Today — Day Mode Switching
    @MainActor
    func testFlow2_TodayDayModeSwitching() throws {
        navigateToTab(.today)

        // 1. Switch to "Ανάπαυση" -> verify 2.5 L target
        tapDayTemplateChip(matching: "Ανάπαυση")
        let restHydration = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '2.5' OR label CONTAINS '2,5'")).firstMatch
        XCTAssertTrue(restHydration.waitForExistence(timeout: 4), "Rest day hydration target should be 2.5 L")

        // 2. Switch to "Προ Αγώνα (48h)" -> verify pre-race plan
        tapDayTemplateChip(matching: "Προ Αγώνα")
        let preRaceBanner = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Προ Αγώνα' OR label CONTAINS 'Υδατανθράκωση'")).firstMatch
        XCTAssertTrue(preRaceBanner.waitForExistence(timeout: 4), "Pre-race confirmation or plan should appear")

        // 3. Switch to "Ημέρα Αγώνα" -> verify "ΠΑΚΕΤΟ"
        tapDayTemplateChip(matching: "Ημέρα Αγώνα")
        let paketoText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'ΠΑΚΕΤΟ'")).firstMatch
        XCTAssertTrue(paketoText.waitForExistence(timeout: 4), "Race Day should show 'ΠΑΚΕΤΟ'")

        // 4. Switch to "Διπλή Προπόνηση" -> verify 3.5 L target
        tapDayTemplateChip(matching: "Διπλή Προπόνηση")
        let doubleHydration = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '3.5' OR label CONTAINS '3,5'")).firstMatch
        XCTAssertTrue(doubleHydration.waitForExistence(timeout: 4), "Double training hydration target should be 3.5 L")

        // 5. Return to "Προπόνηση (Τεχνική Κολύμβηση)"
        tapDayTemplateChip(matching: "Προπόνηση")
        let defaultHydration = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '3.0' OR label CONTAINS '3,0'")).firstMatch
        XCTAssertTrue(defaultHydration.waitForExistence(timeout: 4), "Should return to 3.0 L hydration target")
    }

    // MARK: - Flow 3: Today — Menu-Picker Sheet + Meal Log + Supplement Auto-Water + Undo
    @MainActor
    func testFlow3_TodayMenuOptionPickerAndMealLogAndUndo() throws {
        navigateToTab(.today)

        // Find Menu button (either in nowNextCard or scroll down into timeline)
        var menuBtn = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Μενού'")).firstMatch
        if !menuBtn.exists {
            app.swipeUp()
            menuBtn = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Μενού'")).firstMatch
        }
        XCTAssertTrue(menuBtn.waitForExistence(timeout: 5), "A Menu options button should be accessible")
        menuBtn.tap()

        // Verify MenuOptionPickerSheet opens
        let sheetNav = app.navigationBars["Επιλογή Μενού"]
        let sheetTitle = app.staticTexts["Επιλογή Μενού"]
        XCTAssertTrue(sheetNav.waitForExistence(timeout: 5) || sheetTitle.waitForExistence(timeout: 5), "MenuOptionPickerSheet should be presented")

        // Verify categories exist
        let categoryHeader = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'ΕΠΙΛΟΓ' OR label CONTAINS[c] 'ΧΥΜΟΣ' OR label CONTAINS[c] 'ΑΛΜΥΡΟ' OR label CONTAINS[c] 'ΤΥΡΙ' OR label CONTAINS[c] 'ΚΟΤΟΠΟΥΛΟ'")).firstMatch
        XCTAssertTrue(categoryHeader.waitForExistence(timeout: 3), "Sheet should contain option categories")

        // Tap "Επιλογή & Καταγραφή ✅"
        let logChoiceBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Επιλογή & Καταγραφή'")).firstMatch
        XCTAssertTrue(logChoiceBtn.waitForExistence(timeout: 4), "Select & Log button should exist")
        logChoiceBtn.tap()

        // Verify logged state in Today
        let eatenIndicator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Έφαγες ✅' OR label CONTAINS 'Έφαγα ✅'")).firstMatch
        XCTAssertTrue(eatenIndicator.waitForExistence(timeout: 5), "Meal should show logged as eaten")

        // Now test liquid supplement auto-water + undo
        let takeSuppBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Πήρα'")).firstMatch
        if takeSuppBtn.waitForExistence(timeout: 4) {
            takeSuppBtn.tap()

            // Verify completed supplement indicator
            let suppTaken = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Πήρες ✅' OR label CONTAINS 'Πήρα ✅'")).firstMatch
            XCTAssertTrue(suppTaken.waitForExistence(timeout: 4), "Supplement should show as taken")

            // Test Undo button
            let undoBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'uturn' OR label CONTAINS 'arrow'")).firstMatch
            if undoBtn.waitForExistence(timeout: 4) {
                undoBtn.tap()
            }
        }
    }

    // MARK: - Flow 4: Plan Tab — All 5 Modes & Expandable Options
    @MainActor
    func testFlow4_PlanTabModesAndExpandableOptions() throws {
        navigateToTab(.plan)

        // Verify templates carousel
        let carouselHeader = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'ΠΡΟΓΡΑΜΜΑΤΑ ΗΜΕΡΑΣ'")).firstMatch
        XCTAssertTrue(carouselHeader.waitForExistence(timeout: 5), "Templates carousel header should exist")

        // Verify modes exist
        let modes = ["Προπόνηση", "Διπλή Προπόνηση", "Προ Αγώνα", "Ημέρα Αγώνα", "Ανάπαυση"]
        for mode in modes {
            let chip = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", mode)).firstMatch
            XCTAssertTrue(chip.waitForExistence(timeout: 3), "Plan carousel chip '\(mode)' should exist")
        }

        // Tap "Διπλή Προπόνηση" to check 2 training sessions
        tapDayTemplateChip(matching: "Διπλή Προπόνηση")
        gentleScrollDown()

        let session1 = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Προπόνηση #1' OR label CONTAINS '08:30'")).firstMatch
        let session2 = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Προπόνηση #2' OR label CONTAINS '14:30'")).firstMatch
        XCTAssertTrue(session1.waitForExistence(timeout: 4), "Workout session #1 should exist in Double Training")
        XCTAssertTrue(session2.waitForExistence(timeout: 4), "Workout session #2 should exist in Double Training")

        // Switch back to "Προπόνηση" to check expandable options
        tapDayTemplateChip(matching: "Προπόνηση")

        // Find an expandable options button
        var expandBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Εναλλακτικές Επιλογές Μενού'")).firstMatch
        if !expandBtn.exists {
            app.swipeUp()
            expandBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Εναλλακτικές Επιλογές Μενού'")).firstMatch
        }
        if expandBtn.waitForExistence(timeout: 4) {
            expandBtn.tap()
            let optionDetail = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'P:' OR label CONTAINS 'kcal'")).firstMatch
            XCTAssertTrue(optionDetail.waitForExistence(timeout: 3), "Expanded options details should be displayed")
            // Collapse
            expandBtn.tap()
        }
    }

    // MARK: - Flow 5: Log Tab — New Protocol Suggestions
    @MainActor
    func testFlow5_LogTabProtocolSuggestions() throws {
        navigateToTab(.log)

        // Select "Συμπλήρωμα" in the category picker
        let suppSegment = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Συμπλήρωμα' OR label CONTAINS 'Supplement'")).firstMatch
        XCTAssertTrue(suppSegment.waitForExistence(timeout: 4), "Supplement segmented button should exist")
        suppSegment.tap()

        // Verify chips: HIGH5+BCAA, Πρωτεΐνη AFTER, V2000 SOLGAR, Solumag
        let high5Chip = app.buttons.matching(NSPredicate(format: "label CONTAINS 'HIGH5'")).firstMatch
        let afterProteinChip = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Πρωτεΐνη AFTER'")).firstMatch
        let v2000Chip = app.buttons.matching(NSPredicate(format: "label CONTAINS 'V2000 SOLGAR'")).firstMatch
        let solumagChip = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Solumag'")).firstMatch

        XCTAssertTrue(high5Chip.waitForExistence(timeout: 3), "HIGH5 chip should exist")
        XCTAssertTrue(afterProteinChip.waitForExistence(timeout: 3), "AFTER Protein chip should exist")
        XCTAssertTrue(v2000Chip.waitForExistence(timeout: 3), "V2000 SOLGAR chip should exist")
        XCTAssertTrue(solumagChip.waitForExistence(timeout: 3), "Solumag chip should exist")

        // Verify 0 mentions of Bolero
        let boleroElement = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Bolero'")).element
        let boleroButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Bolero'")).element
        XCTAssertFalse(boleroElement.exists, "Bolero static text should not exist")
        XCTAssertFalse(boleroButton.exists, "Bolero button should not exist")
    }

    @MainActor
    private func tapSwitch(_ switchElement: XCUIElement) {
        switchElement.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
    }

    @MainActor
    private func scrollToTop() {
        let window = app.windows.firstMatch
        for _ in 0..<3 {
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
            let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    // MARK: - Flow 6: Settings ON/OFF Toggles <-> Live Today & Insights Reflection
    @MainActor
    func testFlow6_SettingsTogglesAndLiveReflection() throws {
        // Ensure starting clean: toggle OFF if previously left ON
        navigateToTab(.settings)
        let fastingPicker = app.staticTexts["Πρωτόκολλο"]
        let fastingSwitch = app.switches["Διαλειμματική Νηστεία (Fasting)"]
        if fastingPicker.exists && fastingSwitch.exists {
            tapSwitch(fastingSwitch)
        }

        let coachingPicker = app.staticTexts["Στόχος Coaching"]
        let coachingSwitch = app.switches["Στόχος Βάρους & Coaching"]
        if coachingPicker.exists && coachingSwitch.exists {
            tapSwitch(coachingSwitch)
        }

        // 1. Go to Insights -> verify Goal Projection & Coaching are disabled (OFF state)
        navigateToTab(.insights)
        gentleScrollDown()

        let disabledNotice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Ανενεργό'")).firstMatch
        XCTAssertTrue(disabledNotice.waitForExistence(timeout: 5), "Goal Projection / Coaching should be inactive by default")

        // 2. Go to Settings -> toggle ON Fasting and Goal Tracking & Coaching
        navigateToTab(.settings)
        XCTAssertTrue(fastingSwitch.waitForExistence(timeout: 5), "Fasting switch should exist")
        if !fastingPicker.exists {
            tapSwitch(fastingSwitch)
        }
        XCTAssertTrue(fastingPicker.waitForExistence(timeout: 4), "Fasting protocol picker should appear when Fasting is turned ON")

        XCTAssertTrue(coachingSwitch.waitForExistence(timeout: 5), "Coaching switch should exist")
        if !coachingPicker.exists {
            tapSwitch(coachingSwitch)
        }
        XCTAssertTrue(coachingPicker.waitForExistence(timeout: 4), "Coaching goal picker should appear when Coaching is turned ON")

        // 3. Return to Today -> verify Fasting card APPEARED
        navigateToTab(.today)
        scrollToTop()
        gentleScrollDown()

        let fastingCard = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Νηστεία' OR label CONTAINS 'Παράθυρο' OR label CONTAINS 'Leangains' OR label CONTAINS '16:8'")).firstMatch
        XCTAssertTrue(fastingCard.waitForExistence(timeout: 5), "Fasting card should appear when enabled")

        // 4. Go to Insights -> verify Goal Weight Projection & Coaching Check-In APPEARED
        navigateToTab(.insights)
        let goalWeightActive = scrollDownToFind(predicate: NSPredicate(format: "label CONTAINS 'ΠΡΟΒΟΛΗ ΣΤΟΧΟΥ ΒΑΡΟΥΣ'"), maxScrolls: 4)
        XCTAssertTrue(goalWeightActive.waitForExistence(timeout: 5), "Goal Weight Projection should be active")

        let coachingActive = scrollDownToFind(predicate: NSPredicate(format: "label CONTAINS 'SMART WEEKLY COACHING CHECK-IN'"), maxScrolls: 4)
        XCTAssertTrue(coachingActive.waitForExistence(timeout: 5), "Smart Weekly Coaching should be active")

        // 5. Clean State: return to Settings and turn both OFF
        navigateToTab(.settings)
        if fastingPicker.exists && fastingSwitch.exists {
            tapSwitch(fastingSwitch)
        }
        if coachingPicker.exists && coachingSwitch.exists {
            tapSwitch(coachingSwitch)
        }
    }

    // MARK: - Flow 7: AI Nutrition Coach Chat Sheet
    @MainActor
    func testFlow7_AICoachChatView() throws {
        navigateToTab(.today)

        // 1. Locate and tap AI Coach toolbar button
        let aiButton = app.buttons["ai_coach_button"]
        XCTAssertTrue(aiButton.waitForExistence(timeout: 5), "AI Coach button ('ai_coach_button') should exist in TodayView toolbar")
        aiButton.tap()

        // 2. Verify AICoachChatView opens
        let chatTitle = app.staticTexts["AI Nutrition Coach ✨"]
        XCTAssertTrue(chatTitle.waitForExistence(timeout: 5), "AI Coach chat sheet should open with title")

        // 3. Verify Auto-Log toggle exists
        let autoLogToggle = app.switches.matching(NSPredicate(format: "label CONTAINS 'Auto-Log'")).firstMatch
        XCTAssertTrue(autoLogToggle.waitForExistence(timeout: 4), "Auto-Log toggle should be present in AI Coach subheader")

        // 4. Verify Greek starter prompt chips exist
        let starterPrompt = app.buttons.matching(NSPredicate(format: "label CONTAINS 'ταπεράκι' OR label CONTAINS 'προπόνηση' OR label CONTAINS '500άρι'")).firstMatch
        XCTAssertTrue(starterPrompt.waitForExistence(timeout: 4), "Starter prompts in Greek should be displayed when chat is empty")

        // 5. Verify BYOK API Key indication (either active BYOK or Missing Key warning - 0 crash / 0 hallucination)
        let keyStatus = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Gemini' OR label CONTAINS 'API Key'")).firstMatch
        XCTAssertTrue(keyStatus.waitForExistence(timeout: 4), "BYOK status indicator should be visible")

        // 6. Dismiss the sheet
        let closeBtn = app.buttons["Κλείσιμο"]
        if closeBtn.waitForExistence(timeout: 3) {
            closeBtn.tap()
        }
    }


}
