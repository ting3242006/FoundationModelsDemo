# v10 ABD interrupted run — read-only evidence

## Result bundle summary

`abd-final.xcresult` is readable with `xcresulttool`.

- Summary result: `Failed`; total test count 2; passed 0; failed 2.
- Test A (`ScenarioABUITests/testScenarioA`) is the only test with an application assertion failure: `A02 event` did not complete in 180 seconds.
- Test B (`ScenarioABUITests/testScenarioBAndFollowUp`) has summary failure text `Testing was canceled`.
- Scenario D does not appear in this result summary, so this bundle provides no D test result.
- The source log command scheduled A, B, and D, but the summary only records A and B.

## A log evidence

- `abd-final.log:13` — A test started.
- `abd-final.log:786` — A02 180-second failure text.
- `abd-final.log:793` — A test reported failed after 224.515 seconds.
- `abd-final.log:794` — B test started.

## 18:16 A diagnostics

- `model-diagnostics.log:41` — A generation began with no previous start and no pending draft.
- `model-diagnostics.log:43` — initial merge records Oct 23 hour 16 minute 0.
- `model-diagnostics.log:44` — subsequent clock completion records `explicit=false hour=nil minute=nil`.

## 18:20 B diagnostics

- `model-diagnostics.log:45` — B generation began with no previous start and no pending draft.
- `model-diagnostics.log:47` — initial merge records Oct 28 hour 15 minute 0.
- `model-diagnostics.log:48` — subsequent clock completion records `explicit=false hour=nil minute=nil`.

No result is recorded here for completed B behavior or D behavior. No source, simulator, or test state was modified.
