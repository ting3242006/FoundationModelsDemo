import Foundation
import Testing
@testable import MessyNote

struct FollowUpTests {
    let zone = TimeZone(identifier: "Asia/Taipei")!
    let now = ISO8601DateFormatter().date(from: "2026-10-21T10:00:00+08:00")!
    func draft() -> EventDraft {
        EventDraft(title: "跟小明喝咖啡", date: DateIntent(kind: "nextWeek", dayOffset: 0, weekday: 3, year: 0, month: 0, day: 0), hour: 15, minute: 0, durationMinutes: 60, attendeeQuery: "小明", location: "信義區", notes: "帶合約", reminderMinutesBefore: 1440)
    }
    func previous() throws -> ReviewedEvent { try ReviewedEvent(draft: draft(), now: now, timeZone: zone) }
    @Test func timeOnlyPreservesAllOtherFieldsAndAbsoluteDate() throws {
        var values = draft()
        values.hour = 16; values.minute = 30
        values.attendeeQuery = nil; values.notes = nil; values.location = nil; values.reminderMinutesBefore = nil
        values.title = "錯誤新標題"; values.durationMinutes = 30
        values.date = DateIntent(kind: "offset", dayOffset: 1, weekday: 1, year: 0, month: 0, day: 0)
        let result = try GenerationResult.revision(EventRevision(changes: [.time], values: values)).applying(to: previous(), now: now.addingTimeInterval(7 * 86400), timeZone: zone)
        #expect(result.start == ISO8601DateFormatter().date(from: "2026-10-28T16:30:00+08:00"))
        #expect(result.title == "跟小明喝咖啡")
        #expect(result.attendeeQuery == "小明")
        #expect(result.durationMinutes == 60)
        #expect(result.notes == "帶合約")
        #expect(result.location == "信義區")
        #expect(result.reminderMinutesBefore == 1440)
    }
    @Test func dateOnlyPreservesClock() throws {
        var values = draft(); values.date.weekday = 4; values.hour = nil; values.minute = 0
        let result = try GenerationResult.revision(EventRevision(changes: [.date], values: values)).applying(to: previous(), now: now, timeZone: zone)
        #expect(result.start == ISO8601DateFormatter().date(from: "2026-10-29T15:00:00+08:00"))
    }
    @Test func explicitClearIsRespected() throws {
        var values = draft(); values.attendeeQuery = nil; values.reminderMinutesBefore = nil
        let result = try GenerationResult.revision(EventRevision(changes: [.attendee, .reminder], values: values)).applying(to: previous(), now: now, timeZone: zone)
        #expect(result.attendeeQuery.isEmpty)
        #expect(result.reminderMinutesBefore == nil)
    }
    @Test func emptyChangeListPreservesEverything() throws {
        var values = draft(); values.hour = nil; values.title = ""; values.durationMinutes = -1
        let result = try GenerationResult.revision(EventRevision(changes: [], values: values)).applying(to: previous(), now: now, timeZone: zone)
        let original = try previous()
        #expect(result == original)
    }
    @Test func changedInvalidTimeIsRejected() throws {
        var values = draft(); values.hour = nil
        #expect(throws: PlannerError.self) {
            try GenerationResult.revision(EventRevision(changes: [.time], values: values)).applying(to: previous(), now: now, timeZone: zone)
        }
    }
    @Test func pendingDraftPreservesFridayAcrossDaysAndAllowsExplicitClear() throws {
        var incomplete = draft(); incomplete.date.weekday = 5; incomplete.hour = nil
        let pending = try GenerationResult.initial(incomplete).mergedDraft(to: nil, now: now, timeZone: zone)
        #expect(pending.hour == nil)
        #expect(pending.date.kind == "explicit")
        var values = incomplete; values.date.weekday = 1; values.hour = 19; values.minute = 0
        values.attendeeQuery = nil; values.reminderMinutesBefore = nil
        let result = try GenerationResult.revision(EventRevision(changes: [.time, .reminder], values: values))
            .applying(to: nil, pending: pending, now: now.addingTimeInterval(7 * 86400), timeZone: zone)
        #expect(result.start == ISO8601DateFormatter().date(from: "2026-10-30T19:00:00+08:00"))
        #expect(result.attendeeQuery == "小明")
        #expect(result.reminderMinutesBefore == nil)
    }
    @Test func invalidPendingDateCannotBeFrozenIntoValidDate() throws {
        var incomplete = draft(); incomplete.hour = nil
        incomplete.date = DateIntent(kind: "explicit", dayOffset: 0, weekday: 1, year: 2026, month: 2, day: 30)
        #expect(throws: PlannerError.self) {
            try GenerationResult.initial(incomplete).mergedDraft(to: nil, now: now, timeZone: zone)
        }
        var values = draft(); values.hour = 19
        #expect(throws: PlannerError.self) {
            try GenerationResult.revision(EventRevision(changes: [.time], values: values))
                .applying(to: nil, pending: incomplete, now: now, timeZone: zone)
        }
    }

}
