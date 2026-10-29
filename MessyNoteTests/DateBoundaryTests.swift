import Foundation
import Testing
@testable import MessyNote

struct DateBoundaryTests {
    let zone = TimeZone(identifier: "Asia/Taipei")!
    func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    func intent(_ kind: String = "offset", day: Int = 1, weekday: Int = 3) -> DateIntent { DateIntent(kind: kind, dayOffset: day, weekday: weekday, year: 2026, month: 3, day: 8) }
    @Test func monthAndYearRollover() throws {
        #expect(try DateResolver.resolve(intent(), hour: 16, minute: 0, now: date("2026-12-31T12:00:00+08:00"), timeZone: zone) == date("2027-01-01T16:00:00+08:00"))
    }
    @Test func sundayAndSameWeekdayUseNextWeek() throws {
        #expect(try DateResolver.resolve(intent("nextWeek", weekday: 1), hour: 15, minute: 0, now: date("2026-10-25T12:00:00+08:00"), timeZone: zone) == date("2026-10-26T15:00:00+08:00"))
        #expect(try DateResolver.resolve(intent("nextWeek"), hour: 15, minute: 0, now: date("2026-10-21T12:00:00+08:00"), timeZone: zone) == date("2026-10-28T15:00:00+08:00"))
    }
    @Test(arguments: [(-1,0), (24,0), (15,60), (15,-1)]) func invalidClocks(pair: (Int,Int)) {
        #expect(throws: PlannerError.self) { try DateResolver.resolve(intent(), hour: pair.0, minute: pair.1, now: .now, timeZone: zone) }
    }
    @Test func nonexistentDSTTimeIsRejected() {
        #expect(throws: PlannerError.self) { try DateResolver.resolve(intent("explicit"), hour: 2, minute: 30, now: .now, timeZone: TimeZone(identifier: "America/Los_Angeles")!) }
    }
    @Test func scenarioADurationAndReminder() throws {
        let draft = EventDraft(title: "Amy meeting", date: intent(), hour: 16, minute: 0, durationMinutes: 30, attendeeQuery: "Amy", location: nil, notes: nil, reminderMinutesBefore: 120)
        let value = try ReviewedEvent(draft: draft, now: date("2026-10-21T12:00:00+08:00"), timeZone: zone)
        #expect(value.start == date("2026-10-22T16:00:00+08:00"))
        #expect(value.end == date("2026-10-22T16:30:00+08:00"))
        #expect(value.reminderMinutesBefore == 120)
    }
    @Test(arguments: [0, -1, 481]) func invalidDuration(duration: Int) {
        let draft = EventDraft(title: "Meeting", date: intent(), hour: 16, minute: 0, durationMinutes: duration, attendeeQuery: nil, location: nil, notes: nil, reminderMinutesBefore: nil)
        #expect(throws: PlannerError.self) { try ReviewedEvent(draft: draft, now: .now, timeZone: zone) }
    }
    @Test func invalidReminder() {
        let draft = EventDraft(title: "Meeting", date: intent(), hour: 16, minute: 0, durationMinutes: 30, attendeeQuery: nil, location: nil, notes: nil, reminderMinutesBefore: -10)
        #expect(throws: PlannerError.self) { try ReviewedEvent(draft: draft, now: .now, timeZone: zone) }
    }
}
