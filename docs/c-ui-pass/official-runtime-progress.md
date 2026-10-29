# Case C runtime repair and input investigation — 2026-10-22

## Runtime repair (observed)
- User explicitly authorized replacing the old beta runtime.
- Removed only iOS 27.0 beta 2 image FD2EA5A9-6BAB-4093-9091-A27E756231F3 (24A5370g); no simulator device erase or delete.
- Installed Apple's official iOS 27.0 (24A434), arm64. Install log: runtime-install-after-reclaim.log, exit 0, UUID 71246001-28A7-4DE8-9E15-22F73877587D.
- Created isolated simulator MessyNote Case C QA, UDID 280085F1-11D0-4221-B90F-59FD4226E464.
- Installed existing Debug MessyNote.app from /private/tmp/messynote-validation/DerivedData/Build/Products/Debug-iphonesimulator.
- Real FoundationModels inference completed in the simulator (default B generated coffee with 小明 on Oct 28, 2026 at 15:00, fixture tool ledger showed FindContactTool/CheckCalendarTool).
- Thus the previous model asset startup failure is resolved for this runtime. This observation alone is NOT Case C success.

## False-positive input evidence (must correct prior docs)
- Native accessibility setValue displayed Chinese text in SwiftUI TextField but did not update the model's binding.
- Actual generated drafts still reflected previous/default input. A diagnostic ASCII Test entered through XcodeBuildMCP type_text yielded a Test draft, proving the prior generated content was not Case C.
- Therefore earlier claims that AX setValue solved Chinese input were too strong and are superseded.
- simctl pbcopy/pbpaste roundtrip preserved Chinese, but native Paste actions did not establish a successful model input. Clipboard correctness alone is not UI E2E evidence.
- Several XcodeBuildMCP taps and native keys reported success without visible changes. Native accessibility button/switch actions and CUA drag did produce observable changes.
- Missing simulator accessibility nodes recovered after rebooting this dedicated simulator; app sample before reboot showed idle CFRunLoop, not a main-thread hang.
- Capture Keyboard was restored to OFF after investigation.

## Next verification
- Add a focused opt-in XCUITest using actual UI text entry and real FoundationModels plus read-only fixture tools.
- Require pending original date, natural-language follow-up, same date at 19:00, contact/calendar result UI and ledger.
- Never press calendar save or manual time selection as the success path.
