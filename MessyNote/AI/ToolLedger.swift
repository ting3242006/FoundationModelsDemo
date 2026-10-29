import Foundation
import Observation

@MainActor @Observable
final class ToolLedger {
    struct Context: Equatable, Sendable {
        let generation: UUID
        let draftID: String
        let event: ReviewedEvent
    }
    private(set) var context: Context?
    private(set) var activity: [ActivityEvent] = []
    private(set) var candidates: [ContactCandidate]?
    private(set) var contactError: String?
    private(set) var conflicts: [CalendarConflict]?
    private(set) var nextSlot: Date?
    private(set) var calendarError: String?
    private let contacts: any ContactSearching
    private let calendar: any CalendarReading
    init(contacts: any ContactSearching, calendar: any CalendarReading) { self.contacts = contacts; self.calendar = calendar }
    func reset() { context = nil; activity = []; clearEvidence() }
    func clearEvidence() { candidates = nil; contactError = nil; conflicts = nil; nextSlot = nil; calendarError = nil }
    func append(_ message: String) { activity.append(ActivityEvent(message: message)) }
    func prepare(event: ReviewedEvent, generation: UUID) -> Context {
        clearEvidence()
        let value = Context(generation: generation, draftID: UUID().uuidString, event: event)
        context = value
        return value
    }
    func invalidate() { context = nil; clearEvidence() }
    func find(query: String, draftID: String) async throws -> String {
        guard let captured = context, captured.draftID == draftID, captured.event.attendeeQuery == query else { return "Rejected: stale draft or query mismatch." }
        append("→ FindContactTool(\(query))")
        do {
            let values = try await contacts.candidates(matching: query)
            try Task.checkCancellation()
            guard context == captured else { throw CancellationError() }
            candidates = values
            append("✓ 找到 \(values.count) 位候選人；多位時由使用者選擇")
            return values.isEmpty ? "No contact found. Keep unresolved." : values.map { "id=\($0.id), name=\($0.displayName)" }.joined(separator: "\n") + "\nUser must choose; do not choose an identity."
        } catch is CancellationError { throw CancellationError() }
        catch {
            guard context == captured else { throw CancellationError() }
            contactError = error.localizedDescription
            append("⚠ 聯絡人查詢失敗")
            return "Contact query unavailable: \(error.localizedDescription)"
        }
    }
    func check(draftID: String) async throws -> String {
        guard let captured = context, captured.draftID == draftID else { return "Rejected: stale draft." }
        let event = captured.event
        append("→ CheckCalendarTool(\(event.start.formatted(date: .omitted, time: .shortened)))")
        let limit = event.start.addingTimeInterval(12 * 3600)
        do {
            let values = try await calendar.events(from: event.start, to: limit)
            try Task.checkCancellation()
            guard context == captured else { throw CancellationError() }
            let collisions = CalendarAvailability.conflicts(start: event.start, end: event.end, events: values)
            conflicts = collisions
            nextSlot = collisions.isEmpty ? nil : CalendarAvailability.nextSlot(after: event.start, duration: event.end.timeIntervalSince(event.start), until: limit, events: values)
            append(collisions.isEmpty ? "✓ 此時段沒有衝突（查詢當下）" : "⚠ 找到 \(collisions.count) 個衝突")
            let details = collisions.prefix(10).map { "\($0.title): \($0.start.ISO8601Format())–\($0.end.ISO8601Format())" }.joined(separator: "\n")
            return "Conflicts: \(collisions.count). \(details)\nVerified alternative: \(nextSlot?.ISO8601Format() ?? "none within 12 hours"). Do not invent alternatives."
        } catch is CancellationError { throw CancellationError() }
        catch {
            guard context == captured else { throw CancellationError() }
            calendarError = error.localizedDescription
            append("⚠ 行事曆無法查詢；衝突狀態未知")
            return "Calendar unavailable. Availability UNKNOWN: \(error.localizedDescription)"
        }
    }
}
