import FoundationModels

struct CheckCalendarTool: Tool {
    let ledger: ToolLedger
    let name = "checkCalendar"
    let description = "Read conflicts and Swift-computed available slot for the exact current draft. Uses validated time; cannot save events."
    @Generable struct Arguments { var draftID: String }
    func call(arguments: Arguments) async throws -> String { try await ledger.check(draftID: arguments.draftID) }
}
