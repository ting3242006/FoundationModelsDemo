import Foundation

enum DraftMerge {
    static func merge(_ revision: EventRevision, into previous: ReviewedEvent) -> EventDraft {
        merge(revision, into: previous.asDraft())
    }
    static func merge(_ revision: EventRevision, into previous: EventDraft) -> EventDraft {
        var result = previous
        let values = revision.values
        for field in revision.changes {
            switch field {
            case .title: result.title = values.title
            case .date: result.date = values.date
            case .time: result.hour = values.hour; result.minute = values.minute
            case .duration: result.durationMinutes = values.durationMinutes
            case .location: result.location = values.location
            case .attendee: result.attendeeQuery = values.attendeeQuery
            case .notes: result.notes = values.notes
            case .reminder: result.reminderMinutesBefore = values.reminderMinutesBefore
            }
        }
        return result
    }
}

extension ReviewedEvent {
    /// Use an absolute date so a follow-up cannot reinterpret an old relative date against a new day.
    func asDraft() -> EventDraft {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        let date = DateIntent(kind: "explicit", dayOffset: 0, weekday: 1,
            year: calendar.component(.year, from: start), month: calendar.component(.month, from: start), day: calendar.component(.day, from: start))
        return EventDraft(title: title, date: date, hour: calendar.component(.hour, from: start), minute: calendar.component(.minute, from: start),
            durationMinutes: durationMinutes, attendeeQuery: attendeeQuery.isEmpty ? nil : attendeeQuery,
            location: location.isEmpty ? nil : location, notes: notes.isEmpty ? nil : notes, reminderMinutesBefore: reminderMinutesBefore)
    }
}
