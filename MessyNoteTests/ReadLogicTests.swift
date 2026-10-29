import Foundation
import Testing
@testable import MessyNote

struct ReadLogicTests {
    func date(_ hour: Double) -> Date { Date(timeIntervalSince1970: hour * 3600) }
    func busy(_ a: Double, _ b: Double, _ id: String = "meeting") -> CalendarConflict { CalendarConflict(id: id, title: id, start: date(a), end: date(b)) }
    @Test func conflictAndBufferedSlot() {
        let events = [busy(15, 16), busy(16, 16.5, "buffer")]
        #expect(CalendarAvailability.conflicts(start: date(15), end: date(16), events: events).count == 1)
        #expect(CalendarAvailability.nextSlot(after: date(15), duration: 3600, until: date(20), events: events) == date(16.5))
    }
    @Test func halfOpenOverlappingAndBoundary() {
        let events = [busy(14, 15), busy(15.5, 17), busy(16, 18)]
        #expect(CalendarAvailability.conflicts(start: date(15), end: date(15.5), events: events).isEmpty)
        #expect(CalendarAvailability.nextSlot(after: date(15), duration: 3600, until: date(20), events: events) == date(18))
        #expect(CalendarAvailability.nextSlot(after: date(15), duration: 3600, until: date(18.5), events: events) == nil)
        #expect(CalendarAvailability.nextSlot(after: date(15), duration: 3600, until: date(16), events: []) == date(15))
    }
    @Test func contactCardinality() {
        let a = ContactCandidate(id: "a", displayName: "王小明")
        let b = ContactCandidate(id: "b", displayName: "林小明")
        #expect(ContactResolution.resolve([]) == .none)
        #expect(ContactResolution.resolve([a]) == .single(a))
        #expect(ContactResolution.resolve([a,b]) == .multiple([a,b]))
    }
}
