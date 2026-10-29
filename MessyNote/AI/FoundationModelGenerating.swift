import Foundation

@MainActor
protocol FoundationModelGenerating {
    func reset()
    func generate(_ note: String, current: String?, isRevision: Bool, now: Date, timeZone: TimeZone, onPartial: @escaping @MainActor (EventDraft.PartiallyGenerated) -> Void) async throws -> GenerationResult
    func completeDuration(_ note: String) async throws -> DurationCompletion
    func completeClock(_ note: String, onPartial: @escaping @MainActor (ClockCompletion.PartiallyGenerated) -> Void) async throws -> ClockCompletion
    func review(_ context: ToolLedger.Context) async throws
}

// Shared by app and harness: at most one fresh extraction for an unresolved clock.
extension FoundationModelGenerating {
    func completeInitialDuration(in draft: EventDraft, after result: GenerationResult, note: String) async throws -> EventDraft {
        try Task.checkCancellation()
        guard case .initial = result else { return draft }
        let duration = try await completeDuration(note)
        try Task.checkCancellation()
        return try duration.applying(to: draft)
    }

    func completePendingClock(in draft: EventDraft, after result: GenerationResult, previousEvent: ReviewedEvent?, previousPending: EventDraft?, note: String, now: Date, timeZone: TimeZone, onPartial: @escaping @MainActor (ClockCompletion.PartiallyGenerated) -> Void) async throws -> EventDraft {
        try Task.checkCancellation()
        guard previousEvent == nil, draft.hour == nil else { return draft }
        switch result {
        case .initial:
            guard previousPending == nil else { return draft }
        case .revision(let revision):
            guard let previousPending, previousPending.hour == nil,
                  !revision.changes.contains(.time) else { return draft }
        }
        let clock = try await completeClock(note, onPartial: onPartial)
        try Task.checkCancellation()
        return try clock.applying(to: draft, now: now, timeZone: timeZone)
    }
}
