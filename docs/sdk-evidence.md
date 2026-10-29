# MessyNote SDK evidence — 2026-10-21

## Environment

`xcodebuild -version` reports **Xcode 27.1 (27A9275)**. `xcodebuild -showsdks` reports **iOS 27.1**. `swift --version` reports **Swift 6.4**. `xcodegen --version` reports **2.44.1**.

The full SDK interface used below is:

`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/FoundationModels.framework/Modules/FoundationModels.swiftmodule/arm64e-apple-ios.swiftinterface`

## Foundation Models — supported plan

Foundation Models API availability begins at iOS 26.0. This project deliberately uses iOS 27.0 as its deployment target. The iOS 27 `LanguageModel`-generic session overloads and tool-calling options are additive; the iOS 26-compatible initializer below gives genuine tool calling and guided streaming.

```swift
import FoundationModels

let model = SystemLanguageModel.default
guard model.availability == .available else { return }
guard model.supportsLocale(Locale.current) else { return }

let session = LanguageModelSession(
    model: model,
    tools: [findContactTool, checkCalendarTool],
    instructions: """
    Current date: \(Date.now.formatted())
    Time zone: \(TimeZone.current.identifier)
    Locale: \(Locale.current.identifier)
    """
)
```

Direct evidence:

- FoundationModels interface:36-41 — `LanguageModelSession` initializer has default `SystemLanguageModel`, tools, string/`Instructions`/transcript variants.
- FoundationModels interface:260-272 — `SystemLanguageModel.availability` and `isAvailable`, iOS 26.
- FoundationModels interface:352-369 — availability reasons are `.deviceNotEligible`, `.appleIntelligenceNotEnabled`, `.modelNotReady`.
- FoundationModels interface:397-400 — `supportedLanguages` and synchronous `supportsLocale(_:)`.
- FoundationModels interface:1140-1153 — `@Guide` macro plus `Generable.PartiallyGenerated`.
- FoundationModels interface:1423-1463 — guides support String constraints, Int/Float/Decimal/Double ranges, array counts/elements.

Use semantic, `@Generable` fields rather than `Date`: weekday/date language, `hour`, `minute`, duration and reminder offset. Convert those deterministically with `Calendar` and `TimeZone`.

```swift
@Generable
struct EventDraft: Sendable {
    @Guide(description: "A concise event title") var title: String
    @Guide(.range(0...23)) var hour: Int
    @Guide(.range(0...59)) var minute: Int
    @Guide(.range(1...480)) var durationMinutes: Int
    var attendeeQuery: String?
    var location: String?
    var notes: String?
    var reminderMinutesBefore: Int?
}
```

## Genuine streaming and stateful session

```swift
let stream = session.streamResponse(to: note, generating: EventDraft.self)
for try await snapshot in stream {
    try Task.checkCancellation()
    // snapshot.content is EventDraft.PartiallyGenerated; render only fields present.
    await MainActor.run { viewModel.partialDraft = snapshot.content }
}
```

- FoundationModels interface:2059-2061 — generic `streamResponse(... generating:)`.
- FoundationModels interface:2185-2226 — `ResponseStream` is an `AsyncSequence` of `Snapshot`.
- FoundationModels interface:2190-2200 — snapshot has `content: Content.PartiallyGenerated`, raw content, and (iOS 27) transcript/usage.
- FoundationModels interface:1911-2045 — session exposes `isResponding`; interface:2030-2046 documents iOS 27 concurrent/mutation errors. One session handles one active request; cancel and replace the view model task before a new request.
- FoundationModels interface:1527-1536 — handle `LanguageModelError.contextSizeExceeded`, guardrail/refusal, unsupported locale/guide, and timeout. Treat `CancellationError` as normal lifecycle control flow.

## Genuine tool calling

```swift
@Generable struct FindContactArguments: Sendable { var query: String }

struct FindContactTool: Tool {
    let service: any ContactSearching
    var name: String { "findContact" }
    var description: String { "Finds minimal contact candidates by a supplied name." }

    func call(arguments: FindContactArguments) async throws -> String {
        try await service.minimalCandidates(matching: arguments.query)
    }
}
```

- FoundationModels interface:3054-3079 — `Tool` is `Sendable`, has `Arguments`/`Output`, and asynchronous throwing `call(arguments:)`.
- FoundationModels interface:3072-3079 — `@Generable` argument structs obtain an automatic parameter schema.
- FoundationModels interface:3085 onward — bare primitive/String tool arguments are explicitly unsupported; use an `@Generable` struct.
- `Output` must conform to `PromptRepresentable`; a minimal plain String response is valid. Return only identifier/display name or conflict intervals; never provide the address book.

Use a second `@Generable` arguments struct for calendar start/end semantics. The tool obtains calendar events through the injected service, returns only overlapping intervals/titles, and lets deterministic Swift calculate the next available slot. Neither tool calls `save`.

## Contacts and Calendar permission APIs

```swift
let contactsGranted = try await contactStore.requestAccess(for: .contacts)
let calendarGranted = try await eventStore.requestFullAccessToEvents()
```

- `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/Contacts.framework/Headers/CNContactStore.h:74` — authorization status.
- `CNContactStore.h:79-86` — access request is asynchronous/nonblocking, first request prompts and later calls reuse status.
- `EventKit.framework/Headers/EKEventStore.h:52` — calendar authorization status.
- `EKEventStore.h:84` — `requestFullAccessToEvents`, iOS 17+.
- `EKEventStore.h:86` — write-only access; insufficient for conflict reads.
- `EKEventStore.h:90` — legacy `requestAccessToEntityType` is deprecated from iOS 17.

Include `NSContactsUsageDescription` and `NSCalendarsFullAccessUsageDescription`. Contacts code must accept `.limited` and `.authorized`; Apple’s Contacts documentation confirms limited access (iOS 18+) works with the Contacts API and should offer user selection for absent candidates. Calendar save stays in an explicit user-button method after a final review.

## Simulator and physical-device evidence

An escalated `xcrun simctl list devices available` succeeded. Available iOS runtimes include iOS 26.0 (e.g. iPhone 17 Pro, ID `265CC1D6-56D1-479B-9976-42AE2EDF893D`), 26.4, and 27.0. Build and deterministic tests run on the installed iOS 27 simulator. Foundation Models availability, Apple Intelligence language/region state, model download, on-device inference, Contacts and Calendar user permission flows require a supported physical Apple Intelligence device for authoritative validation.

Apple official documentation evidence: the Foundation Models framework page states system-model on-device inference can work without internet; the “Generating content and performing tasks” page says availability depends on device and region, models may take time to download, and recommends inspecting `model.availability`. The Apple `supportedLanguages` documentation states `supportsLocale(_:)` includes language fallback.

## SwiftUI, concurrency, and tests — implementation constraints

- Views reference: `swiftui-pro/references/views.md` — one type per file; use extracted views, `TextField(axis: .vertical)`, and action methods outside `body`.
- Data reference: `swiftui-pro/references/data.md` — use `@MainActor @Observable` view model; view owns it via private `@State` and passes bindings with `@Bindable`.
- Accessibility/resizability: use Dynamic Type fonts, semantic `Button` labels, `accessibilityReduceMotion`, `ScrollView`, size classes and no fixed safe-area guesses (`accessibility.md`, `resizability.md`).
- Concurrency: `swift-concurrency-pro/references/cancellation.md` — cancel a stored generation task before replacement and filter `CancellationError`; `bridging.md` — use checked throwing continuations only when no async EventKit/Contacts overlay is available; `async-streams.md` — consume the stream with cancellation-aware iteration.
- Tests: `swift-testing-pro/references/core-rules.md` — use `struct` suites, `@Test`, `#expect`, isolated deterministic fixtures; `async-tests.md` — tests may be async and must await task completion. Test `DateResolver`, availability-slot selection, contact candidate count, and a spy that proves model/services cannot invoke calendar save.

## Final implementation update

Deployment is iOS27.0. Parse session uses SystemLanguageModel.default without tools and streams typed EventDraft; tool review uses separate fresh SingleToolReviewProfile sessions, explicitly .model(SystemLanguageModel.default). SDK27 DynamicProfile, SessionPropertyEntry, SessionProperty, toolCallingMode and onToolCall are used. Each profile starts required and becomes disallowed after the first tool call. See tool-control-evidence.md for the actual interface and official pattern. Contact and Calendar reads remain model-invoked; the application selects read-only review stages, while the model generates Tool arguments and initiates call. Free-form model review text is not presented as evidence.

## Typed revision preservation

Follow-ups stream EventRevision instead of a replacement EventDraft. EventRevision.values partial content is displayed directly; GenerationResult.applying merges only EventField values listed in changes into an explicit-date baseline from ReviewedEvent. Explicit optional clearing is supported. This corrects an observed model failure that dropped attendee on a time-only follow-up. No JSON decoder or regex is used.


## 最終抽取與pending follow-up

`@Generable(representNilExplicitlyInGeneratedContent: true)`已用本機SDK27.1成功編譯，讓EventDraft的optional值明確生成null。初次抽取提示分開REFERENCE_CONTEXT與USER_NOTE；typed revision分開REFERENCE_DRAFT與LATEST_REQUEST。這些是語意指示，不是正確性保證。

缺時間的raw草稿也使用既有EventRevision schema。純Swift `DateResolver.resolveDay`先校驗日曆日期，`GenerationResult.mergedDraft(to:pending:now:timeZone:)`保存explicit日期；`applying`使用同一合併路徑再驗證完整事件。這是App狀態保持，沒有加入新的模型API、regex NLU或假推論。


## 2026-10-22：pending-only窄型時刻抽取

新增`@Generable(representNilExplicitlyInGeneratedContent: true) ClockCompletion { hour: Int?, minute: Int }`，使用現有已支援的Guided Generation與typed stream API。fresh `LanguageModelSession(model: SystemLanguageModel.default, instructions:)`只接收當次LATEST_REQUEST；`GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 128)`。沒有改用其他模型、JSONDecoder、regex或日期parser。

`FoundationModelGenerating.completePendingClock(in:after:previousEvent:previousPending:note:now:timeZone:onPartial:)`為App及harness共用單次條件；`ClockCompletion.applying(to:now:timeZone:)`透過既有`.time`合併並驗證範圍。明確`.time=nil`不會被補回。額外串流與原generation共用取消任務與UUID，fresh session局部持有，無跨request時刻記憶。
