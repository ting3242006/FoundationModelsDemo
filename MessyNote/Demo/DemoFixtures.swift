#if DEBUG
import Foundation

@MainActor
struct DemoContacts: ContactSearching {
    func candidates(matching query: String) async throws -> [ContactCandidate] {
        if query.contains("小明") {
            return [ContactCandidate(id: "fixture-ming-1", displayName: "王小明"), ContactCandidate(id: "fixture-ming-2", displayName: "林小明")]
        }
        if query.localizedCaseInsensitiveContains("Amy") { return [ContactCandidate(id: "fixture-amy", displayName: "Amy Chen")] }
        return []
    }
}

@MainActor
struct DemoCalendar: CalendarReading {
    let now: Date
    let timeZone: TimeZone
    init(now: Date = .now, timeZone: TimeZone = .current) { self.now = now; self.timeZone = timeZone }
    func events(from start: Date, to end: Date) async throws -> [CalendarConflict] {
        let intent = DateIntent(kind: "nextWeek", dayOffset: 0, weekday: 3, year: 0, month: 0, day: 0)
        let meeting = try DateResolver.resolve(intent, hour: 15, minute: 0, now: now, timeZone: timeZone)
        let values = [
            CalendarConflict(id: "fixture-meeting", title: "Team Meeting · Fixture", start: meeting, end: meeting.addingTimeInterval(3600)),
            CalendarConflict(id: "fixture-buffer", title: "準備時間 · Fixture", start: meeting.addingTimeInterval(3600), end: meeting.addingTimeInterval(5400))
        ]
        return CalendarAvailability.conflicts(start: start, end: end, events: values)
    }
}
#endif
