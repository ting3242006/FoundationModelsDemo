import XCTest

final class ScenarioABUITests: XCTestCase {
    @MainActor
    func testNoteZhuyinReturnCommitsCandidate() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let input = noteInput(app)
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()

        // Prerequisite: Traditional Chinese Zhuyin is the active hardware keyboard.
        // Require a real candidate; typeText("下週五") bypasses composition.
        try replaceText(in: input, with: "", app: app)
        for key in ["v", "u", "8", "4", "5", ".", " ", "j", "3"] {
            app.typeKey(key, modifierFlags: [])
        }
        let candidate = app.buttons["下週五"]
        let hasCandidate = candidate.waitForExistence(timeout: 2)
        checkpoint("IME candidate before hardware Return", app: app)
        guard hasCandidate else {
            throw XCTSkip("需配置繁體注音硬體鍵盤並顯示『下週五』候選；目前尚未執行 Enter 驗收。")
        }
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
        let committed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "下週五"), object: input)
        XCTAssertEqual(XCTWaiter.wait(for: [committed], timeout: 3), .completed,
                       "實體 Return 必須確認注音候選並保留『下週五』。")
        checkpoint("IME candidate after hardware Return", app: app)
    }

    @MainActor
    func testNoteMultilineEditingAndExampleReplacement() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let input = noteInput(app)
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        try replaceText(in: input, with: "", app: app)
        // This verifies ordinary multiline editing, not hardware IME submission.
        try replaceText(in: input, with: "Meeting\nFriday", app: app)
        XCTAssertEqual(input.value as? String, "Meeting\nFriday")
        try replaceText(in: input, with: "", app: app)
        XCTAssertTrue((input.value as? String ?? "").isEmpty || input.value as? String == "今天想做什麼？")
        XCTAssertFalse(app.buttons["整理成活動"].isEnabled)
        app.swipeUp()
        app.buttons["填入範例筆記"].tap()
        XCTAssertEqual(input.value as? String, "下週三下午三點跟小明在信義區喝咖啡一小時，記得帶合約，前一天提醒我")
    }

    @MainActor
    private func noteInput(_ app: XCUIApplication) -> XCUIElement {
        let label = "隨手筆記或修改指令"
        return app.textViews[label].exists ? app.textViews[label] : app.textFields[label]
    }

    @MainActor
    func testNativeStudioEditReviewCancellation() throws {
        let app = try launchFixture()
        let primary = app.buttons["整理成活動"]
        XCTAssertTrue(primary.waitForExistence(timeout: 5), "筆記工作室必須提供明確的主要整理動作。")
        try generate("明天下午四點跟Amy開會半小時，兩小時前提醒我", app: app, stage: "Studio01 generate")
        try waitFor(app.staticTexts["活動預覽"], app: app, stage: "Studio02 preview")
        XCTAssertTrue(app.buttons["筆記與修改指令"].exists)
        XCTAssertFalse(app.textFields["隨手筆記或修改指令"].exists || app.textViews["隨手筆記或修改指令"].exists, "產生活動後先收合筆記，讓活動內容成為焦點。")
        let title = app.textFields["標題"]
        XCTAssertFalse(title.exists, "預覽先顯示內容；編輯欄位由使用者展開。")
        let edit = app.buttons["編輯"]
        top(app)
        reveal(edit, app: app)
        edit.tap()
        reveal(title, app: app)
        XCTAssertTrue(title.exists)
        // A descendant can report hittable while still below the pinned next action.
        // Bring the entire field into the scroll viewport before asking for focus.
        for _ in 0..<8 {
            if title.frame.minY >= 120, title.frame.maxY <= app.frame.maxY - 180 { break }
            scrollDown(app)
        }
        XCTAssertLessThanOrEqual(title.frame.maxY, app.frame.maxY - 180)
        title.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "標題欄必須真的取得鍵盤焦點。")
        title.typeText("（已確認）")
        let editedTitle = try XCTUnwrap(title.value as? String)
        app.swipeUp()
        let unknown = app.staticTexts["未有有效查詢證據；衝突狀態未知。"]
        reveal(unknown, app: app)
        XCTAssertTrue(unknown.exists, "手動編輯後舊查詢證據必須失效。")
        let next = app.buttons["檢查並加入"]
        reveal(next, app: app)
        XCTAssertTrue(next.isEnabled)
        next.tap()
        try waitFor(app.staticTexts["最後確認"], app: app, stage: "Studio03 review")
        XCTAssertTrue(app.staticTexts[editedTitle].exists, "最後確認必須使用編輯後快照。")
        XCTAssertTrue(app.buttons["確認加入行事曆"].exists)
        checkpoint("Studio review before cancel; never write calendar", app: app)
        app.buttons["取消"].tap()
        XCTAssertFalse(app.staticTexts["最後確認"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.staticTexts["已加入系統行事曆"].exists)
    }

    @MainActor
    func testScenarioA() throws {
        let app = try launchFixture()
        let calendar = Calendar(identifier: .gregorian)
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: .now))
        let start = try XCTUnwrap(calendar.date(bySettingHour: 16, minute: 0, second: 0, of: tomorrow))
        try generate("明天下午四點跟Amy開會半小時，兩小時前提醒我", app: app, stage: "A01 Chinese input")
        try waitFor(app.staticTexts["活動預覽"], app: app, stage: "A02 event")
        try verifyTools(attendee: "Amy", start: start, app: app, stage: "A03 tools")
        try verifyNoConflicts(app: app, stage: "A04 no conflicts")
        try verifyEvent(start: start, duration: 30, attendee: "Amy", reminder: "兩小時前", app: app, stage: "A05 event fields")
        top(app)
        let amy = app.buttons["Amy Chen"]
        reveal(amy, app: app)
        XCTAssertTrue(amy.exists)
        amy.tap()
        checkpoint("A06 selected Amy Chen", app: app)
        try openReviewAndCancel(contact: "Amy Chen", reminder: 120, app: app, stage: "A07 review and cancel")
    }

    @MainActor
    func testScenarioBAndFollowUp() throws {
        let app = try launchFixture()
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: .now)
        let mondayIndex = (calendar.component(.weekday, from: today) + 5) % 7
        let wednesday = try XCTUnwrap(calendar.date(byAdding: .day, value: 9 - mondayIndex, to: today))
        let start = try XCTUnwrap(calendar.date(bySettingHour: 15, minute: 0, second: 0, of: wednesday))
        let alternative = try XCTUnwrap(calendar.date(bySettingHour: 16, minute: 30, second: 0, of: wednesday))
        try generate("下週三下午三點跟小明在信義區喝咖啡一小時，記得帶合約，前一天提醒我", app: app, stage: "B01 Chinese input")
        try waitFor(app.staticTexts["活動預覽"], app: app, stage: "B02 event")
        try verifyTools(attendee: "小明", start: start, app: app, stage: "B03 initial tools")
        try verifyEvent(start: start, duration: 60, attendee: "小明", reminder: "前一天", app: app, stage: "B04 initial fields", checkCoffeeFields: true)
        top(app)
        let wang = app.buttons["王小明"]
        reveal(wang, app: app)
        XCTAssertTrue(wang.exists)
        XCTAssertTrue(app.buttons["林小明"].exists)
        checkpoint("B05 two candidates", app: app)
        let conflict = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "⚠ Team Meeting")).firstMatch
        reveal(conflict, app: app)
        try waitFor(conflict, app: app, stage: "B06 conflict")
        let slot = app.staticTexts["建議時段：\(alternative.formatted(date: .abbreviated, time: .shortened))"]
        reveal(slot, app: app)
        XCTAssertTrue(slot.exists, "必須由Swift產生16:30空檔。")
        let save = app.buttons["檢查並加入"]
        reveal(save, app: app)
        XCTAssertFalse(save.isEnabled, "多候選尚未由使用者選擇時不得儲存。")
        checkpoint("B07 Swift slot and unresolved ambiguity", app: app)

        try generate("好，那改成16:30", app: app, stage: "B08 follow-up input")
        // The time-specific new tool entry cannot be satisfied by the previous 15:00 review.
        try verifyTools(attendee: "小明", start: alternative, app: app, stage: "B09 follow-up tools")
        try verifyNoConflicts(app: app, stage: "B10 follow-up no conflicts")
        try verifyEvent(start: alternative, duration: 60, attendee: "小明", reminder: "前一天", app: app, stage: "B11 preserved fields", checkCoffeeFields: true)
        top(app)
        reveal(wang, app: app)
        XCTAssertTrue(wang.exists)
        XCTAssertTrue(app.buttons["林小明"].exists)
        reveal(save, app: app)
        XCTAssertFalse(save.isEnabled, "新草稿仍須由使用者確認候選。")
        top(app)
        reveal(wang, app: app)
        wang.tap()
        checkpoint("B12 user selected Wang", app: app)
        try openReviewAndCancel(contact: "王小明", reminder: 1440, app: app, stage: "B13 review and cancel")
    }

    @MainActor
    private func launchFixture() throws -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["MESSYNOTE_ACCEPTANCE_DIAGNOSTICS"] = "1"
        app.launch()
        addTeardownBlock { @MainActor [weak self] in
            guard let self else { return }
            if self.testRun?.hasSucceeded == false { self.checkpoint("Failure final UI state", app: app) }
        }
        app.buttons["設定"].tap()
        let fixture = app.switches["Demo Fixture Mode"].firstMatch
        try waitFor(fixture, app: app, stage: "Fixture available", timeout: 15)
        for attempt in 1...2 {
            if fixture.value as? String == "1" { break }
            XCTAssertEqual(fixture.value as? String, "0", "未知fixture狀態不可盲目反切。")
            let tappable = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true AND hittable == true"), object: fixture)
            XCTAssertEqual(XCTWaiter.wait(for: [tappable], timeout: 5), .completed, "必須定位可操作的具名switch。")
            let track = fixture.switches.firstMatch
            XCTAssertTrue(track.exists, "必須定位具名switch內的真實track。")
            if attempt == 1 {
                track.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).tap()
            } else {
                let offThumb = track.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5))
                let onEnd = track.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5))
                offThumb.press(forDuration: 0.05, thenDragTo: onEnd,
                               withVelocity: XCUIGestureVelocity(rawValue: 100), thenHoldForDuration: 0.2)
            }
            let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: fixture)
            _ = XCTWaiter.wait(for: [enabled], timeout: 5)
            checkpoint("Fixture labeled switch attempt \(attempt)", app: app)
        }
        XCTAssertEqual(fixture.value as? String, "1", "兩次具名switch操作後仍未啟用fixture；停止於UI setup，尚未執行模型。")
        app.buttons["完成"].tap()
        let demo = app.staticTexts["真實模型推論＋示範聯絡人與行事曆查詢。儲存仍會寫入系統行事曆。"]
        try waitFor(demo, app: app, stage: "Demo Mode binding confirmed", timeout: 5)
        XCTAssertFalse(app.staticTexts["使用系統資料"].exists)
        checkpoint("Fixture ON", app: app)
        return app
    }

    @MainActor
    private func generate(_ text: String, app: XCUIApplication, stage: String) throws {
        top(app)
        if app.buttons["筆記與修改指令"].exists && !app.textFields["隨手筆記或修改指令"].exists && !app.textViews["隨手筆記或修改指令"].exists {
            let note = app.buttons["筆記與修改指令"]
            reveal(note, app: app)
            note.tap()
        }
        let label = "隨手筆記或修改指令"
        let input = app.textViews[label].exists ? app.textViews[label] : app.textFields[label]
        reveal(input, app: app)
        XCTAssertTrue(input.exists)
        try replaceText(in: input, with: text, app: app)
        checkpoint(stage, app: app)
        let generate = app.buttons["整理成活動"]
        if app.buttons["檢查並加入"].exists {
            try revealSubmissionAbovePinnedAction(generate, app: app)
        } else {
            reveal(generate, app: app)
        }
        XCTAssertTrue(generate.isEnabled, "模型不可用不得skip或當作通過。")
        let cancel = app.buttons["取消"]
        XCTAssertFalse(cancel.exists, "本次提交前不應仍有上一輪生成。")
        generate.tap()
        checkpoint(stage + " immediately after submission tap", app: app)
        let started = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: cancel)
        let startResult = XCTWaiter.wait(for: [started], timeout: 10)
        checkpoint(stage + " submission start observation", app: app)
        guard startResult == .completed else {
            throw NSError(domain: "MessyNoteAcceptanceUI", code: 6, userInfo: [NSLocalizedDescriptionKey: "未觀察到此次提交開始（取消按鈕未出現）；未重複點擊，不據此判定模型錯誤。"])
        }
        let partial = app.staticTexts["正在整理活動"]
        let partialAppeared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: partial)
        if XCTWaiter.wait(for: [partialAppeared], timeout: 3) == .completed {
            checkpoint(stage + " observed real partial section", app: app)
        }
        scrollDown(app)
    }

    @MainActor
    private func revealSubmissionAbovePinnedAction(_ button: XCUIElement, app: XCUIApplication) throws {
        let nextAction = app.buttons["檢查並加入"]
        for attempt in 0..<8 {
            let window = app.windows.firstMatch.frame
            let visibleTop = window.minY + 120
            let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : window.maxY
            let visibleBottom = min(keyboardTop, nextAction.frame.minY) - 20
            let frame = button.frame
            pinnedGeometry("Submission before drag \(attempt + 1)", element: button, app: app)
            if frame.minY >= visibleTop, frame.maxY <= visibleBottom {
                XCTAssertTrue(button.isHittable, "整理按鈕必須完整位於固定底欄上方且可點擊。")
                return
            }
            guard visibleBottom - visibleTop > 80 else { break }
            let movingDown = frame.minY < visibleTop
            let distance = min(movingDown ? visibleTop - frame.minY + 20 : frame.maxY - visibleBottom + 20,
                               visibleBottom - visibleTop - 40)
            let startY = movingDown ? visibleTop + 20 : visibleBottom - 20
            let endY = movingDown ? startY + distance : startY - distance
            controlledEdgeDrag(from: startY, to: endY, app: app)
            pinnedGeometry("Submission after drag \(attempt + 1)", element: button, app: app)
        }
        if isAbovePinnedAction(button, app: app) {
            XCTAssertTrue(button.isHittable, "整理按鈕必須完整位於固定底欄上方且可點擊。")
            return
        }
        checkpoint("Submission still covered before tap", app: app)
        throw NSError(domain: "MessyNoteAcceptanceUI", code: 9, userInfo: [NSLocalizedDescriptionKey: "整理按鈕仍被導覽列、固定操作列或鍵盤遮住，尚未提交。"])
    }

    @MainActor
    private func focusInputAbovePinnedAction(_ input: XCUIElement, app: XCUIApplication) throws {
        let nextAction = app.buttons["檢查並加入"]
        if nextAction.exists { pinnedGeometry("Input before initial focus", element: input, app: app) }
        input.tap()
        if nextAction.exists { pinnedGeometry("Input after initial focus", element: input, app: app) }
        // The initial note has no pinned action; preserve its existing editing path.
        guard nextAction.exists else { return }
        for attempt in 0..<8 {
            if !app.keyboards.firstMatch.exists {
                pinnedGeometry("Input before focus \(attempt + 1)", element: input, app: app)
                input.tap()
                pinnedGeometry("Input after focus \(attempt + 1)", element: input, app: app)
            }
            guard app.keyboards.firstMatch.waitForExistence(timeout: 5) else {
                throw NSError(domain: "MessyNoteAcceptanceUI", code: 7, userInfo: [NSLocalizedDescriptionKey: "輸入框未取得鍵盤焦點，未操作編輯選單。"])
            }
            let window = app.windows.firstMatch.frame
            let visibleTop = window.minY + 120
            let visibleBottom = min(app.keyboards.firstMatch.frame.minY - 20, nextAction.frame.minY - 20)
            let frame = input.frame
            pinnedGeometry("Input before drag \(attempt + 1)", element: input, app: app)
            if frame.minY >= visibleTop, frame.maxY <= visibleBottom { return }
            guard visibleBottom - visibleTop > 80 else { break }
            // Both endpoints stay in the scroll viewport, clear of the keyboard and pinned action.
            let movingDown = frame.minY < visibleTop
            let distance = min(movingDown ? visibleTop - frame.minY + 20 : frame.maxY - visibleBottom + 20,
                               visibleBottom - visibleTop - 40)
            let startY = movingDown ? visibleTop + 20 : visibleBottom - 20
            let endY = movingDown ? startY + distance : startY - distance
            controlledEdgeDrag(from: startY, to: endY, app: app)
            pinnedGeometry("Input after drag \(attempt + 1)", element: input, app: app)
        }
        if !app.keyboards.firstMatch.exists {
            pinnedGeometry("Input before final focus", element: input, app: app)
            input.tap()
            pinnedGeometry("Input after final focus", element: input, app: app)
        }
        if app.keyboards.firstMatch.waitForExistence(timeout: 5), isAbovePinnedAction(input, app: app) { return }
        checkpoint("Input still covered before edit menu", app: app)
        throw NSError(domain: "MessyNoteAcceptanceUI", code: 8, userInfo: [NSLocalizedDescriptionKey: "輸入框仍被導覽列、固定操作列或鍵盤遮住，未操作編輯選單。"])
    }

    @MainActor
    private func controlledEdgeDrag(from startY: CGFloat, to endY: CGFloat, app: XCUIApplication) {
        let window = app.windows.firstMatch
        let origin = window.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: 10, dy: startY - window.frame.minY))
        let end = origin.withOffset(CGVector(dx: 10, dy: endY - window.frame.minY))
        start.press(forDuration: 0.05, thenDragTo: end,
                    withVelocity: XCUIGestureVelocity(rawValue: 100), thenHoldForDuration: 0.2)
    }

    @MainActor
    private func isAbovePinnedAction(_ element: XCUIElement, app: XCUIApplication) -> Bool {
        let window = app.windows.firstMatch.frame
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : window.maxY
        let bottom = min(keyboardTop, app.buttons["檢查並加入"].frame.minY) - 20
        return element.frame.minY >= window.minY + 120 && element.frame.maxY <= bottom
    }

    @MainActor
    private func pinnedGeometry(_ stage: String, element: XCUIElement, app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        let attachment = XCTAttachment(string: "app=\(app.frame), window=\(app.windows.firstMatch.frame), target=\(element.frame), keyboardExists=\(keyboard.exists), keyboard=\(keyboard.exists ? keyboard.frame : .zero), nextAction=\(app.buttons["檢查並加入"].frame)")
        attachment.name = stage
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func replaceText(in input: XCUIElement, with text: String, app: XCUIApplication) throws {
        let expectedPlaceholder = "今天想做什麼？"
        let emptyField = NSPredicate { object, _ in
            guard let field = object as? XCUIElement, field.exists else { return false }
            let rawValue = field.value
            if rawValue == nil {
                return field.placeholderValue == expectedPlaceholder
            }
            if rawValue is NSNull {
                return field.placeholderValue == expectedPlaceholder
            }
            guard let value = rawValue as? String else { return false }
            return value.isEmpty || (value == expectedPlaceholder && field.placeholderValue == expectedPlaceholder)
        }
        try focusInputAbovePinnedAction(input, app: app)
        inputValueCheckpoint("Before clear", input: input)
        if !emptyField.evaluate(with: input) {
            guard let current = input.value as? String, !current.isEmpty, current != expectedPlaceholder else {
                throw NSError(domain: "MessyNoteAcceptanceUI", code: 4, userInfo: [NSLocalizedDescriptionKey: "輸入欄狀態無法確認，不將未知非字串值視為空欄。"])
            }
            let menuItem = app.menuItems["Select All"]
            let button = app.buttons["Select All"]
            var menuAppeared = false
            for attempt in 0..<2 {
                if attempt == 0 {
                    input.press(forDuration: 1.2)
                } else {
                    // Move the caret away from the observed start position before reopening the menu.
                    let endOfInput = input.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.85))
                    endOfInput.tap()
                    checkpoint("Caret moved before reopening edit menu", app: app)
                    endOfInput.press(forDuration: 1.2)
                }
                let expectation = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "SUBQUERY(SELF, $item, $item.exists == true).@count > 0"),
                    object: [menuItem, button])
                menuAppeared = XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
                if menuAppeared { break }
                checkpoint("Select All menu absent attempt \(attempt + 1)", app: app)
            }
            guard menuAppeared else {
                throw NSError(domain: "MessyNoteAcceptanceUI", code: 2, userInfo: [NSLocalizedDescriptionKey: "真實輸入框編輯選單沒有Select All；未送出follow-up。"])
            }
            (menuItem.exists ? menuItem : button).tap()
            input.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        let cleared = XCTNSPredicateExpectation(predicate: emptyField, object: input)
        let clearResult = XCTWaiter.wait(for: [cleared], timeout: 5)
        inputValueCheckpoint("After clear wait", input: input)
        guard clearResult == .completed else {
            throw NSError(domain: "MessyNoteAcceptanceUI", code: 5, userInfo: [NSLocalizedDescriptionKey: "清空輸入未在5秒內取得可確認的空欄狀態；尚未輸入或送出新指令。"])
        }
        if !text.isEmpty { input.typeText(text) }
        let exactText = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND value == %@", text), object: input)
        let typedResult = XCTWaiter.wait(for: [exactText], timeout: 5)
        inputValueCheckpoint("After replacement text", input: input)
        XCTAssertEqual(typedResult, .completed, "輸入完成後必須整句精確符合期待指令。")
        XCTAssertEqual(input.value as? String, text)
    }

    @MainActor
    private func inputValueCheckpoint(_ stage: String, input: XCUIElement) {
        let rawValue = input.value
        let rawType = rawValue.map { String(reflecting: type(of: $0)) } ?? "nil"
        let attachment = XCTAttachment(string: "exists=\(input.exists)\nrawType=\(rawType)\nrawValue=\(String(reflecting: rawValue))\nplaceholder=\(String(reflecting: input.placeholderValue))")
        attachment.name = stage + " raw input attributes"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func verifyEvent(start: Date, duration: Int, attendee: String, reminder: String, app: XCUIApplication, stage: String, checkCoffeeFields: Bool = false) throws {
        top(app)
        if !app.textFields["標題"].exists {
            let edit = app.buttons["編輯"]
            reveal(edit, app: app)
            edit.tap()
        }
        let picker = app.datePickers.firstMatch
        reveal(picker, app: app)
        XCTAssertTrue(picker.exists)
        let description = normalized(picker.debugDescription)
        XCTAssertTrue(containsExpectedDate(description, expected: start), picker.debugDescription)
        XCTAssertTrue(description.contains(normalized(start.formatted(date: .omitted, time: .shortened))), picker.debugDescription)
        let durationControl = app.steppers["持續 \(duration) 分鐘"]
        reveal(durationControl, app: app)
        XCTAssertTrue(durationControl.exists)
        let name = app.textFields["參與者姓名"]
        reveal(name, app: app)
        XCTAssertEqual(name.value as? String, attendee)
        if checkCoffeeFields {
            XCTAssertEqual(app.textFields["地點"].value as? String, "信義區")
            let notes = app.textFields["活動筆記"]
            reveal(notes, app: app)
            XCTAssertTrue((notes.value as? String)?.contains("合約") == true)
        }
        let reminderControl = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "提醒")).firstMatch
        reveal(reminderControl, app: app)
        XCTAssertTrue(reminderControl.exists)
        XCTAssertTrue(reminderControl.debugDescription.contains(reminder), reminderControl.debugDescription)
        checkpoint(stage, app: app)
    }

    @MainActor
    private func verifyTools(attendee: String, start: Date, app: XCUIApplication, stage: String) throws {
        if !app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "→ ")).firstMatch.exists {
            let log = app.buttons["AI 處理紀錄"]
            reveal(log, app: app)
            log.tap()
        }
        let deadline = Date().addingTimeInterval(180)
        var scrolls = 0
        // Form rows are virtualized and can move while generation is still adding content.
        // Check and scroll together, rather than spending all scroll attempts before waiting.
        @MainActor func locate(_ element: XCUIElement, towardTop: Bool, name: String) throws {
            while Date() < deadline, scrolls < 32 {
                let visibleTop = app.frame.minY + 120
                // Keep drags above both the keyboard assistant and the pinned bottom action bar.
                let visibleBottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY - 80 : app.frame.maxY - 160
                if element.exists {
                    let frame = element.frame
                    if frame.height > 0, frame.maxY > visibleTop, frame.minY < visibleBottom {
                        checkpoint(stage + " " + name + " visible after \(scrolls) scrolls", app: app)
                        return
                    }
                }
                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0 else { break }
                if !element.exists {
                    let appeared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: element)
                    _ = XCTWaiter.wait(for: [appeared], timeout: min(3, remaining))
                    if element.exists { continue }
                }
                let moveTowardTop = element.exists ? element.frame.minY < visibleTop : towardTop
                let availableHeight = max(80, visibleBottom - visibleTop)
                let step = min(120, availableHeight * 0.3)
                let startY = moveTowardTop ? visibleTop + 30 : visibleBottom - 30
                let endY = moveTowardTop ? startY + step : startY - step
                let height = app.frame.height
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: (startY - app.frame.minY) / height))
                    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: (endY - app.frame.minY) / height)))
                scrolls += 1
            }
            checkpoint(stage + " " + name + " search exhausted after \(scrolls) scrolls", app: app)
            throw NSError(domain: "MessyNoteAcceptanceUI", code: 3, userInfo: [NSLocalizedDescriptionKey: "\(stage)：未在180秒／32次小幅捲動內定位\(name)；請依最後AX判斷工具或虛擬化狀態，不能只憑逾時判模型錯誤。"])
        }
        let calendar = app.staticTexts["→ CheckCalendarTool(\(start.formatted(date: .omitted, time: .shortened)))"]
        try locate(calendar, towardTop: false, name: "Calendar call")
        XCTAssertTrue(calendar.exists, "必須有指定時刻的真實Calendar工具activity。")
        let contact = app.staticTexts["→ FindContactTool(\(attendee))"]
        try locate(contact, towardTop: true, name: "Contact call")
        XCTAssertTrue(contact.exists, "同一草稿必須真正呼叫Contact tool。")
        checkpoint(stage + " both calls located", app: app)
    }

    @MainActor
    private func verifyNoConflicts(app: XCUIApplication, stage: String) throws {
        top(app)
        let empty = app.staticTexts["此時段沒有衝突（查詢當下）"]
        reveal(empty, app: app)
        try waitFor(empty, app: app, stage: stage)
    }

    @MainActor
    private func openReviewAndCancel(contact: String, reminder: Int, app: XCUIApplication, stage: String) throws {
        let save = app.buttons["檢查並加入"]
        reveal(save, app: app)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        try waitFor(app.staticTexts["最後確認"], app: app, stage: stage + " opened", timeout: 10)
        XCTAssertTrue(app.staticTexts[contact].exists)
        let reminderLabels = [reminder == 120 ? "兩小時前提醒" : "前一天提醒"]
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label IN %@", reminderLabels)).firstMatch.exists)
        let cancel = app.buttons["取消"]
        reveal(cancel, app: app)
        XCTAssertTrue(cancel.exists)
        checkpoint(stage + " before cancel; never confirm save", app: app)
        cancel.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.staticTexts["最後確認"])
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        XCTAssertFalse(app.staticTexts["已加入系統行事曆"].exists)
        checkpoint(stage + " dismissed", app: app)
    }

    @MainActor private func top(_ app: XCUIApplication) {
        for _ in 0..<6 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)))
        }
    }
    @MainActor private func scrollDown(_ app: XCUIApplication) {
        // Start inside the Form, above the keyboard, so the drag scrolls and dismisses it.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
    }
    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<16 {
            if element.exists {
                if element.isHittable && ["檢查並加入", "取消", "確認加入行事曆"].contains(element.label) { return }
                let frame = element.frame
                let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY - 80 : app.frame.maxY - 160
                if frame.height > 0, frame.minY >= 120, frame.maxY <= bottom { return }
                if frame.minY < 120 {
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                        .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)))
                    continue
                }
            }
            scrollDown(app)
        }
    }
    @MainActor private func waitFor(_ element: XCUIElement, app: XCUIApplication, stage: String, timeout: TimeInterval = 180) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        checkpoint(stage, app: app)
        guard result == .completed else {
            throw NSError(domain: "MessyNoteAcceptanceUI", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(stage)未在\(timeout)秒內完成；模型錯誤或不可用不算通過。"])
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
    private func normalized(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace }
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
