import Foundation

enum CalendarAvailability {
    static func conflicts(start: Date, end: Date, events: [CalendarConflict]) -> [CalendarConflict] {
        guard end > start else { return [] }
        return events.filter { $0.start < end && $0.end > start && $0.end > $0.start }
    }
    static func nextSlot(after start: Date, duration: TimeInterval, until limit: Date, events: [CalendarConflict]) -> Date? {
        guard duration > 0, duration.isFinite, limit > start else { return nil }
        var candidate = start
        for event in events.filter({ $0.end > $0.start }).sorted(by: { $0.start < $1.start }) {
            if event.end <= candidate { continue }
            if candidate.addingTimeInterval(duration) <= event.start { break }
            candidate = max(candidate, event.end)
        }
        return candidate.addingTimeInterval(duration) <= limit ? candidate : nil
    }
}
