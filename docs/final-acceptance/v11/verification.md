# v11驗證準備：恢復缺hour補抽

當前v11 **58項unit通過、0失敗、0略過；UI／unit建置與unsigned generic iOS Release均exit0成功**。[Unit摘要](unit-summary.json)、[命令與結果](build-results.txt)。同版本C（104.843秒）、A（207.542秒）PASS；B因觀察到fresh clock false而由主對話停止，沒有完整verdict，D未跑，suite exit75。這是歷史候選，不以其他版本成功補成整套通過。

## 撤回v8額外閘門

C曾出現18:00，當時推測可能是完整EventDraft先猜了非nil hour，導致原缺hour補抽被跳過。v8因此讓所有initial都重新抽clock，並以false／nil清除初稿。但後續診斷證實當次C初稿其實hour=nil，18來自fresh clock本身；這不支持『非nil初稿bypass』是該次根因。

v10的A初稿已有正確16:00，卻被第二次clock的false清掉而正式FAIL；B也觀察到15:00被清，但該run被停止，B只記Testing was canceled，D未執行。[v10中斷證據](../v10/abd-interrupted-evidence.md)保留這些界限。停止命令exit75不是完整B或D失敗verdict。

v11撤回v8額外initial閘門，回到**只有draft.hour缺失才補抽一次**。已有hour保持原日期／時分／欄位，避免第二次模型覆蓋。缺hour仍使用v9 required Bool分類、optional minute及v10繁中Guide；false／nilhour不套用，明確hour且minute未說才由Swift用0。pending revision仍保留allowlist、固定日期與明確time清除政策。沒有新增regex或驗收句特判。

此範圍恢復不保證完整EventDraft永不猜時間；模型語意仍需使用者檢查和真UI驗收。保留v7/v8的B完整通過與v10的C完整通過歷史，但它們不代表v11通過。

## 回歸與證據

先把initial已有clock測試恢復為『不呼叫補抽、完整保留原稿』，以會回false的fake作負面保護；在v10策略下正式red（1個測試、9個issues、exit65），再恢復入口。完整58項green。日期／時間／duration／其他欄位斷言、pending補19保Friday、false+18整稿不變、非法值、取消／reset／mode及過期generation保護保留；沒有縮小UI條件。

來源證據：`/private/tmp/messynote-clock-fallback-v11-validation/red.xcresult`、`unit-green.xcresult`及build logs。此文件整理未更動source/tests/config或執行測試。最終UI附件、manifest與連結驗證等待sealed suite與裝置刷新。

E仍僅兩個官方Run診斷分支；locale INCONCLUSIVE、AI disabled未驗。F實機飛航未驗，最近查核17Pro unavailable、Team未選，沒有實機部署或模型就緒證據。
