import XCTest

final class CaseCUITests: XCTestCase {
    @MainActor
    func testCaseCNaturalLanguageCompletion() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["MESSYNOTE_ACCEPTANCE_DIAGNOSTICS"] = "1"
        app.launch()
        addTeardownBlock { @MainActor [weak self] in
            guard let self else { return }
            if self.testRun?.hasSucceeded == false { self.checkpoint("Failure final UI state", app: app) }
        }
        checkpoint("01 launched", app: app)

        app.buttons["設定"].tap()
        let fixture = app.switches["Demo Fixture Mode"].firstMatch
        try waitFor(fixture, stage: "Fixture switch", app: app, timeout: 15)
        for attempt in 1...2 {
            if fixture.value as? String == "1" { break }
            XCTAssertEqual(fixture.value as? String, "0", "未知fixture狀態不可盲目反切。")
            let tappable = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true AND hittable == true"), object: fixture)
            XCTAssertEqual(XCTWaiter.wait(for: [tappable], timeout: 5), .completed, "必須定位可操作的具名switch。")
            let track = fixture.switches.firstMatch
            XCTAssertTrue(track.exists, "必須定位具名switch內的真實track。")
            track.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).tap()
            let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: fixture)
            _ = XCTWaiter.wait(for: [enabled], timeout: 5)
            checkpoint("Fixture labeled switch attempt \(attempt)", app: app)
        }
        XCTAssertEqual(fixture.value as? String, "1", "兩次具名switch操作後仍未啟用fixture；停止於UI setup，尚未執行模型。")

        app.buttons["完成"].tap()
        if app.buttons["筆記與修改指令"].exists && !app.textFields["隨手筆記或修改指令"].exists && !app.textViews["隨手筆記或修改指令"].exists {
            let note = app.buttons["筆記與修改指令"]
            reveal(note, app: app)
            note.tap()
        }
        let label = "隨手筆記或修改指令"
        let input = app.textViews[label].exists ? app.textViews[label] : app.textFields[label]
        try replaceText(in: input, with: "下週五晚上跟一個不存在於 Contacts 的人吃飯", app: app)
        checkpoint("02 initial Chinese input and fixture ON", app: app)
        let generate = app.buttons["整理成活動"]
        reveal(generate, app: app)
        XCTAssertTrue(generate.isEnabled, "模型不可用時必須失敗，不能skip或當作通過。")
        generate.tap()
        scroll(app, towardTop: false)

        let pending = app.staticTexts["尚待時間確認"]
        try waitFor(pending, stage: "03 pending draft", app: app)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: .now)
        let mondayIndex = (calendar.component(.weekday, from: today) + 5) % 7
        let friday = try XCTUnwrap(calendar.date(byAdding: .day, value: 11 - mondayIndex, to: today))
        let expectedPendingDate = "固定草稿日期：" + friday.formatted(date: .complete, time: .omitted)
        let fixedDate = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "固定草稿日期：")).firstMatch
        reveal(fixedDate, app: app)
        XCTAssertEqual(fixedDate.label, expectedPendingDate)
        let capturedDate = XCTAttachment(string: fixedDate.label)
        capturedDate.name = "Captured pending date"
        capturedDate.lifetime = .keepAlways
        add(capturedDate)
        checkpoint("04 fixed Friday captured", app: app)

        for _ in 0..<8 {
            let frame = input.frame
            let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY - 20 : app.frame.maxY - 40
            if frame.minY >= 120, frame.maxY <= bottom { break }
            scroll(app, towardTop: frame.minY < 120)
        }
        XCTAssertGreaterThanOrEqual(input.frame.minY, 120, "補充時間的輸入框必須完整位於導覽列下方。")
        let inputBottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY - 20 : app.frame.maxY - 40
        XCTAssertLessThanOrEqual(input.frame.maxY, inputBottom, "補充時間的輸入框必須完整位於鍵盤上方。")
        try replaceText(in: input, with: "晚上七點，吃飯一小時，同行者叫阿不存在", app: app)
        checkpoint("05 follow-up Chinese input", app: app)
        reveal(generate, app: app)
        generate.tap()
        scroll(app, towardTop: false)
        let editor = app.staticTexts["活動預覽"]
        try waitFor(editor, stage: "06 completed event", app: app)
        XCTAssertFalse(pending.exists, "自然語言補充後不能仍是pending草稿。")
        let edit = app.buttons["編輯"]
        let editReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true"), object: edit)
        XCTAssertEqual(XCTWaiter.wait(for: [editReady], timeout: 180), .completed, "模型與工具查詢完成、編輯啟用後才能操作。")
        reveal(edit, app: app)
        edit.tap()
        let start = app.datePickers.firstMatch
        reveal(start, app: app)
        XCTAssertTrue(start.exists, "必須從實際DatePicker讀取完成日期與時間。")
        let pickerDescription = normalized(start.debugDescription)
        XCTAssertTrue(containsExpectedDate(pickerDescription, expected: friday), "完成日期必須是原pending的下一週五。\n\(start.debugDescription)")
        let atSeven = try XCTUnwrap(calendar.date(bySettingHour: 19, minute: 0, second: 0, of: friday))
        XCTAssertTrue(pickerDescription.contains(normalized(atSeven.formatted(date: .omitted, time: .shortened))) || pickerDescription.contains("19:00"), "完成時間必須是19:00。\n\(start.debugDescription)")
        let duration = app.steppers["持續 60 分鐘"]
        reveal(duration, app: app)
        XCTAssertTrue(duration.exists)
        let attendee = app.textFields["參與者姓名"]
        reveal(attendee, app: app)
        XCTAssertEqual(attendee.value as? String, "阿不存在")
        checkpoint("07 event date time duration and attendee", app: app)

        let noContacts = app.staticTexts["找不到可存取的聯絡人（可能受限於部分存取權）。"]
        reveal(noContacts, app: app)
        try waitFor(noContacts, stage: "08 empty Contacts result", app: app)
        let noConflicts = app.staticTexts["此時段沒有衝突（查詢當下）"]
        reveal(noConflicts, app: app)
        try waitFor(noConflicts, stage: "09 empty Calendar result", app: app)
        let log = app.buttons["AI 處理紀錄"]
        reveal(log, app: app)
        // The pinned next action can overlap a control that XCTest reports as hittable.
        let visibleBottom = app.keyboards.firstMatch.exists
            ? app.keyboards.firstMatch.frame.minY - 20 : app.frame.maxY - 160
        for _ in 0..<8 {
            if log.frame.minY >= 120, log.frame.maxY <= visibleBottom { break }
            scroll(app, towardTop: log.frame.minY < 120)
        }
        XCTAssertGreaterThanOrEqual(log.frame.minY, 120)
        XCTAssertLessThanOrEqual(log.frame.maxY, visibleBottom, "AI紀錄按鈕必須完整位於固定底欄上方。")
        log.tap()
        let contactCall = app.staticTexts["→ FindContactTool(阿不存在)"]
        try waitFor(contactCall, stage: "AI activity expanded", app: app, timeout: 5)
        reveal(contactCall, app: app)
        XCTAssertTrue(contactCall.exists, "必須有真實Contacts工具activity。")
        let calendarCall = app.staticTexts["→ CheckCalendarTool(\(atSeven.formatted(date: .omitted, time: .shortened)))"]
        reveal(calendarCall, app: app)
        XCTAssertTrue(calendarCall.exists, "必須有19:00的真實Calendar工具activity。")
        XCTAssertFalse(app.staticTexts["已加入系統行事曆"].exists)
        checkpoint("10 true tool activity; no calendar save", app: app)
    }

    @MainActor
    private func replaceText(in input: XCUIElement, with text: String, app: XCUIApplication) throws {
        XCTAssertTrue(input.exists, "缺少筆記輸入欄。")
        input.tap()
        if let current = input.value as? String, !current.isEmpty {
            input.press(forDuration: 1.2)
            let selectAll = app.menuItems["Select All"].exists ? app.menuItems["Select All"] : app.buttons["Select All"]
            try waitFor(selectAll, stage: "Select All for input replacement", app: app, timeout: 5)
            selectAll.tap()
            input.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        input.typeText(text)
        XCTAssertEqual(input.value as? String, text, "必須由真實typeText寫入完整中文binding。")
    }

    @MainActor
    private func scroll(_ app: XCUIApplication, towardTop: Bool) {
        let start = towardTop ? 0.35 : 0.55
        let end = towardTop ? 0.55 : 0.35
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: end)))
    }

    @MainActor
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for attempt in 0..<12 {
            if element.exists {
                if element.isHittable { return }
                let frame = element.frame
                let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.frame.maxY - 40
                // Container controls can be readable but not hittable. Do not scroll a visible picker away.
                if frame.height > 0, frame.minY >= 120, frame.maxY <= bottom { return }
                scroll(app, towardTop: frame.minY < 120)
            } else {
                // Lazy Form children may need a bounded search in either direction.
                scroll(app, towardTop: attempt >= 6)
            }
        }
        checkpoint("Reveal did not settle: " + element.identifier, app: app)
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, stage: String, app: XCUIApplication, timeout: TimeInterval = 180) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        checkpoint(stage, app: app)
        guard result == .completed else {
            throw NSError(domain: "MessyNoteCaseCUI", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(stage)未在\(timeout)秒內完成；runtime錯誤或模型不可用均不視為通過。請檢視截圖與AX附件。"])
        }
    }

    @MainActor
    private func checkpoint(_ stage: String, app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = stage + " screenshot"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = stage + " accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    private func normalized(_ string: String) -> String {
        string.lowercased().filter { !$0.isWhitespace }
    }
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
