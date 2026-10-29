# 既有工具鏈／更新狀態唯讀查證

## 直接結論

目前無法在「不升級 macOS、不下載完整 Xcode 或 Simulator runtime」的條件下，改用既有工具鏈來嘗試修正 iOS 27.0 Simulator 的 Foundation Models runner asset 缺失：`/Applications` 內只有一個實際 Xcode 開發工具鏈，即 Xcode 27.1。

本機也沒有可供切換的 `/Applications/Xcode 27.0.app`。`/Applications/Xcodes.app` 是 Xcodes 管理程式，並非第二個 Xcode toolchain；其存在不能提供 iOS 27.0 SDK/runtime。

## `/Applications` 實測範圍

搜尋命令：`find /Applications -maxdepth 1 -type d -name 'Xcode*.app' -print`。

結果：`/Applications/Xcode.app` 與 `/Applications/Xcodes.app`，未列出其他 `Xcode*.app`。

`/Applications/Xcode.app/Contents/Info.plist`：`CFBundleShortVersionString=27.1`、`CFBundleVersion=25183.120.5`、`DTXcode=2710`、`DTXcodeBuild=27A9274`。

`xcode-select -p` 的唯讀結果為 `/Applications/Xcode.app/Contents/Developer`；本次沒有變更它。

`/Applications/Xcodes.app/Contents/Info.plist`：`CFBundleShortVersionString=4.1.1`。此項僅辨識 app bundle，未將它當作 Xcode toolchain。

## macOS 更新目錄的本次讀取

`sw_vers`：macOS 27.0.1（Build 26A434）。

`softwareupdate -l` 本次僅列出「Command Line Tools for Xcode 27.0-27.0」，版本 27.0、約 519460 KiB、Recommended YES。

此結果沒有列出 macOS 27.1；它只能說明當時 Software Update 回傳的目錄中沒有列出該更新，不能據此證明 macOS 27.1 對此 Mac、帳號、更新通道或 MDM 設定永久不可用。

Command Line Tools 不是完整 Xcode.app，也不會構成可選取的 iOS Simulator／Foundation Models toolchain；本次未安裝它。

## Apple 官方資料

Apple 的 [Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes) 表示 Xcode 27.1 含 iOS 27.1 SDK，且要求 macOS Tahoe 26.6 或後續版本。該頁面本次全文搜尋未出現「Foundation Models」、「model catalog」或 iOS 27.0 Simulator 模型資產選擇機制。

Apple 的 [Xcode system requirements](https://developer.apple.com/xcode/system-requirements) 將 Xcode 27.1 列為支援 iOS 15–27 deployment targets、iOS 17+ Simulator runtimes；這是部署／runtime 支援資訊，沒有聲稱 Xcode 27.1 能為 iOS 27.0 Simulator 選擇或補齊 Foundation Models runner asset。

Apple Developer Forums 的 Apple staff 回覆：[Foundation Models Error -1](https://developer.apple.com/forums/thread/787445)，說明 Simulator 不含模型副本、會使用 Mac 上的模型，並要求 Xcode、Simulator 與 macOS 版本對齊。這是 Apple-hosted forum 的支援說明，並非 Xcode 27.1 release note 的可切換模型功能文件。

## 與本次 runner asset 失敗的關係

先前同一診斷已記錄 iOS 27.0 Simulator 在 HostInferenceProvider 回報 `Failed to look up runner asset object`；此查證沒有找到官方文件可讓 app 或 Xcode 27.1 在既有 iOS 27.0 runtime 中手動選用另一份 Foundation Models asset。

主機 harness 成功只能證明該 Mac 的 host Foundation Models 路徑曾可生成；其 log 不含 Simulator runtime asset/catalog 版本，不能證明它與 iOS 27.0 Simulator 的 asset 相符。

因此，現有安裝中沒有可驗證的「切換至 Xcode 27.0」低成本修復。另行取得完整舊版 Xcode 或 iOS runtime 屬於下載新元件，且本查證沒有證據保證會修復 runner asset 缺失。

## 不確定性與界限

稍早的 `simctl list runtimes` 曾成功列出 iOS 27.0；之後一次 CoreSimulatorService connection invalid 僅表示該次服務連線失敗，不能當成 Simulator runtime crash 或 asset 根因。

本報告只讀取 `/Applications` 的 `Xcode*.app`、系統版本／Software Update 清單與 Apple 公開資料；沒有啟動更新、下載、切換 `xcode-select`、重啟或修改 Simulator。
