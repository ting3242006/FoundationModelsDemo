# 歷史v10驗證：C通過，A失敗、B取消、D未跑

**58項unit全通過、unsigned generic iOS Release exit0／BUILD SUCCEEDED；C真模型UI單次完整PASS。** [Unit摘要](unit-summary.json)、[C摘要](c-summary.json)、[建置命令與結果](build-results.txt)。後續A正式FAIL；B於尚未完成時取消，D未執行。[中斷證據](abd-interrupted-evidence.md)保存原始verdict，不用v7／v8的B成功代替本輪結果。

C使用真實FoundationModels、Unicode中文typeText及唯讀fixture providers。初次只有模糊時段，保留Friday 2026-10-30且待補時間；follow-up後維持同日19:00／60分鐘／阿不存在，模型真正呼叫兩個工具並取得空結果。沒有手動指定picker或Calendar寫入。

| 階段 | 可攜證據 |
|---|---|
| 固定Friday pending | [圖](c-fixed-friday.png)／[AX](c-fixed-friday.txt) |
| 真中文follow-up | [圖](c-followup.png)／[AX](c-followup.txt) |
| 同日期19:00與欄位 | [圖](c-event.png)／[AX](c-event.txt) |
| Contacts空結果 | [圖](c-contacts.png)／[AX](c-contacts.txt) |
| Calendar空結果 | [圖](c-calendar.png)／[AX](c-calendar.txt) |
| FindContact／CheckCalendar真calls | [圖](c-tools.png)／[AX](c-tools.txt) |

[診斷原文](clock-diagnostics.txt)保留跨版本時序。v10 18:14初次explicit=false、hour/minute=nil；follow-up的revision只列attendee，Swift保留固定日期及缺時間狀態，fresh clock判explicit=true、19:00，review.start為2026-10-30T11:00:00Z（台北19:00）。這證明本次確有走pending額外clock路徑，不只碰巧一般revision抽對time。

## v7→v10歷史與修正

- v7：ClockCompletion.minute改optional，明確hour而無minute時Swift用0；B曾單次完整PASS、56unit通過。[v7證據](../v7/verification.md)保留。其後C先在fixture setup失敗，修正內層switch後出現18:00；當時initial猜時間的假說後來被診斷修正，不能把C寫PASS。
- v8：initial一律以fresh clock作最後時刻依據；沒有明確hour就清除初稿猜測，revision/pending通用語義不變。57unit通過，B再次完整PASS但C仍FAIL；[原B/C混合摘要](historical-v8-bc-summary.json)保留1pass／1fail。診斷證實fresh clock本身將晚上變18，非舊ledger或未提交。
- v9：新增首先生成、無預設的hasExplicitStartTime。Swift對false拒絕數值時間，initial回pending；true且minute=nil才轉整點0。58unit通過；C初次false正確，但明確中文follow-up也被判false，所以[C結果仍FAIL](historical-v9-c-summary.json)。
- v10：只校正兩檔繁中Guide／prompt，明確區分只有時段與時段加中文鐘點；型別、Swift策略、UI輸入與斷言未改。本輪C完整通過，不宣稱模型每次都穩定或例子干擾已證因果。

所有真實失敗保留；沒有regex主NLU、驗收句特判、假模型或注入結果。v8與v9分別先以新unit取得行為red，再full green；prompt文字不寫鏡像單元測試。通用ClockCompletion.applying的false／nilhour不改原稿；只有initial生成流程可以清掉猜測。明確time清除與revision allowlist保持既有規則。

Debug OSLog僅env MESSYNOTE_ACCEPTANCE_DIAGNOSTICS=1才開，記錄explicit、日期／時分、欄位mask與generation；沒有note、title、姓名、地點、notes。Release不含此診斷。

## 尚未完成範圍

A正式FAIL、B被取消、D沒有結果；最新v11撤回額外initial閘門，見[v11說明](../v11/verification.md)。E僅兩個官方Run診斷分支通過，locale仍INCONCLUSIVE、AI disabled未驗。F須相容實機模型就緒後實際飛航驗證。最近[17:56裝置查核](device-1756.md)為15Plus connected、17Pro unavailable；Team未選、無App實機部署或模型就緒證據，最終結果後將再刷新連線。

來源：`/private/tmp/messynote-clock-language-v10-validation/`的sealed C／unit結果及build logs；[附件來源對照](selected-attachments.json)保留原始檔名，不複製巨大xcresult或完整device ID。


## v10圖證標註校正

原始附件名`06 completed event screenshot`（EE1CBA92-2FC5-407D-9AD7-9A79BDA80EEF.png）實際仍是partial／loading，不能作為最終19:00截圖證據，本資料夾未複製或引用該圖。19:00以[c-event AX](c-event.txt)、[Calendar AX](c-calendar.txt)及18:14診斷互相核對；[最後工具圖](c-tools.png)（原93F3C7A7…）才是終態工具結果。c-event.png是較晚欄位checkpoint的畫面，其命名本身不是時刻正確的證明。
