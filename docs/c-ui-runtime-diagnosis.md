# MessyNote iOS Simulator UI 推論錯誤：唯讀診斷

## 結論

- 12:04:32 的 UI `FoundationModels.LanguageModelError error -1` 對應到模擬器的 Model Catalog／HostInferenceProvider 資產失敗；不是筆記、fixture Contacts/Calendar、或 App 內日期合併邏輯在該次請求前拋出的錯誤。
- 根據同一請求的系統記錄，iOS 27.0 simulator runtime 載入後找不到 `com.apple.fm.language.instruct_3b.fm_api_generic` 的 runner asset，隨後 Model Catalog 回報 UnifiedAssetFramework Code 5000「沒有 underlying assets」。
- 此次資料不足以把 UIKit/CUA 顯示的 `LanguageModelError error -1` 精確映射為公開 enum case；系統 log 沒有該字串，但在其前後記錄了上述底層 ModelManager error。

## 精確 runtime 時序（Asia/Taipei）

- `2026-10-22 12:04:28.865`：`MessyNote[88077]` 對 ModelManager 發送 streaming execute request `FBB9B43B-A49B-4283-B184-6608E1B012AE`。
- `2026-10-22 12:04:31.822`：`HostInferenceProviderService[88368]` 回報 `InferenceError::notLoaded::Failed to look up runner asset object for asset bundle com.apple.fm.language.instruct_3b.fm_api_generic`。
- `2026-10-22 12:04:31.970`：`modelmanagerd[88367]` 對 base/tokenizer/fm_api_generic/draft/image_encoder 回報 `UnifiedAssetFramework Code=5000`；訊息為「There are no underlying assets ... for asset set com.apple.modelcatalog」。
- `2026-10-22 12:04:32.071`：`MessyNote[88077]` 收到相同 Model Catalog error；`12:04:32.075-077` token generation 記錄「couldn't be converted to a TokenGenerationError」與 `not GenerativeError`。
- 上述證據由唯讀指令 `xcrun simctl spawn 66FF8FF9-4132-4C55-92CC-1BCBA53F00A3 log show --start ...` 讀取；UDID 對應本次指定 iOS 27.0 simulator。

## 可用性與 App 配置證據

- `/Users/yitingsung/Developer/FMDemo/MessyNote/AI/ModelState.swift:8-20`：UI 啟用條件僅是 `availability == .available` 且 locale supported；它不會驗證 runner asset 是否可執行。因此「裝置端模型可使用」可與本次 execute 失敗並存。
- `/Users/yitingsung/Developer/FMDemo/MessyNote/Feature/Planner/PlannerViewModel.swift:58-80`：按鈕先檢查 available、建立 task，再直接呼叫 `service.generate`；沒有在初次生成前呼叫 Contacts 或 Calendar。
- `/Users/yitingsung/Developer/FMDemo/MessyNote/Feature/Planner/PlannerViewModel.swift:100-109`：錯誤由 `ModelErrorPresentation` 顯示，無 draft／event 的 early runtime failure 會停在這裡。
- `/Users/yitingsung/Developer/FMDemo/MessyNote/AI/ModelErrorPresentation.swift:6-16`：未列舉的 `LanguageModelError` 會直接顯示 `localizedDescription`，故 UI 的 `error -1` 沒有更細分類。
- `/Users/yitingsung/Developer/FMDemo/project.yml:3-25`：iOS 27.0 target、`com.demo.MessyNote` bundle ID，以及 Contacts/Calendar usage strings 均存在；這些權限尚未介入此次 generation error。
- `/Users/yitingsung/Library/Developer/XcodeBuildMCP/workspaces/FoundationModelsDemo-1b099d4986f5/logs/build_run_sim_2026-10-22T03-48-17-210Z_pid49153_8a40476d.log:151`：該 simulator build 為 `BUILD SUCCEEDED`，並以 iPhoneSimulator27.1 SDK、arm64 iOS 27.0 simulator target 編譯。

## runtime 狀態的限定

- 同一段系統 log 在 12:04:20 及 12:04:30 顯示 ModelManager 嘗試／宣稱載入 assets，但 request 實際執行時 runner lookup 失敗，且隨即 catalog 無 assets；成功 prewarm 不能當作成功推論證據。
- 12:06:30 本機後續 `simctl getenv` 讀取時，CoreSimulatorService 已回 `Connection refused`／`simdiskimaged ... crashed or is not responding`。這發生在本次 12:04 execute error 之後，不能由現有資料證明為前因。

## 依證據的下一步（至多兩項）

1. 修復或更新該 iOS 27.0 simulator runtime 的 Model Catalog／重新建立乾淨的同版本 simulator 後，再用同一 UI 請求重試；若仍出現 Code 5000，保留 `simctl log show` 的相同時窗作 runtime 問題證據，無須先改 App。
2. 在已啟用 Apple Intelligence 的相容實機做同一 flow；這可區分 simulator runner asset 故障與實機 FoundationModels 可用性，且仍必須把實機結果與 simulator 結果分開記錄。
