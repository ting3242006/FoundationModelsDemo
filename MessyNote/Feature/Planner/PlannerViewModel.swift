import Foundation
import FoundationModels
import Observation
import SwiftUI

@MainActor @Observable
final class PlannerViewModel {
    var availability: ModelState
    var input = "下週三下午三點跟小明在信義區喝咖啡一小時，記得帶合約，前一天提醒我"
    var draft: EventDraft?
    var partial: EventDraft.PartiallyGenerated?
    var clockPartial: ClockCompletion.PartiallyGenerated?
    var event: ReviewedEvent? {
        didSet {
            guard event != oldValue else { return }
            if event?.attendeeQuery != oldValue?.attendeeQuery { selectedContact = nil; proceedUnresolved = false }
            ledger.invalidate()
            saver.invalidate()
            presentedReview = nil
            success = nil
        }
    }
    var selectedContact: ContactCandidate?
    var proceedUnresolved = false
    var presentedReview: SaveReview?
    var success: String?
    let saver: SaveCoordinator
    var error: String?
    var isLoading = false
    private var generation = UUID()
    private(set) var task: Task<Void, Never>?
    private(set) var ledger: ToolLedger
    private var service: any FoundationModelGenerating
    init(ledger: ToolLedger? = nil, service: (any FoundationModelGenerating)? = nil, writer: any CalendarWriting = CalendarWriter(), availability: ModelState? = nil) {
        let activeLedger = ledger ?? ToolLedger(contacts: ContactService(), calendar: CalendarService())
        self.ledger = activeLedger
        self.service = service ?? FoundationModelService(ledger: activeLedger)
        self.saver = SaveCoordinator(writer: writer)
        self.availability = availability ?? ModelState.current()
    }
    #if DEBUG
    var fixtureMode = false {
        didSet {
            guard fixtureMode != oldValue else { return }
            reset()
            ledger = fixtureMode ? ToolLedger(contacts: DemoContacts(), calendar: DemoCalendar()) : ToolLedger(contacts: ContactService(), calendar: CalendarService())
            service = FoundationModelService(ledger: ledger)
        }
    }
    #endif
    var isFixture: Bool {
        #if DEBUG
        fixtureMode
        #else
        false
        #endif
    }
    func fillExample() { input = "下週三下午三點跟小明在信義區喝咖啡一小時，記得帶合約，前一天提醒我" }
    func generate() {
        guard !saver.isSaving, availability == .available, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if isLoading { cancel() }
        let id = UUID()
        generation = id
        let note = input
        let previousEvent = event
        let pendingDraft = draft
        #if DEBUG
        AcceptanceDiagnostics.record("generation.begin id=\(id.uuidString) previousStart=\(previousEvent?.start.ISO8601Format() ?? "nil") pending=\(pendingDraft != nil)")
        if let pendingDraft { AcceptanceDiagnostics.record("generation.baseline id=\(id.uuidString) \(AcceptanceDiagnostics.timing(pendingDraft))") }
        #endif
        let current = previousEvent?.context ?? draft.map { String(describing: $0.generatedContent) }
        let now = Date.now
        let zone = previousEvent.flatMap { TimeZone(identifier: $0.timeZoneIdentifier) } ?? .current
        ledger.reset()
        ledger.append("→ 理解筆記並接收 typed streaming")
        error = nil
        partial = nil
        clockPartial = nil
        event = nil
        isLoading = true
        task = Task { [weak self] in
            guard let self else { return }
            defer { if generation == id { isLoading = false } }
            do {
                let result = try await service.generate(note, current: current, isRevision: previousEvent != nil || pendingDraft != nil, now: now, timeZone: zone) { [weak self] value in
                    guard let self, generation == id else { return }
                    partial = value
                }
                guard generation == id else { return }
                if previousEvent == nil, pendingDraft == nil { draft = result.proposedDraft }
                #if DEBUG
                AcceptanceDiagnostics.record("merge.before id=\(id.uuidString) previousStart=\(previousEvent?.start.ISO8601Format() ?? "nil") pending=\(pendingDraft != nil)")
                #endif
                let merged = try result.mergedDraft(to: previousEvent, pending: pendingDraft, now: now, timeZone: zone)
                #if DEBUG
                AcceptanceDiagnostics.record("merge.after id=\(id.uuidString) \(AcceptanceDiagnostics.timing(merged))")
                #endif
                draft = merged
                partial = nil
                let durationChecked = try await service.completeInitialDuration(in: merged, after: result, note: note)
                guard generation == id else { return }
                draft = durationChecked
                let completed = try await service.completePendingClock(in: durationChecked, after: result, previousEvent: previousEvent, previousPending: pendingDraft, note: note, now: now, timeZone: zone) { [weak self] value in
                    guard let self, generation == id else { return }
                    clockPartial = value
                }
                guard generation == id else { return }
                draft = completed
                let reviewed = try ReviewedEvent(draft: completed, now: now, timeZone: zone)
                draft = reviewed.asDraft()
                event = reviewed
                ledger.append("✓ Parsed note · Swift 日期校驗完成")
                try await review(reviewed, generation: id)
            } catch is CancellationError { }
            catch {
                if generation == id {
                    self.error = ModelErrorPresentation.message(for: error)
                    if event == nil, let previousEvent {
                        event = previousEvent
                        draft = previousEvent.asDraft()
                        self.error = "修改未通過驗證，已保留前一份草稿。" + (self.error ?? "")
                    }
                }
            }
        }
    }
    /// A disappearing editor can still be read by SwiftUI after the optional event is cleared.
    /// Keep that read safe, and never accept writes from a superseded or disabled editor.
    func editorBinding(for snapshot: ReviewedEvent) -> Binding<ReviewedEvent> {
        let id = generation
        return Binding(
            get: { [weak self] in
                guard let self, self.generation == id else { return snapshot }
                return self.event ?? snapshot
            },
            set: { [weak self] value in
                guard let self, self.generation == id, self.event != nil,
                      !self.isLoading, !self.saver.isSaving, !self.saver.saved else { return }
                self.event = value
            }
        )
    }

    var pendingDay: Date? {
        guard event == nil, let draft, draft.hour == nil else { return nil }
        return try? DateResolver.resolveDay(draft.date, now: .now, timeZone: .current)
    }
    /// An explicit human choice changes only the clock; the model still performs all read-only tool calls.
    func completePendingTime(_ clock: Date, now: Date = .now, timeZone: TimeZone = .current) {
        guard !isLoading, !saver.isSaving, availability == .available, event == nil,
              let pending = draft, pending.hour == nil else { return }
        do {
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
            var values = pending
            values.hour = calendar.component(.hour, from: clock)
            values.minute = calendar.component(.minute, from: clock)
            let result = GenerationResult.revision(EventRevision(changes: [.time], values: values))
            let reviewed = try result.applying(to: nil, pending: pending, now: now, timeZone: timeZone)
            let id = UUID(); generation = id
            draft = reviewed.asDraft()
            event = reviewed
            partial = nil
            clockPartial = nil
            error = nil
            ledger.reset()
            ledger.append("✓ 使用者確認時間 · Swift 日期校驗完成")
            isLoading = true
            task = Task { [weak self] in
                guard let self else { return }
                defer { if generation == id { isLoading = false } }
                do { try await review(reviewed, generation: id) }
                catch is CancellationError { }
                catch { if generation == id { self.error = ModelErrorPresentation.message(for: error) } }
            }
        } catch { self.error = ModelErrorPresentation.message(for: error) }
    }
    private func review(_ reviewed: ReviewedEvent, generation id: UUID) async throws {
        try Task.checkCancellation()
        guard generation == id else { return }
        #if DEBUG
        AcceptanceDiagnostics.record("review.begin id=\(id.uuidString) start=\(reviewed.start.ISO8601Format())")
        #endif
        let context = ledger.prepare(event: reviewed, generation: id)
        try await service.review(context)
        guard generation == id else { return }
        if case .single(let candidate) = ContactResolution.resolve(ledger.candidates ?? []) { selectedContact = candidate }
        if ledger.conflicts == nil && ledger.calendarError == nil { ledger.append("未取得有效行事曆工具結果；空檔未知") }
    }
    var canSave: Bool {
        guard let event, !isLoading, !saver.isSaving, !saver.saved else { return false }
        return (try? event.validate()) != nil && (event.attendeeQuery.isEmpty || selectedContact != nil || proceedUnresolved)
    }
    func acceptSlot() {
        guard let slot = ledger.nextSlot, var value = event else { return }
        value.start = slot
        event = value
        ledger.append("已接受建議時間；舊查詢證據已失效，可再次請模型檢查。")
    }
    func prepareSave() {
        guard canSave, let event else { return }
        error = nil
        saver.prepare(event: event, contact: selectedContact)
        presentedReview = saver.review
    }
    func confirmSave(_ review: SaveReview) async {
        let id = generation
        do {
            let saved = try await saver.confirm(review)
            guard generation == id else { return }
            if saved { success = "已加入系統行事曆"; presentedReview = nil }
        } catch { if generation == id { self.error = error.localizedDescription } }
    }
    func cancelReview() { presentedReview = nil; saver.invalidate() }
    func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
        isLoading = false
        partial = nil
        clockPartial = nil
        service.reset()
        ledger.invalidate()
        saver.invalidate()
        presentedReview = nil
    }
    func reset() { cancel(); draft = nil; event = nil; error = nil; ledger.reset(); selectedContact = nil; proceedUnresolved = false; success = nil }
    isolated deinit { task?.cancel() }
}
