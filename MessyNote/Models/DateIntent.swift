import FoundationModels

@Generable
struct DateIntent: Sendable {
    @Guide(description: "Choose ONLY from the user note: 今天/明天/後天 use offset; nextWeek ONLY for explicit 下週/下禮拜/next week; explicit only for a stated calendar date. Reference context is not the event date.", .anyOf(["offset", "nextWeek", "explicit"])) var kind: String
    @Guide(description: "For offset: 今天/today=0, 明天/tomorrow=1, 後天=2. Do not add a week. Otherwise0.") var dayOffset: Int
    @Guide(description: "Only nextWeek uses this: requested Monday/一1, Tuesday/二2, Wednesday/三3, Thursday/四4, Friday/五5, Saturday/六6, Sunday/日7. Not the week start. Otherwise1.", .range(1...7)) var weekday: Int
    @Guide(description: "Stated year for explicit only; 0 for offset or nextWeek.") var year: Int
    @Guide(description: "Stated month for explicit only; 0 for offset or nextWeek.") var month: Int
    @Guide(description: "Stated day of month for explicit only; 0 for offset or nextWeek.") var day: Int
}
