import Foundation
import Testing
@testable import MessyNote

@MainActor
struct SaveBoundaryTests {
    final class Spy: CalendarWriting {
        var calls = 0
        func authorize() async throws { }
        func save(_ event: ReviewedEvent, contact: ContactCandidate?) throws -> String { calls += 1; return "saved" }
    }
    func event() throws -> ReviewedEvent {
        try ReviewedEvent(draft: EventDraft(title: "Coffee", date: DateIntent(kind: "offset", dayOffset: 1, weekday: 1, year: 2026, month: 10, day: 21), hour: 15, minute: 0, durationMinutes: 60, attendeeQuery: nil, location: nil, notes: nil, reminderMinutesBefore: nil), now: Date(timeIntervalSince1970: 0), timeZone: TimeZone(secondsFromGMT: 0)!)
    }
    @Test func onlyExplicitConfirmSavesOnce() async throws {
        let spy = Spy()
        let gate = SaveCoordinator(writer: spy)
        gate.prepare(event: try event(), contact: nil)
        #expect(spy.calls == 0)
        let review = try #require(gate.review)
        let saved = try await gate.confirm(review)
        #expect(saved)
        _ = try? await gate.confirm(review)
        #expect(spy.calls == 1)
    }
    @Test func invalidatedReviewCannotSave() async throws {
        let spy = Spy()
        let gate = SaveCoordinator(writer: spy)
        gate.prepare(event: try event(), contact: nil)
        let review = try #require(gate.review)
        gate.invalidate()
        _ = try? await gate.confirm(review)
        #expect(spy.calls == 0)
    }
}
