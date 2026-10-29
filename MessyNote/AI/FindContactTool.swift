import FoundationModels

struct FindContactTool: Tool {
    let ledger: ToolLedger
    let name = "findContact"
    let description = "Read minimal contact candidates for the current reviewed draft. Never select among multiple candidates." // 不要幫使用者選
    @Generable struct Arguments {
        var query: String
        var draftID: String
    }
    func call(arguments: Arguments) async throws -> String {
        try await ledger.find(query: arguments.query, draftID: arguments.draftID)
    }
}
