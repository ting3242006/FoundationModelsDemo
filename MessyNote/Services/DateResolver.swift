import Foundation

enum DateResolver {
    static func resolve(_ intent: DateIntent, hour: Int?, minute: Int, now: Date, timeZone: TimeZone) throws -> Date {
        guard let hour else { throw PlannerError.missingTime }
        guard (0...23).contains(hour), (0...59).contains(minute) else { throw PlannerError.invalidDate }
        let day = try resolveDay(intent, now: now, timeZone: timeZone)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        guard let result = calendar.date(from: components), calendar.component(.hour, from: result) == hour,
              calendar.component(.minute, from: result) == minute else { throw PlannerError.invalidDate }
        return result
    }
    /// Resolve and validate only the day, even when the user has not supplied a clock time.
    static func resolveDay(_ intent: DateIntent, now: Date, timeZone: TimeZone) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        let day: Date
        switch intent.kind {
        case "offset":
            guard (-365...365).contains(intent.dayOffset), let result = calendar.date(byAdding: .day, value: intent.dayOffset, to: calendar.startOfDay(for: now)) else { throw PlannerError.invalidDate }
            day = result
        case "nextWeek":
            guard (1...7).contains(intent.weekday) else { throw PlannerError.invalidDate }
            let mondayIndex = (calendar.component(.weekday, from: now) + 5) % 7
            guard let result = calendar.date(byAdding: .day, value: 7 - mondayIndex + intent.weekday - 1, to: calendar.startOfDay(for: now)) else { throw PlannerError.invalidDate }
            day = result
        case "explicit":
            guard (1900...2200).contains(intent.year), (1...12).contains(intent.month), (1...31).contains(intent.day),
                  let result = calendar.date(from: DateComponents(year: intent.year, month: intent.month, day: intent.day)),
                  calendar.component(.month, from: result) == intent.month,
                  calendar.component(.day, from: result) == intent.day else { throw PlannerError.invalidDate }
            day = result
        default: throw PlannerError.invalidDate
        }
        return day
    }
}
