import FoundationModels

@Generable
struct EventRevision: Sendable {
    @Guide(description: "Allowlist of fields explicitly changed or cleared by LATEST_REQUEST only. NOT a property catalog: copied and unchanged fields MUST be excluded. Clock-only => [time]; day-only => [date]; cancel reminder => [reminder]. Ignore earlier transcript when selecting this list.")
    var changes: [EventField]
    @Guide(description: "Edited values. Copy unedited reference values without adding them to changes. Explicit attendee/reminder removal sets that value to nil and includes the corresponding field in changes.")
    var values: EventDraft
}
