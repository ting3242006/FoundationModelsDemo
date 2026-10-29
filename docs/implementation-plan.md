# MessyNote Implementation Plan

> Worker 按此計畫及完整附件逐階段實作，禁止一次寫完才 build。

**Goal:** 在 /Users/yitingsung/Developer/FMDemo 建立獨立 SwiftUI iOS Demo，展示自然語言 → Guided Swift Type → 真實 streaming → 模型觸發唯讀 tools → 使用者確認後 EventKit save。
**Architecture:** PlannerView + @MainActor observable ViewModel；FoundationModelService 管理 session 與 partial results。DateResolver 與 CalendarAvailability 是純 Swift deterministic logic。Tool 僅注入唯讀 protocol；save capability 只在明確 UI action 的路徑。
**Tech Stack:** 本機 Xcode 27.1 / iOS SDK 27.1 / Swift 6.4；deployment iOS 27.0；Swift 6 strict concurrency；FoundationModels, SwiftUI, Contacts, EventKit, Swift Testing；無第三方 runtime dependency。

## Global constraints
- 不讀取、修改或依賴其他 repository；只建立 FMDemo。不得修改受保護政策檔。不要 commit/push/PR。
- 所有使用者溝通繁體中文，UI 可保留指定品牌英文，錯誤與說明採繁體中文。
- 不 fake streaming/inference；不用 regex 當 NLU、不經 JSON string decode。
- Model 必須自行發起 Tool.call；無工具呼叫時誠實顯示未查詢，不能假裝成功。
- 日期使用模型語意欄位（day offset / next-week weekday / explicit date / hour / minute）及 Swift Gregorian Calendar 計算。固定週一作一週起點；時區以當次 context 保存。缺少確切時間需要使用者確認，不猜晚上幾點。
- Availability 與錯誤分開處理；denied calendar/contacts 不毀掉已產生 draft。
- Contacts 多候選只由使用者選，不讓 model 偷猜。Tool output 最少資料，不曝光整份 address book。
- Conflict/slot UI 只使用 Swift tool ledger 證據；人工修改時間/attendee 後原證據失效。
- 保留 session 支援 follow-up，明確附 current draft context。取消後新 request 不與舊 session 重疊，generation token 阻擋舊 UI 更新。
- Save 不可暴露在 Tool protocol；保存前有可見 review，重複點擊不重複存。fixture mode 必須清楚不寫入 fixture 聯絡人/事件到系統。
- 每一階段先 build/test 成功才下一階段，完整 log 存專案外 /private/tmp/messynote-validation/。

## Phase 1 — Compile real framework
- 建立 MessyNote.xcodeproj（可用現有 xcodegen）、App entry、AvailabilityView/ModelState、Info.plist/usage strings。
- 引用 FoundationModels，實際初始化 LanguageModelSession(model: SystemLanguageModel.default)，依 availability / supportsLocale 顯示原因。
- 執行 generic iOS Simulator build（不需要 boot simulator）；失敗先修正再繼續。

## Phase 2 — Guided type and deterministic dates
- Models/EventDraft.swift @Generable & @Guide；日期語意獨立型別，避免直接生成 Date。
- Services/DateResolver.swift；先撰寫 representation→date 失敗測試，再完成邏輯。測試 tomorrow / next Wednesday / hour=15 / 60min / invalid dates / week & month boundary。
- FoundationModelService respond(generating: EventDraft.self) 最小 happy path，提供當下日期、timezone、locale。
- Build 並紀錄 checkpoint。

## Phase 3 — Real partial streaming
- 改為 streamResponse(generating: EventDraft.self)，隨 Snapshot.content 更新 Event Card。
- loading/cancel/restart；final validation 不讓 partial 被儲存；同 session follow-up + current draft context。
- Build；不要 timer、不要假結果。

## Phase 4 — Model-invoked tools
- ContactService + FindContactTool；最小 name/identifier；permission/on-demand/limited/0/1/multiple。
- CalendarService read-only interface + CheckCalendarTool；query 半開區間、deterministic available slots（有界時間範圍，包含所有 busy intervals），inference 發起 call。
- 可採 draft 完成後 model review turn，tool 使用確定 draft context，避免自行轉日期。所有回傳以 generation ID 與 draft fingerprint 綁定，UI 用實際 tool ledger 保障建議真實性。
- AI Activity 由真實 stream/tool lifecycle 更新。
- Tests first：contact candidate 0/1/multiple；15–16 conflict → verified slot；no conflict / overlapping events / boundary。
- Build/tests。

## Phase 5 — User confirmation and save
- UI 可編輯 title/date/time/duration/location/notes/reminders、contact picker、接受經計算 slot。
- 只在 explicit user confirmation handler 呼叫 EventKit.save；NSCalendarsFullAccessUsageDescription / NSContactsUsageDescription 正確。
- Safety spy test：generate/tools 不 save、explicit action 才 save、重複點擊/取消/過期 draft 保護。
- Build/tests。

## Phase 6 — Debug-only fixtures
- #if DEBUG DemoFixtures（小明多候選可測、Amy、固定 next Wednesday 15:00 conflict，16:00–16:30 buffer event 得到16:30）。Mode switch resets/cancels session & state。
- Fixture replaces only read services，inference 真實；最後仍由使用者明確確認寫入真實系統 Calendar，confirmation 要清楚說明正在儲存示範資料，fixture setup 本身不得寫入。
- Build/tests Debug；Release build 確認不暴露 mode controls。

## Phase 7 — Complete tests
- 執行 deterministic full suite：DateResolver / CalendarAvailability / ContactResolution / SaveBoundary / stale-generation & edit invalidation。
- Scenario A–F 建證據表：unit/static/simulator/device 各自標示，不把未跑推論標成 PASS。

## Phase 8 — UI and delivery
- SwiftUI native styles，Dynamic Type、VoiceOver label、窄畫面與鍵盤、loading/error/success、availability refresh。
- README：能力、架構 Mermaid、安裝開啟、實際版本、API 對照、90秒腳本、5–10分鐘延伸、隱私、日期規則、permission、fixtures、風險與三大優先修補。
- EVIDENCE.md：每階段命令、exit code、log、最終完整 build/test，哪些實機未驗證。
- 交付完整報告 /private/tmp/messynote-implementation-report.md，主對話執行最終完整驗證；不宣稱 MERGE_READY。
