import EventKit

@MainActor
protocol CalendarReading: Sendable {
    func events(from start: Date, to end: Date) async throws -> [CalendarConflict]
}

@MainActor
final class CalendarService: CalendarReading {
    private let store = EKEventStore()
    func events(from start: Date, to end: Date) async throws -> [CalendarConflict] {
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            guard try await store.requestFullAccessToEvents() else { throw PlannerError.denied("行事曆") }
        }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { throw PlannerError.denied("行事曆") }
        try Task.checkCancellation()
        return store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil)).map {
            CalendarConflict(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "未命名行程", start: $0.startDate, end: $0.endDate)
        }
    }
}
