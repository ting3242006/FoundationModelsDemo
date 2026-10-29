# Foundation Models iOS/macOS 27 single-tool required-call control and trace evidence

Sources: installed Xcode 27.1 macOS SDK interface and Apple’s official “Expanding generation with tool calling” documentation. This is SDK evidence; it does not claim that a particular prompt used a tool.

## Exact iOS/macOS 27 API surface

- `LanguageModelSession.DynamicProfile` protocol is at `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/FoundationModels.framework/Modules/FoundationModels.swiftmodule/arm64e-apple-macos.swiftinterface:824–827`.
- `LanguageModelSession.Profile` and `Profile { … }` initializer are at `:830–850`; fresh `LanguageModelSession.init(profile:history:)` is at `:915–917`.
- `.toolCallingMode(_)`, `.onToolCall { }`, and typed `.onToolCall { ToolCall in }` are at `:970–1014`.
- `@SessionPropertyEntry` is at `:1079–1097`; `@SessionProperty` is at `:1037–1048`.
- `GenerationOptions.ToolCallingMode` cases and `GenerationOptions` iOS/macOS 27 initializer are at `:3245–3248,3293–3308`.

Apple’s official example uses this exact state transition: a session property count begins at zero, the dynamic profile gives the model `.required` only before the first tool call, and `onToolCall` increments the count. Apple documents that `.required` otherwise continues calling tools; it requires an exit condition. See [Expanding generation with tool calling](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling).

## Compile-oriented concrete pattern: a fresh one-tool session

The following profile mirrors Apple’s documented syntax. Make one profile type and one fresh session for each target tool; the profile includes exactly one tool, therefore a required call can only target that single tool.

```swift
import FoundationModels

extension SessionPropertyValues {
    @SessionPropertyEntry var toolCallCount: Int = 0
}

struct ContactReviewProfile: LanguageModelSession.DynamicProfile {
    @SessionProperty(\.toolCallCount) var toolCallCount
    let tool: FindContactTool

    var body: some LanguageModelSession.DynamicProfile {
        Profile { tool }
            .toolCallingMode(toolCallCount < 1 ? .required : .allowed)
            .onToolCall { toolCallCount += 1 }
    }
}

@MainActor
func reviewContactOnce(ledger: ToolLedger, prompt: String) async throws -> String {
    let session = LanguageModelSession(
        profile: ContactReviewProfile(tool: FindContactTool(ledger: ledger))
    )
    let response = try await session.respond(to: prompt)
    return response.content
}
```

Use the same construction for `CheckCalendarTool`, changing only the profile’s stored tool type and initializer:

```swift
struct CalendarReviewProfile: LanguageModelSession.DynamicProfile {
    @SessionProperty(\.toolCallCount) var toolCallCount
    let tool: CheckCalendarTool
    var body: some LanguageModelSession.DynamicProfile {
        Profile { tool }
            .toolCallingMode(toolCallCount < 1 ? .required : .allowed)
            .onToolCall { toolCallCount += 1 }
    }
}

@MainActor
func reviewCalendarOnce(ledger: ToolLedger, prompt: String) async throws -> String {
    let session = LanguageModelSession(
        profile: CalendarReviewProfile(tool: CheckCalendarTool(ledger: ledger))
    )
    return try await session.respond(to: prompt).content
}
```

`profile:` is iOS/macOS 27 only. This code makes no `GenerationOptions(toolCallingMode:)` call because the profile is the required→allowed control point. If calling options are separately needed, their documented form is `GenerationOptions(toolCallingMode: .required)`.

Fresh sessions do not carry the extraction session’s transcript, so calls remain statefully isolated. The caller must include the exact prepared `draftID` and query in each target prompt. The tool/ledger guard may still reject a model-created wrong ID; `.required` proves an attempt happened, not that application-level arguments passed the guard.

## Trace actual attempts, arguments, and outputs

The SDK exposes `LanguageModelSession.transcript` at interface `:1911–1916`; `Response<String>.transcriptEntries` is at `:1968–1975`. `Transcript.Entry` has `.toolCalls` and `.toolOutput` at `:2262–2270`; `Transcript.ToolCall` provides `toolName` and `arguments` at `:2554–2575`. Therefore trace after each response rather than infer calls from app `activity`:

```swift
func printToolTrace(_ entries: some Collection<Transcript.Entry>) {
    for entry in entries {
        if case .toolCalls(let calls) = entry {
            for call in calls {
                print("tool=\(call.toolName) args=\(call.arguments.jsonString)")
            }
        } else if case .toolOutput(let output) = entry {
            print("toolOutput=\(output)")
        }
    }
}

let response = try await session.respond(to: prompt)
printToolTrace(response.transcriptEntries) // one request
printToolTrace(session.transcript)          // full fresh-session history
```

`GeneratedContent.jsonString` is available in the SDK interface at `FoundationModels.swiftinterface:1350–1355`. The `toolOutput` interpolation is a debug representation; match entries structurally if a stable display format is required.

For live model-call visibility, the profile can also use the typed closure `onToolCall { call in … }` and typed `onToolOutput { call, output in … }`, signatures at interface `:1014,1022`. The callbacks run on nonisolated/nonsending async closures; do not mutate `@MainActor` UI state from them without an actor hop. Existing `ToolLedger` tool methods are `@MainActor`, so keeping each review function `@MainActor` and treating trace as data to relay to the main actor is the conservative integration boundary.

If a tool throws, Foundation Models throws `LanguageModelSession.ToolCallError`, with `tool` and `underlyingError` at interface `:1695–1707`; log that separately from “no call.”
