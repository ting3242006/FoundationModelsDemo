import Foundation

struct CalendarConflict: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
}
