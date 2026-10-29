# v7：B完整UI通過；其餘本輪結果待確認

2026-10-22，B單次完整 `testScenarioBAndFollowUp` **Passed，1/0/0，264.086秒**；[sealed摘要](b-summary.json)。測試使用真正FoundationModels、中文Unicode typeText與唯讀fixtures。初始與follow-up皆檢查完整欄位與真工具，再選王小明、開啟review並取消；未按最終Calendar寫入，也未使用手動時間picker。

[follow-up](b-followup.png)／[AX](b-followup.txt)、[提交已開始](b-submission-start.png)／[AX](b-submission-start.txt)、[兩工具與4:30 PM](b-tools.png)／[AX](b-tools.txt)、[保留日期和欄位](b-fields.png)／[AX](b-fields.txt)、[review](b-review.png)／[AX](b-review.txt)、[取消後](b-canceled.png)／[AX](b-canceled.txt)。[附件來源](selected-attachments.json)另含清空前後及輸入完成的raw type/value/placeholder紀錄；只含測試fixture指令，沒有真實聯絡人資料。

Unit **56 passed / 0 failed / 0 skipped**，[sealed摘要](unit-summary.json)。最初新增整稿等值測試錯依JSON key順序失敗，改逐欄比較後全通過；未因此修改產品。Release **exit0 / BUILD SUCCEEDED**，見[命令與摘要](release-summary.txt)。A/C/D本輪同來源重驗尚待主對話回報；以前通過的證據保留，不冒充本輪結果。

## 本次修正與歷史界限

1. 空白TextField的AX可只列placeholder、沒有value。測試明確區分nil、NSNull、String；null僅在exists且placeholder正確時接受，其他非字串實值拒絕。清空及輸入各有界等待，完整中文句子仍須精確相同。
2. 工具定位原拖曳起點落在SystemInputAssistant（y546–590），不是Form；鍵盤frame從y590開始。安全區再上移80點，仍保留180秒／32次及精確時刻工具標籤。單次tap後等待取消按鈕出現並留真實partial診斷，區分提交未開始與模型結果。
3. v5／v6確定initial缺hour後fresh clock產生15:30，原指令為整點。v6只去除prompt例子仍失敗，不宣稱此假說已證因果。v7將窄型ClockCompletion.minute改Int?：只有明說分鐘成分才輸出值；hour存在時Swift以minute ?? 0套用，hour不存在則整稿不變。EventDraft.minute、revision mask與merge規則未變，無regex或B字串特判。新增回歸涵蓋舊非零分鐘、明確分鐘、整稿保留；既有非法值驗證保留。
4. Debug診斷僅環境變數MESSYNOTE_ACCEPTANCE_DIAGNOSTICS=1才輸出日期／時分、mask、階段與generation ID，不輸出note、title、姓名、地點或notes；Release不含診斷。這是觀察工具，不注入模型答案。

此為v7一次完整B通過，不保證模型永遠穩定。以前B輸入、格式、虛擬化定位與模型失敗均保留，[較早分次結果](../b-run-comparison.md)不能改寫成成功。v3首次Mach-308／serverdied未執行test屬基礎設施錯誤；重新boot後的完整失敗與之分開。

E僅兩個官方Run診斷UI分支已驗；locale仍INCONCLUSIVE，AI disabled未測。F飛航推論尚未驗證。最新[17:31裝置快照](device-1731.md)為15Plus connected、17Pro unavailable，無部署或模型就緒證據。
