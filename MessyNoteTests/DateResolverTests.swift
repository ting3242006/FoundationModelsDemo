import Foundation
import Testing
@testable import MessyNote

struct DateResolverTests {
    let zone = TimeZone(identifier: "Asia/Taipei")!
    var now: Date { ISO8601DateFormatter().date(from: "2026-10-21T10:00:00+08:00")! }
    func intent(_ kind: String = "offset", offset: Int = 1, weekday: Int = 3, year: Int = 2026, month: Int = 10, day: Int = 28) -> DateIntent {
        DateIntent(kind: kind, dayOffset: offset, weekday: weekday, year: year, month: month, day: day)
    }
    @Test func tomorrow() throws {
        let value = try DateResolver.resolve(intent(), hour: 16, minute: 0, now: now, timeZone: zone)
        #expect(value == ISO8601DateFormatter().date(from: "2026-10-22T16:00:00+08:00"))
    }
    @Test func nextWednesday() throws {
        let value = try DateResolver.resolve(intent("nextWeek"), hour: 15, minute: 0, now: now, timeZone: zone)
        #expect(value == ISO8601DateFormatter().date(from: "2026-10-28T15:00:00+08:00"))
    }
    @Test func invalidDayAndMissingTime() {
        #expect(throws: PlannerError.self) { try DateResolver.resolve(intent("explicit", month: 2, day: 30), hour: 15, minute: 0, now: now, timeZone: zone) }
        #expect(throws: PlannerError.self) { try DateResolver.resolve(intent(), hour: nil, minute: 0, now: now, timeZone: zone) }
    }
}
