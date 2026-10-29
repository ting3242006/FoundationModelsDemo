# UI 測試追加修復完成

2026-10-27：已達 `IMPLEMENTATION_COMPLETE`。62 項單元測試及完整 5 項 UI 測試全數通過，0 失敗、0 跳過；兩個 xcodebuild 均 exit 0。未 commit，未建立 PR；本次不涉及 `MERGE_READY`。

## 修正範圍

本輪只修改 `MessyNoteUITests/CaseCUITests.swift` 與 `MessyNoteUITests/ScenarioABUITests.swift`。35 個 App Swift 檔及 Scenario D 測試與本輪開始時一致，保留原生筆記工作室設計、現有功能與確認流程。

- Case C：AI 紀錄按鈕原本被固定底欄遮住，輸入框也可能落在頂部導覽列後方。點擊前檢查整個控制項位於可操作範圍，展開後等待真正工具紀錄出現。
- Scenario B：鍵盤與固定底欄可能遮住輸入框和「整理成活動」。改以兩者的實際位置判定安全範圍，從輸入框外側慢速拖曳、停穩後量測；僅鍵盤消失時重新取得焦點，並檢查最後一次拖曳結果。
- 示範查詢開關：保留第一次點擊；若仍關閉，第二次改為沿實際開關滑軌向右拖曳。維持兩次操作上限及開關狀態斷言。

保留文字選取／清空、完整中文輸入、日期時間、聯絡人、工具紀錄、衝突、權限拒絕及確認取消等既有斷言。沒有增加重試次數、放寬模型等待上限、跳過情境或注入生成結果。UI 測試使用真 Foundation Models；示範資料只替代查詢，測試不確認建立行事曆事件。

## 最終驗證

| 套件 | 結果 | 原始證據 |
| --- | --- | --- |
| 完整單元測試 | 62 通過／0 失敗／0 跳過，exit 0 | `/private/tmp/fmdemo-followup-final-unit.xcresult` |
| 完整 UI 測試 | 5 通過／0 失敗／0 跳過，exit 0 | `/private/tmp/fmdemo-verified-ui.xcresult` |

完整 UI 包含 Case C、原生編輯與確認取消、Scenario A、Scenario B 與後續修改、Scenario D 權限拒絕。執行未使用 `only-testing` 或 `skip-testing`。

開關拖曳 fallback 在本輪原生編輯情境的第二次操作實際觸發並成功（`fmdemo-verified-ui.log:702`）；A、B 的第一次點擊即成功。最終 38 個 Swift 檔 hash 與保存清單完全一致。

單元測試通過後只調整 UI 測試操作；App 與單元測試來源未變。最終 UI 建置成功。專案沒有額外 lint 指令；既有 strict concurrency 編譯與 build/test 為驗證入口。

## 追溯紀錄

歷史失敗均保留，未以最終成功覆蓋原始證據：

| 證據 | 當時結果與處理 |
| --- | --- |
| `fmdemo-ai-log-focused.xcresult` | Case C 的 AI 紀錄定位修正定向通過。 |
| `fmdemo-ai-log-full-ui.xcresult` | 4 通過、1 失敗；發現 B 輸入框被底欄遮擋。 |
| `fmdemo-input-focused.xcresult` | 首次候選誤套無底欄初始輸入；限縮範圍後 `fmdemo-input-focused-2.xcresult` 通過。 |
| `fmdemo-followup-final-ui.xcresult` | C 的後續輸入被頂欄遮住；中止的非完整套件，exit 75。 |
| `fmdemo-case-c-input-focused.xcresult` | 自動化連線停滯，屬基礎設施故障，未取得功能判定。 |
| `fmdemo-case-c-input-reboot.xcresult` | 重啟專用模擬器後，C 定向通過。 |
| `fmdemo-all-ui-final.xcresult` | 4 通過、1 失敗；B 的送出按鈕被底欄遮擋。 |
| `fmdemo-submit-focused.xcresult` | B 輸入捲動來回過衝，未到送出步驟；追加可控拖曳。 |
| `fmdemo-controlled-scroll-focused.xcresult` | B 全流程通過；輸入與送出各一次拖曳即穩定進入安全範圍。 |
| `fmdemo-complete-ui.xcresult` | 4 通過、1 失敗；B 的示範開關兩次點擊後仍關閉，模型未執行。 |
| `fmdemo-verified-ui.xcresult` | 補強開關第二次操作後，完整 5 項通過。 |

以上原始 xcresult 均位於 `/private/tmp/`。詳細診斷與歷次報告保存在同位置；本目錄保存正式摘要、最終來源 hash、範圍與完整差異。

## 重播命令

共同參數：`xcodebuild -project /Users/yitingsung/Developer/FMDemo/MessyNote.xcodeproj -parallel-testing-enabled NO -collect-test-diagnostics never`。

- Unit：`-scheme MessyNote -destination 'platform=iOS Simulator,id=86A04964-BCB3-4819-BDA5-0B4311BBCC9C' -derivedDataPath /private/tmp/fmdemo-studio-parent-dd -resultBundlePath NEW_UNIT.xcresult test`。
- UI 前置：`xcrun simctl privacy 280085F1-11D0-4221-B90F-59FD4226E464 reset calendar com.demo.MessyNote`。
- UI：`-scheme MessyNoteAcceptanceUI -destination 'platform=iOS Simulator,id=280085F1-11D0-4221-B90F-59FD4226E464' -derivedDataPath /private/tmp/fmdemo-studio-dd -resultBundlePath NEW_UI.xcresult test`。

重新執行須使用新的 resultBundlePath，以保留證據。測試會開啟示範查詢並使用真模型，但不確認儲存。
