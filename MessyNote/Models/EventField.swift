import FoundationModels

@Generable
enum EventField: Sendable, Equatable {
    case title
    case date
    case time
    case duration
    case location
    case attendee
    case notes
    case reminder
}
