import FoundationModels

// @Generable 加在 struct 上，意思是「模型可以直接產生這個型別」
@Generable(representNilExplicitlyInGeneratedContent: true)
struct EventDraft: Sendable {
    @Guide(description: "簡短事件標題") var title: String
    var date: DateIntent
    @Guide(description: "24-hour clock ONLY when an actual hour is stated. 下午三點=15; 下午四點=16; 晚上七點=19. Generic 晚上/evening without an hour MUST be null, never guessed.", .range(0...23)) var hour: Int?
    @Guide(description: "Minute explicitly stated in the latest clock: 16:30 => 30; 七點半 => 30; 七點/an exact whole hour => 0 even if prior draft had other minutes. Missing clock => 0.", .range(0...59)) var minute: Int
    @Guide(description: "Duration in minutes: 半小時/half an hour=30, 一小時=60, 兩小時=120. Use60 only when duration is absent.", .range(1...480)) var durationMinutes: Int
    @Guide(description: "Exact person name from the note; null if absent or only an anonymous description. Never the literal string nil, null, 無 or 空.") var attendeeQuery: String?
    @Guide(description: "Stated location, otherwise real null. Never a placeholder string such as nil or 無.") var location: String?
    @Guide(description: "Extra user notes, otherwise real null. Never a placeholder string such as nil or 無.") var notes: String?
    @Guide(description: "Reminder minutes before event: 前一天=1440, 兩小時前=120. Null when no reminder is requested; 0 only for an explicit at-event reminder.", .range(0...10080)) var reminderMinutesBefore: Int?
}
