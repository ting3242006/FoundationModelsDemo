import Foundation
import FoundationModels

@Generable(representNilExplicitlyInGeneratedContent: true)
struct ClockCompletion: Sendable {
    @Guide(description: "從USER_INPUT逐字複製明確的活動開始鐘點短語，包含時段及鐘點；只要短語，不要改寫或複製整句。中文數字與阿拉伯數字都可。只有時段、活動時長或提前提醒不是開始鐘點，找不到回null。")
    var clockPhrase: String?
    @Guide(description: "判斷clockPhrase本身是否明確提供開始鐘點。時段加中文數字鐘點或數字時刻為true；只有時段、時長、提醒間隔或null為false。同句另有時長或提醒不影響已找到的鐘點。")
    var hasExplicitStartTime: Bool
    @Guide(description: "只有hasExplicitStartTime為true時，從clockPhrase明說的開始鐘點抽取小時，結合上午、下午、晚上等時段換成24小時制；中文數字加「點」也是明確鐘點。false時回null。不可將只有時段的描述自行正規化成某個小時，也不可複製示例、時長或提醒數字。", .range(0...23))
    var hour: Int?
    @Guide(description: "只有hasExplicitStartTime為true且clockPhrase明說開始時刻的分鐘成分時才填值。只說某點而未提分鐘時回null，不補數字；「點半」明確表示30分鐘，數字時刻冒號後的分鐘照原文抽取。false時回null。持續時間及提前提醒的分鐘都不是開始時刻分鐘。", .range(0...59))
    var minute: Int?

    /// Literal source grounding only; the model remains responsible for interpreting the clock.
    func grounded(in note: String) -> ClockCompletion {
        guard hasExplicitStartTime, let clockPhrase,
              !clockPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              note.contains(clockPhrase) else {
            return ClockCompletion(clockPhrase: nil, hasExplicitStartTime: false, hour: nil, minute: nil)
        }
        return self
    }

    /// A clock-only result can never replace the draft's date or any other field.
    func applying(to draft: EventDraft, now: Date, timeZone: TimeZone) throws -> EventDraft {
        guard hasExplicitStartTime, let clockPhrase,
              !clockPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let hour else { return draft }
        let minute = minute ?? 0
        guard (0...23).contains(hour), (0...59).contains(minute) else { throw PlannerError.invalidDate }
        var values = draft
        values.hour = hour
        values.minute = minute
        return try GenerationResult.revision(EventRevision(changes: [.time], values: values))
            .mergedDraft(to: nil, pending: draft, now: now, timeZone: timeZone)
    }
}
