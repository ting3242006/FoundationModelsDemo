# B 分次驗證：整項尚未通過

所有結果保留 Failed，未把分次成功步驟合成一次 PASS。相同產品來源下只修改 UI 測試 helpers；達到同一輸入元件首次加兩次修正上限後停止，沒有再改 Swift／project 或重跑模型。

| 結果 | 實際停止點與證據界限 | 摘要 |
|---|---|---|
| 原 A–D suite | A/C/D 通過；B Select All 不存在，未發 follow-up | [3 passed / 1 failed](a-d-summary.json) |
| b-input-final | 清空後斷言未接受 placeholder，未生成 | [0 passed / 1 failed](b-input-summary.json) |
| b-placeholder-final | 初始及 follow-up 16:30、原日期、其他欄位、兩工具、選王小明均通過；review 顯示正確 `1,440 分鐘前提醒`，測試期待 `1440 分鐘前提醒`；未執行取消 | [0 passed / 1 failed](b-review-format-summary.json) |
| b-review-final | 等待預期 Calendar tool 逾時；失敗 AX 沒有 DatePicker、工具在可視區邊緣及下方，不能推論時間語意或仍為 15:00 | [0 passed / 1 failed](b-tool-wait-summary.json) |
| b-tool-scroll-final | Fixture 仍為 0，停在 setup；新 tool 定位 helper 未執行，並非 helper 或模型的失敗驗證 | [0 passed / 1 failed](b-fixture-off-summary.json) |
| b-fixture-final（最後） | Fixture 已 1；第149行清空輸入斷言失敗，尚未生成。AX 顯示 placeholder 且無 value，不能推測 XCTest value 為 nil 或非空，也不能宣稱殘留內容 | [0 passed / 1 failed](b-final-summary.json) |

前次核心流程：[16:30與保留欄位](b-preserved-fields.png)／[AX](b-preserved-fields.txt)、[真工具](b-followup-tools.png)／[AX](b-followup-tools.txt)、[選王小明](b-selected-wang.png)／[AX](b-selected-wang.txt)、[review正確提醒](b-review.png)／[AX](b-review.txt)。

最後失敗：[截圖](b-final-input-failure.png)／[AX](b-final-input-failure.txt)。failureText 是原測試字串，不單獨構成輸入實際殘留的診斷。

## 原始可重現來源

- `/private/tmp/messynote-timing-final/a-d-final.xcresult`（原 suite）；log `/private/tmp/messynote-timing-final-validation/a-d-final.log`。
- `/private/tmp/messynote-b-input-final-validation/b-final.xcresult`／`b-final.log`。
- `/private/tmp/messynote-b-placeholder-final-validation/b-final.xcresult`／`b-final.log`；診斷 `b-review-diagnosis.md`。
- `/private/tmp/messynote-b-review-final-validation/b-final.xcresult`／`b-final.log`；修正後診斷 `b-followup-time-diagnosis.md`。
- `/private/tmp/messynote-b-tool-scroll-final-validation/b-final.xcresult`／`b-final.log`。
- `/private/tmp/messynote-b-fixture-final-validation/b-final.xcresult`／`b-final.log`；最後建置 log `build-for-testing.log` 為 TEST BUILD SUCCEEDED、exit 0。
- 最後 xctestrun：`/private/tmp/messynote-b-fixture-final/Build/Products/MessyNoteAcceptanceUI_iphonesimulator27.1-arm64-x86_64.xctestrun`。

後續若另行授權修復，可用現有 binary 指定 B 執行（此文件收尾未執行）：

```sh
xcodebuild test-without-building -xctestrun /private/tmp/messynote-b-fixture-final/Build/Products/MessyNoteAcceptanceUI_iphonesimulator27.1-arm64-x86_64.xctestrun \
  -destination 'platform=iOS Simulator,id=<YOUR_SIMULATOR_UDID>' \
  -only-testing:MessyNoteUITests/ScenarioABUITests/testScenarioBAndFollowUp \
  -parallel-testing-enabled NO -collect-test-diagnostics never
```

新 tool 等待／捲動 helper 尚未實際驗證，不能標成 fixed PASS。所有測試均未按最終 Calendar 寫入確認；B review 取消尚未完成正式驗收。
