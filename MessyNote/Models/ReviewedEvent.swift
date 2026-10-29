import Foundation

struct ReviewedEvent: Equatable, Sendable {
    var title: String
    var start: Date
    var durationMinutes: Int
    var location: String
    var attendeeQuery: String
    var notes: String
    var reminderMinutesBefore: Int?
    var timeZoneIdentifier: String
    var end: Date { start.addingTimeInterval(Double(durationMinutes) * 60) }
    var context: String { "title=\(title); start=\(start.ISO8601Format()); duration=\(durationMinutes); location=\(location); attendee=\(attendeeQuery); notes=\(notes); reminder=\(reminderMinutesBefore.map(String.init) ?? "none"); timezone=\(timeZoneIdentifier)" }
    init(draft: EventDraft, now: Date, timeZone: TimeZone) throws {
        title = draft.title
        start = try DateResolver.resolve(draft.date, hour: draft.hour, minute: draft.minute, now: now, timeZone: timeZone)
        durationMinutes = draft.durationMinutes
        location = draft.location ?? ""
        attendeeQuery = draft.attendeeQuery ?? ""
        notes = draft.notes ?? ""
        reminderMinutesBefore = draft.reminderMinutesBefore
        timeZoneIdentifier = timeZone.identifier
        try validate()
    }
    func validate() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, (1...480).contains(durationMinutes), reminderMinutesBefore.map({ (0...10080).contains($0) }) ?? true else { throw PlannerError.invalidDraft }
    }
}
