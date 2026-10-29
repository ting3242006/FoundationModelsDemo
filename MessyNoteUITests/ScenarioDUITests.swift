import XCTest

final class ScenarioDUITests: XCTestCase {
    @MainActor
    func testCalendarPermissionDeniedPreservesDraft() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.launch()
        app.buttons["設定"].tap()
        let fixture = app.switches["Demo Fixture Mode"]
        try waitFor(fixture, app: app, stage: "D01 launch Real Mode", timeout: 15)
        if fixture.value as? String == "1" {
            fixture.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let off = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: fixture)
        XCTAssertEqual(XCTWaiter.wait(for: [off], timeout: 5), .completed)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.staticTexts["使用系統資料"].exists)

        let calendar = Calendar(identifier: .gregorian)
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: .now))
        let start = try XCTUnwrap(calendar.date(bySettingHour: 16, minute: 0, second: 0, of: tomorrow))
        try submit("明天 16:00 開會，持續 30 分鐘。", app: app, stage: "D03 initial explicit time")
        try waitForGenerationState(app: app, springboard: springboard, stage: "D03c initial generation state")
        let pending = app.staticTexts["尚待時間確認"]
        if pending.exists {
            let fixedDate = app.staticTexts["固定草稿日期：" + tomorrow.formatted(date: .complete, time: .omitted)]
            reveal(fixedDate, app: app)
            XCTAssertTrue(fixedDate.exists, "補充時刻前必須保留原先的明天日期。")
            checkpoint("D03d pending before one natural-language completion", app: app)
            try submit("時間是下午四點整，持續三十分鐘。", app: app, stage: "D03e natural-language completion")
            try waitForGenerationState(app: app, springboard: springboard, stage: "D03f completion state")
            XCTAssertFalse(pending.exists, "一次自然語言補充後仍缺時間，停止並保留診斷；不改用手動picker。")
        }
        XCTAssertFalse(app.staticTexts["需要注意"].exists, "生成出現錯誤，尚未抵達真實權限查詢。")

        // The parent resets permission beforehand. The test must observe and deny a real OS alert.
        var deniedCalendar = false
        for attempt in 1...2 {
            let permission = NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS %@ OR label CONTAINS %@", "calendar", "contacts", "行事曆", "聯絡人")
            let appAlert = app.alerts.matching(permission).firstMatch
            let systemAlert = springboard.alerts.matching(permission).firstMatch
            let appeared = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "SUBQUERY(SELF, $alert, $alert.exists == true).@count > 0"),
                object: [appAlert, systemAlert])
            let result = XCTWaiter.wait(for: [appeared], timeout: 180)
            // Capture both hosts before asserting, including on timeout.
            checkpoint("D04 app permission state \(attempt)", app: app)
            checkpoint("D04 SpringBoard permission state \(attempt)", app: springboard)
            XCTAssertEqual(result, .completed, "未出現真實系統授權提示；不可用既有拒絕狀態冒充通過。")
            let alert = appAlert.exists ? appAlert : systemAlert
            let description = alert.debugDescription.lowercased()
            let isCalendar = description.contains("calendar") || description.contains("行事曆")
            let isContacts = description.contains("contacts") || description.contains("聯絡人")
            XCTAssertTrue(isCalendar || isContacts, alert.debugDescription)
            let deny = alert.buttons["Don’t Allow"].exists ? alert.buttons["Don’t Allow"] :
                (alert.buttons["Don't Allow"].exists ? alert.buttons["Don't Allow"] : alert.buttons["不允許"])
            XCTAssertTrue(deny.exists, alert.debugDescription)
            deny.tap()
            if isCalendar { deniedCalendar = true; break }
        }
        XCTAssertTrue(deniedCalendar, "必須捕捉並拒絕Calendar真實系統prompt。")
        scrollDown(app)
        let denied = app.staticTexts["未允許讀取行事曆。草稿仍保留，可在系統設定調整權限。"]
        reveal(denied, app: app)
        try waitFor(denied, app: app, stage: "D05 calendar denial explanation")
        let unknown = app.staticTexts["未有有效查詢證據；衝突狀態未知。"]
        reveal(unknown, app: app)
        XCTAssertTrue(unknown.exists)
        XCTAssertFalse(app.staticTexts["此時段沒有衝突（查詢當下）"].exists)
        checkpoint("D06 Calendar remains unknown", app: app)

        for _ in 0..<6 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)))
        }
        let event = app.staticTexts["活動預覽"]
        reveal(event, app: app)
        XCTAssertTrue(event.exists, "拒絕權限後必須保留完整草稿。")
        let edit = app.buttons["編輯"]
        reveal(edit, app: app)
        edit.tap()
        let picker = app.datePickers.firstMatch
        reveal(picker, app: app)
        let description = picker.debugDescription.lowercased().filter { !$0.isWhitespace }
        XCTAssertTrue(containsExpectedDate(description, expected: start), picker.debugDescription)
        XCTAssertTrue(description.contains(start.formatted(date: .omitted, time: .shortened).lowercased().filter { !$0.isWhitespace }), picker.debugDescription)
        let duration = app.steppers["持續 30 分鐘"]
        reveal(duration, app: app)
        XCTAssertTrue(duration.exists)
        checkpoint("D07 preserved tomorrow 16:00 thirty-minute draft", app: app)
        let log = app.buttons["AI 處理紀錄"]
        reveal(log, app: app)
        log.tap()
        let activity = app.staticTexts["⚠ 行事曆無法查詢；衝突狀態未知"]
        reveal(activity, app: app)
        XCTAssertTrue(activity.exists)
        XCTAssertTrue(app.staticTexts["→ CheckCalendarTool(\(start.formatted(date: .omitted, time: .shortened)))"].exists)
        XCTAssertFalse(app.staticTexts["已加入系統行事曆"].exists)
        checkpoint("D08 real Calendar tool denied; no save", app: app)
    }

    @MainActor private func submit(_ note: String, app: XCUIApplication, stage: String) throws {
        for _ in 0..<6 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)))
        }
        if app.buttons["筆記與修改指令"].exists && !app.textFields["隨手筆記或修改指令"].exists && !app.textViews["隨手筆記或修改指令"].exists {
            let note = app.buttons["筆記與修改指令"]
            reveal(note, app: app)
            note.tap()
        }
        let label = "隨手筆記或修改指令"
        let input = app.textViews[label].exists ? app.textViews[label] : app.textFields[label]
        reveal(input, app: app)
        input.tap()
        if let current = input.value as? String, !current.isEmpty {
            input.press(forDuration: 1.2)
            let selectAll = app.menuItems["Select All"].exists ? app.menuItems["Select All"] : app.buttons["Select All"]
            try waitFor(selectAll, app: app, stage: stage + " Select All", timeout: 5)
            selectAll.tap()
            input.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        input.typeText(note)
        XCTAssertEqual(input.value as? String, note)
        checkpoint(stage + " input", app: app)
        let generate = app.buttons["整理成活動"]
        reveal(generate, app: app)
        XCTAssertTrue(generate.isEnabled, "模型不可用必須失敗，不能skip。")
        generate.tap()
        checkpoint(stage + " submitted", app: app)
        if !app.alerts.firstMatch.exists && !springboardAlertExists() { scrollDown(app) }
    }
    @MainActor private func springboardAlertExists() -> Bool {
        XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists
    }
    @MainActor private func waitForGenerationState(app: XCUIApplication, springboard: XCUIApplication, stage: String) throws {
        let states = [app.staticTexts["活動預覽"], app.staticTexts["尚待時間確認"],
                      app.staticTexts["需要注意"], app.alerts.firstMatch, springboard.alerts.firstMatch]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "SUBQUERY(SELF, $state, $state.exists == true).@count > 0"), object: states)
        let result = XCTWaiter.wait(for: [expectation], timeout: 180)
        checkpoint(stage + " app", app: app)
        checkpoint(stage + " SpringBoard", app: springboard)
        XCTAssertEqual(result, .completed, "未產生完整草稿、pending、錯誤或權限prompt；見雙host附件。")
    }

    @MainActor private func scrollDown(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
    }
    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<8 { if element.exists && element.isHittable { return }; scrollDown(app) }
    }
    @MainActor private func waitFor(_ element: XCUIElement, app: XCUIApplication, stage: String, timeout: TimeInterval = 180) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        checkpoint(stage, app: app)
        guard result == .completed else {
            throw NSError(domain: "MessyNotePermissionUI", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(stage)未在\(timeout)秒內完成。"])
        }
    }
    @MainActor private func checkpoint(_ stage: String, app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = stage + " screenshot"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = stage + " accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
    private func normalized(_ text: String) -> String { text.lowercased().filter { !$0.isWhitespace } }

    private func containsExpectedDate(_ description: String, expected: Date) -> Bool {
        if description.contains(normalized(expected.formatted(date: .abbreviated, time: .omitted))) { return true }
        // UIDatePicker can honor the user's numeric short-date preference even when
        // Foundation's abbreviated formatter uses month names. Verify the same day.
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: expected)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return false }
        let numericDates = ["\(year)/\(month)/\(day)", String(format: "%04d/%02d/%02d", year, month, day)]
        return numericDates.contains { value in
            let pattern = "(?<![0-9])" + NSRegularExpression.escapedPattern(for: value) + "(?![0-9])"
            return description.range(of: pattern, options: .regularExpression) != nil
        }
    }


}
