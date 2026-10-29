import Foundation
import FoundationModels

@Generable(representNilExplicitlyInGeneratedContent: true)
struct DurationCompletion: Sendable {
    @Guide(description: "Explicit event duration in minutes, not a daily clock or reminder offset. 半小時 / half an hour is 30; 一個半小時 is 90. 兩小時前提醒 / remind two hours before is a reminder, NOT a 120-minute event. If no event duration is stated, return null; do not choose a default.", .range(1...480))
    var durationMinutes: Int?

    func applying(to draft: EventDraft) throws -> EventDraft {
        guard let durationMinutes else { return draft }
        guard (1...480).contains(durationMinutes) else { throw PlannerError.invalidDraft }
        var result = draft
        result.durationMinutes = durationMinutes
        return result
    }
}
