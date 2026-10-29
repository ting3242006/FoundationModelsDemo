import EventKit

@MainActor
protocol CalendarWriting {
    func authorize() async throws
    func save(_ event: ReviewedEvent, contact: ContactCandidate?) throws -> String
}

@MainActor
final class CalendarWriter: CalendarWriting {
    private let store = EKEventStore()
    func authorize() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined || status == .writeOnly {
            guard try await store.requestFullAccessToEvents() else { throw PlannerError.denied("行事曆") }
        }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { throw PlannerError.denied("行事曆") }
    }
    func save(_ event: ReviewedEvent, contact: ContactCandidate?) throws -> String {
        try event.validate()
        guard let calendar = store.defaultCalendarForNewEvents else { throw PlannerError.denied("可寫入的預設行事曆") }
        let value = EKEvent(eventStore: store)
        value.calendar = calendar
        value.title = event.title
        value.startDate = event.start
        value.endDate = event.end
        value.timeZone = TimeZone(identifier: event.timeZoneIdentifier)
        value.location = event.location
        let attendee = contact?.displayName ?? event.attendeeQuery
        value.notes = event.notes + (attendee.isEmpty ? "" : "\n參與者：\(attendee)（僅筆記，不發邀請）")
        if let minutes = event.reminderMinutesBefore { value.addAlarm(EKAlarm(relativeOffset: -Double(minutes) * 60)) }
        try store.save(value, span: .thisEvent, commit: true)
        return value.eventIdentifier ?? "saved"
    }
}
