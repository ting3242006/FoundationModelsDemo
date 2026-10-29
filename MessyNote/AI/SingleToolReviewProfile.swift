import FoundationModels

extension SessionPropertyValues {
    @SessionPropertyEntry var messyNoteToolCalls: Int = 0
}

/// A fresh, one-capability session must call its tool once, then stop calling tools.
/// The model still generates arguments and invokes Tool.call; app code never calls a read service here.
struct SingleToolReviewProfile<ReviewTool: Tool>: LanguageModelSession.DynamicProfile {
    @SessionProperty(\.messyNoteToolCalls) var toolCalls
    let tool: ReviewTool
    var body: some LanguageModelSession.DynamicProfile {
        Profile {
            tool
        }
        .model(SystemLanguageModel.default)
        .samplingMode(.greedy)
        .maximumResponseTokens(1024)
        .toolCallingMode(toolCalls < 1 ? .required : .disallowed)
        .onToolCall { toolCalls += 1 }
    }
}
