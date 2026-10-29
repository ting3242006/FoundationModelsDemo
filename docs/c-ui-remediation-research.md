# Simulator FoundationModels runner asset：唯讀修復研究

## 本機版本與可選 runtime（2026-10-22）

- `xcodebuild -version`：Xcode 27.1（27A9275）。
- `sw_vers`：macOS 27.0.1（26A434）。
- `xcrun simctl list runtimes`：已安裝 iOS 18.2（22C150）、iOS 26.0（23A343）、iOS 26.4（23E244）、iOS 27.0（24A5370g）；沒有列出 iOS 27.1 runtime。
- 指定裝置 `66FF8FF9-4132-4C55-92CC-1BCBA53F00A3` 是 Booted 的 iPhone 18 Pro／iOS 27.0；iOS 27.0 尚有 iPhone 18 Pro Max、iPhone 17 系列與多個 iPad 定義可建立。
- 這次 `simctl list` 成功取得清單。12:06 的 `CoreSimulatorService connection refused` 是另一個先前命令的連線結果，不能歸因為 sandbox 拒絕，也不足以證明 runtime 已崩潰。

## 本次錯誤與 host 對照

- `/private/tmp/messynote-c-ui-validation/runtime-diagnosis.md:11-14`：12:04:31.822 runner lookup 失敗，12:04:31.970 UnifiedAssetFramework Code 5000，12:04:32.071 App 收到 Model Catalog error。
- 同一 request 在 simulator 使用 `com.apple.fm.language.instruct_3b.fm_api_generic`；HostInferenceProviderService 記錄該 runner asset object 不存在。
- `/Users/yitingsung/Developer/FMDemo/docs/host-c-attempt2.log:1-21`：macOS host 的真 `SystemLanguageModel` 流程完成初次、revision、clock extraction 與 tools；這證明 host 路徑曾可推論，但該 log 沒有列出 asset bundle／catalog version，不能據此斷定與 simulator 使用同一 asset 版本。
- `/Users/yitingsung/Developer/FMDemo/EVIDENCE.md:108` 也限定 host 記錄是 macOS、memory fixtures，並非 iPhone simulator 或實機證據。

## Apple 官方／Apple Developer Forums 證據

- [Apple Developer Forums：Foundation Model Framework](https://developer.apple.com/forums/thread/787445) 中 Apple 員工說明 Simulator 沒有模型副本，`SystemLanguageModel` 會呼叫 Mac 上的模型；並說 Xcode、Simulator、macOS 需相符，否則會出現這類錯誤。
- 同一 Apple 員工建議版本至少 26.0 且相符，例如 Xcode 26.2、iOS Simulator 26.2、macOS 26.2；更新後模型 assets 可能需等待下載完成。該討論的實際錯誤亦是 `com.apple.modelcatalog`／UnifiedAssetFramework Code 5000，與本次字串相符。
- [Foundation Models 官方文件](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models) 說明可用性取決於裝置與地區，模型可能需要時間下載；因此 `availability == .available` 不是 runner asset 完整性檢查。
- [Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels) 說明模型會隨 iOS/macOS 版本更新而變，需按新模型版本再測 prompts；它沒有提供針對 Code 5000 的公開修復指令。

## 依證據的最多兩個低風險步驟

1. 透過 Xcode 的 Components／Platforms 安裝與 Xcode 27.1 相符的 iOS Simulator runtime，並把 macOS 更新至 Apple 對該 Xcode/runtime 要求的相符版本；之後在新建立的 simulator device 上等待模型 assets 完成下載再重試。依 Apple forum 的 simulator→Mac model 架構，這處理的是目前 27.1 Xcode、27.0 simulator、27.0.1 macOS 不齊且 catalog 缺 asset 的可驗證差異；不需先改 App source。
2. 若需立即驗證產品流程，改以已啟用 Apple Intelligence 的相容實機執行同一 UI flow。這避開 simulator 對 Mac model/catalog 的代理路徑，且能獨立驗證實機 availability、permissions 與生成；記錄時必須與 simulator 結果分開。

## 不確定性與未採取動作

- Apple Forum 是 Apple-hosted 且含 Apple 員工回覆，但不是保證 Xcode 27.1／iOS 27.0／macOS 27.0.1 這一特定組合的公開 release note；它支持版本對齊的修復方向，不能保證安裝後立即修好。
- 本任務未下載／更新任何 runtime、未建立或刪除 device、未重啟服務、未重跑模型，也沒有讀取真實 Contacts 或 Calendar。
- 本機 `find /Library/Developer/CoreSimulator/Profiles/Runtimes` 找不到該舊式路徑；已安裝 runtime 的事實以成功的 `xcrun simctl list runtimes` 為準。
