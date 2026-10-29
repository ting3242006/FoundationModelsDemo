# v12：時刻片段核對與驗收結果

**同一v12來源／建置：62項unit通過；A–D共4項真UI測試全部通過；UI／unit建置與generic iOS unsigned Release皆exit0。** [Unit摘要](unit-summary.json)、[命令與結果](build-results.txt)。BC與AD分兩次序列執行，兩份原始摘要均為2 passed／0 failed／0 skipped，不以不同產品版本拼接通過。

| 測試 | 時間 | 結果與重點 |
|---|---:|---|
| A | 128.329秒 | 明天16:00、30分鐘、120分鐘提醒、Amy Chen、無衝突、review開啟與取消 |
| B | 245.649秒 | 初次15:00／60分鐘／前一天提醒、兩候選與衝突；follow-up16:30保留原日期及欄位、重新兩工具無衝突、選王小明、review取消 |
| C | 73.690秒 | 只有晚上保持10/30待確認；真中文補19:00後60分鐘／阿不存在，真工具0結果 |
| D | 69.276秒 | 真Simulator Calendar prompt拒絕，明天16:00／30分鐘草稿保留，Calendar未知且有拒絕說明 |

[BC sealed摘要](bc-summary.json)、[AD sealed摘要](ad-summary.json)。兩個xcodebuild均exit0／TEST EXECUTE SUCCEEDED。

## 最小修正

ClockCompletion新增`clockPhrase: String?`，要求從本次USER_INPUT逐字引用明確活動開始鐘點。再依片段判斷`hasExplicitStartTime`及時分，使同句的時長／提醒不應否定另一個明確鐘點。欄位排列是設計意圖，不宣稱API保證生成順序或推理鏈。

Swift只檢查分類為true、片段非空且原文contains該片段；不自行解析鐘點，不用regex、中文數字規則或驗收句特判。核對失敗正規化為false／nil。substring核對只能排除不在原文的片段，不能證明模型語意正確；只有「晚上」仍須由模型判為不明確。

既有缺hour才補抽入口保持；已有hour不追加此模型呼叫。明確hour存在時，未說分鐘的nil由Swift採0；範圍校驗與time-only merge仍保留日期／非時間欄位。service真正typed streaming完成後核對再回傳，DEBUG診斷只記sourceAccepted／explicit／時分，不記原文或片段。

## TDD與實測界限

新增nil、空字串、空白、不在原文的片段測試，舊identity helper正式red：1個參數測試、4案例、exit65。實作後全62項green；另涵蓋中文混合句、數字分鐘、false分類不因substring存在而通過，以及缺片段不能套用數字時刻。既有非法、日期、明確清空、取消及過期generation保護均保留。

v11的C與A分別實測PASS；B缺hour後fresh clock卻回false，主對話停止該suite，exit75。B沒有完整verdict，D未跑。v12不把停止視為B測試FAIL，也不把不同版本的局部PASS合併成整套通過。

本輪B已完整通過，並直接觀察initial hour=nil、fresh sourceAccepted=true／explicit=true／hour15／minute0，接著review為10月28日15:00。這證明當次走過新增片段補抽路徑，不保證模型永遠穩定。[診斷摘要](clock-diagnostics.txt)保存這條路徑與follow-up time mask；A/D同版回歸亦已通過。

E仍為兩個官方診斷分支通過、locale未定與AI disabled未驗；F的相容實機飛航推論未驗證。沒有最終Calendar寫入或實機部署的主張。

## B/C可攜附件

- B：[清空後raw](b-input-cleared.txt)、[輸入後raw](b-input-replaced.txt)、[initial真工具](b-initial-tools.png)／[AX](b-initial-tools.txt)、[兩候選](b-two-candidates.png)。
- B follow-up：[16:30工具](b-followup-tools.png)／[AX](b-followup-tools.txt)、[保留欄位](b-preserved-fields.png)／[AX](b-preserved-fields.txt)、[review](b-review.png)／[AX](b-review.txt)、[取消後](b-canceled.png)／[AX](b-canceled.txt)。取消後圖是Form，不是仍顯示確認sheet。
- C：[待確認固定Friday](c-fixed-date.png)／[AX](c-fixed-date.txt)、[真正中文follow-up](c-followup-input.png)／[AX](c-followup-input.txt)、[完成欄位](c-final-fields.png)／[AX](c-final-fields.txt)、[兩工具0結果](c-tools.png)／[AX](c-tools.txt)。完成欄位截圖只看到姓名與60分鐘，日期／19:00在同附件AX及診斷核對，不把視窗外內容說成圖上可見。
- [來源對照](selected-attachments.json)只選精簡附件，未複製巨大xcresult。這是相同v12來源上的兩項完整測試，不拼接失敗run。

B/C使用真實Foundation Models、typed streaming及模型發起工具呼叫；只有readonly Contacts/Calendar providers為fixtures。沒有手動picker設定、沒有建立Contacts或最終Calendar寫入，不是實機權限整合。

## 歷史23:36裝置清單

[23:36 CST唯讀快照](device-connection-redacted.md)：iPhone15Plus connected、iPhone17Pro available（paired）。當時available/paired清單本身不證明實際連接、App部署或模型就緒；23:37直接preflight已確認connected，最新狀態見下節。這是當時較17:56新的清單，後續23:37直接preflight見下節；歷史快照不覆寫。

## A/D可攜附件

A：[草稿欄位](a-fields.png)／[AX](a-fields.txt)、[Amy Chen](a-amy.png)／[AX](a-amy.txt)、[review取消前](a-review.png)／[AX](a-review.txt)、[取消後](a-canceled.png)／[AX](a-canceled.txt)。完整值以對應AX與測試斷言核對，不把視窗外欄位說成截圖直接可見。

D：[真系統prompt](d-system-prompt.png)／[AX](d-system-prompt.txt)、[拒絕說明](d-denied.png)／[AX](d-denied.txt)、[Calendar未知](d-unknown.png)／[AX](d-unknown.txt)、[保留草稿](d-draft.png)／[AX](d-draft.txt)、[真工具拒絕](d-tools.png)／[AX](d-tools.txt)。D使用Real Mode並真的點系統Don't Allow，沒有用fixture或預注入權限狀態冒充prompt；沒有最終儲存。

## 最新實機前置檢查與未驗項

[23:37 CST preflight](phone17-preflight-redacted.md)確認iPhone17Pro connected、paired，localNetwork／TCP連線，iOS27.0.1／24A446，Developer Mode enabled，Xcode列為相容目的地。這是較23:36 available清單更新的直接查核；歷史unavailable紀錄仍保留，不篡改。

專案Automatic Signing已設但Team仍空。沒有簽署、安裝、App實機執行或模型就緒的證據。E只驗兩個官方Run override分支；Polish仍modelNotReady而無法判unsupported-locale，AI disabled未測。F的實機飛航推論未驗，不能宣稱A–F全部完成。

## 來源封存

[現行來源manifest](../../final-source-sha256.txt)與[可攜副本](../sources.sha256)共52項，涵蓋app/unit/UI Swift、project.yml、pbxproj及shared schemes。舊清單另存[歷史副本](historical-before-v12-sources.sha256)，不拿來驗證現行來源。[文件驗證摘要](document-validation.txt)記錄SHA256與本地連結檢查。本次只更新文件，不修改source/tests/config，不commit或部署。
