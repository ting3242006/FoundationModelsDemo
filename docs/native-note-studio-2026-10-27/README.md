# MessyNote 原生筆記工作室

2026-10-27 追加修復已完成：62 項單元測試與完整 5 項 UI 測試全數通過，0 失敗、0 跳過，已達 IMPLEMENTATION_COMPLETE。詳見 [UI 測試修復報告](ui-test-fix.md)。下方原始 UI 測試失敗與停止紀錄保留為歷史證據。

使用者已於 2026-10-27 批准「原生筆記工作室」方向，保留既有功能與確認流程。

## 實作範圍

- 主畫面改為分組卡片：隨手筆記、活動預覽、聯絡人與行事曆查詢、可收合的 AI 處理紀錄。
- iPhone 單欄，寬度足夠的 iPad 雙欄；輔助使用字級改回單欄。支援系統深淺模式。
- 活動先顯示摘要，再展開編輯。手機產生活動後收合筆記，寬版保留輸入區供後續修改。
- 主要動作依序為「整理成活動」、「檢查並加入」、「確認加入行事曆」。最終確認保留取消、真實寫入警告、快照說明、儲存中鎖定。
- 保留缺少時間補充、候選聯絡人、未解析姓名、衝突與未知狀態、建議時段、取消生成、重置及原始診斷。
- 僅修改 PlannerView.swift、EventEditorView.swift、SaveReviewView.swift 三個 production 檔；另外三支 UI tests 適配新的操作入口與展開流程。
- 未變更 ViewModel、模型與工具、服務、權限時機、專案設定或儲存邏輯；32 個其他 production Swift 檔與改版前 hash 一致。

## 驗證與界線

- 最終 production 單元測試：62 通過、0 失敗、0 跳過。`/private/tmp/fmdemo-studio-final-unit.xcresult`。
- 最終 production 的 Scenario D：拒絕行事曆權限時保留草稿並呈現未知狀態，1 通過。`/private/tmp/fmdemo-studio-final-d.xcresult`。
- UI 測試使用真 Foundation Models；示範模式僅替代聯絡人與行事曆查詢，不注入生成結果。
- 所有 UI 驗證都停在確認前或取消確認，沒有建立行事曆事件。實際儲存邊界由既有單元測試覆蓋。
- 已人工查看最終 iPad 深淺模式、最大輔助字級，以及測試畫面；這不等同完整 VoiceOver 或所有裝置的無障礙稽核。
- 編譯成功。Xcode 測試建置有既有的無 AppIntents 相依資訊擷取警告，執行時有 orientation 設定提醒，未擴張範圍修改專案設定。

## 可追溯資料

- 原始備份：`/private/tmp/fmdemo-native-studio-baseline/`。
- 最終 hash 範圍證據：`/private/tmp/fmdemo-studio-delivery-scope.json`。
- 完整實作及歷次測試紀錄：`/private/tmp/fmdemo-studio-worker-report.md`。
- 無 Git repository；未初始化 Git、未 commit、未建立 PR。`MERGE_READY` 不在本次交付範圍。

## 前次 UI 測試補充證據（歷史）

第一次補充只修改兩個測試的 switch 點擊位置：由整列中心改為真實 switch track 的左側 thumb。保留狀態斷言、最多兩次操作以及所有功能條件。`/private/tmp/fmdemo-studio-evidence-1.xcresult` 結果為 3 通過、1 失敗、0 跳過（exit 65）：Native 編輯／確認取消、Scenario A、Scenario B 與後續修改均通過。

Case C 的截圖及 AX (`E2D020FB-3417-4C64-B139-5A7FED3735E4.txt`) 明確記錄 `eventEditorDisclosure Disabled`，模型工具仍在處理。原測試看見 typed streaming 預覽就點擊編輯，沒有等待控制項啟用。第二次補充僅在 C 加入 `exists && enabled` 等待，沿用 180 秒的模型操作上限；不改 production、不減少日期／時刻／參與者／工具證據斷言。這是最後一輪獨立驗證工具補強。

第二次補充結果：Case C 仍失敗，exit 65。日期、19:00 時刻、60 分鐘、參與者姓名、空白聯絡人與無衝突結果斷言均已走過；最後讀取 `→ FindContactTool(阿不存在)` 時找不到節點。失敗 AX 顯示 AI 紀錄仍收合，尚未確認是測試點位或互動問題。不能將這項失敗視為通過，也不能宣稱所有功能已完整驗收。

前次交付結果（已由上述追加修復取代）：build 成功、62 個單元測試通過；5 個 UI 情境中 Native、A、B、D 通過，C 未通過（各切片均無跳過）。C 之外的 production 與測試未受最後三行同步補強影響，未重跑無關測試。依 `/Users/yitingsung/.codex/harness/model-dispatch.md` 的 implementation 與 evidence remediation 上限停止追加修正。狀態為**已實作、驗收尚未全綠；未達 IMPLEMENTATION_COMPLETE**。

最後 C 證據：`/private/tmp/fmdemo-studio-evidence-2.xcresult`，`/private/tmp/fmdemo-studio-evidence-2.log`，`/private/tmp/fmdemo-studio-evidence-2-artifacts/2732EE02-3EDF-4235-BD66-03A5E00E8824.txt`。未解決項目是 Case C 的 AI 紀錄展開／定位驗收，不是日期補充失敗。

## 重播命令

共同參數：`xcodebuild -project /Users/yitingsung/Developer/FMDemo/MessyNote.xcodeproj -parallel-testing-enabled NO -collect-test-diagnostics never`。

- Unit：`-scheme MessyNote -destination 'platform=iOS Simulator,id=86A04964-BCB3-4819-BDA5-0B4311BBCC9C' -derivedDataPath /private/tmp/fmdemo-studio-parent-dd -resultBundlePath /private/tmp/fmdemo-studio-final-unit.xcresult test`，exit 0。
- D：同 iPad／DerivedData，`-scheme MessyNoteAcceptanceUI -only-testing:MessyNoteUITests/ScenarioDUITests -resultBundlePath /private/tmp/fmdemo-studio-final-d.xcresult test`，exit 0。
- Native/A/B/C：`-scheme MessyNoteAcceptanceUI -destination 'platform=iOS Simulator,id=280085F1-11D0-4221-B90F-59FD4226E464' -derivedDataPath /private/tmp/fmdemo-studio-dd -only-testing:MessyNoteUITests/ScenarioABUITests -only-testing:MessyNoteUITests/CaseCUITests -resultBundlePath /private/tmp/fmdemo-studio-evidence-1.xcresult test`，exit 65（3 通過、1 失敗）。
- C 最後切片：同 phone／DerivedData，僅 `-only-testing:MessyNoteUITests/CaseCUITests -resultBundlePath /private/tmp/fmdemo-studio-evidence-2.xcresult test`，exit 65（1 失敗）。

再次執行時需使用新的 resultBundlePath，現有 xcresult 保留為原始證據。測試會開啟示範查詢、使用真模型，但不確認儲存。
