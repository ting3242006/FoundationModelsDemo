import Foundation

enum GenerationResult: Sendable {
    case initial(EventDraft)
    case revision(EventRevision)
    var proposedDraft: EventDraft {
        switch self { case .initial(let draft): draft; case .revision(let revision): revision.values }
    }
    /// Shared by UI and integration harness. A pending draft can preserve its date before it has a time.
    func mergedDraft(to previous: ReviewedEvent?, pending: EventDraft? = nil, now: Date, timeZone: TimeZone) throws -> EventDraft {
        var draft: EventDraft
        if case .revision(let revision) = self {
            guard let baseline = previous?.asDraft() ?? pending else { throw PlannerError.invalidDraft }
            draft = DraftMerge.merge(revision, into: baseline)
        } else {
            draft = proposedDraft
        }
        let zone = previous.flatMap { TimeZone(identifier: $0.timeZoneIdentifier) } ?? timeZone
        let day = try DateResolver.resolveDay(draft.date, now: now, timeZone: zone)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        draft.date = DateIntent(kind: "explicit", dayOffset: 0, weekday: 1,
            year: calendar.component(.year, from: day), month: calendar.component(.month, from: day), day: calendar.component(.day, from: day))
        return draft
    }
    func applying(to previous: ReviewedEvent?, pending: EventDraft? = nil, now: Date, timeZone: TimeZone) throws -> ReviewedEvent {
        let draft = try mergedDraft(to: previous, pending: pending, now: now, timeZone: timeZone)
        let zone = previous.flatMap { TimeZone(identifier: $0.timeZoneIdentifier) } ?? timeZone
        return try ReviewedEvent(draft: draft, now: now, timeZone: zone)
    }
}
