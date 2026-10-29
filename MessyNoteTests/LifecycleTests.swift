import Foundation
import FoundationModels
import Testing
@testable import MessyNote

@MainActor
struct LifecycleTests {
    final class WriterSpy: CalendarWriting {
        var calls = 0
        var pause = false
        var authorization: CheckedContinuation<Void, Error>?
        func authorize() async throws {
            if pause { try await withCheckedThrowingContinuation { authorization = $0 } }
        }
        func save(_ event: ReviewedEvent, contact: ContactCandidate?) throws -> String { calls += 1; return "saved" }
    }
    final class ControlledGenerator: FoundationModelGenerating {
        var requests: [CheckedContinuation<GenerationResult, Error>] = []
        var partials: [@MainActor (EventDraft.PartiallyGenerated) -> Void] = []
        var resets = 0
        var revisionFlags: [Bool] = []
        var durationNotes: [String] = []
        var durationRequests: [CheckedContinuation<DurationCompletion, Error>] = []
        var automaticDuration = DurationCompletion(durationMinutes: nil)
        var pauseDuration = false
        var clockRequests: [CheckedContinuation<ClockCompletion, Error>] = []
        var clockNotes: [String] = []
        var automaticClock: ClockCompletion?
        var clockPartials: [@MainActor (ClockCompletion.PartiallyGenerated) -> Void] = []
        var reviewedContexts: [ToolLedger.Context] = []
        var pauseReview = false
        var pendingReview: CheckedContinuation<Void, Error>?
        func reset() { resets += 1 }
        func generate(_ note: String, current: String?, isRevision: Bool, now: Date, timeZone: TimeZone, onPartial: @escaping @MainActor (EventDraft.PartiallyGenerated) -> Void) async throws -> GenerationResult {
            partials.append(onPartial)
            revisionFlags.append(isRevision)
            return try await withCheckedThrowingContinuation { requests.append($0) }
        }
        func completeDuration(_ note: String) async throws -> DurationCompletion {
            durationNotes.append(note)
            if pauseDuration { return try await withCheckedThrowingContinuation { durationRequests.append($0) } }
            return automaticDuration
        }
        func completeClock(_ note: String, onPartial: @escaping @MainActor (ClockCompletion.PartiallyGenerated) -> Void) async throws -> ClockCompletion {
            clockNotes.append(note); clockPartials.append(onPartial)
            if let automaticClock { return automaticClock }
            return try await withCheckedThrowingContinuation { clockRequests.append($0) }
        }
        func review(_ context: ToolLedger.Context) async throws {
            reviewedContexts.append(context)
            if pauseReview { try await withCheckedThrowingContinuation { pendingReview = $0 } }
        }
    }
    struct DeniedContacts: ContactSearching {
        func candidates(matching query: String) async throws -> [ContactCandidate] { throw PlannerError.denied("聯絡人") }
    }
    struct DeniedCalendar: CalendarReading {
        func events(from start: Date, to end: Date) async throws -> [CalendarConflict] { throw PlannerError.denied("行事曆") }
    }
    final class PausedContacts: ContactSearching {
        var continuation: CheckedContinuation<[ContactCandidate], Error>?
        func candidates(matching query: String) async throws -> [ContactCandidate] {
            try await withCheckedThrowingContinuation { continuation = $0 }
        }
    }
    func draft(_ title: String = "Coffee") -> EventDraft {
        EventDraft(title: title, date: DateIntent(kind: "offset", dayOffset: 1, weekday: 1, year: 2026, month: 10, day: 21), hour: 15, minute: 0, durationMinutes: 60, attendeeQuery: "小明", location: "台北", notes: "", reminderMinutesBefore: 1440)
    }
    func reviewed() throws -> ReviewedEvent {
        try ReviewedEvent(draft: draft(), now: Date(timeIntervalSince1970: 0), timeZone: TimeZone(secondsFromGMT: 0)!)
    }
    func eventually(_ predicate: () -> Bool) async throws {
        for _ in 0..<1000 { if predicate() { return }; await Task.yield() }
        try #require(predicate())
    }
    @Test func unavailableModelDoesNotStartGeneration() {
        let fake = ControlledGenerator()
        let reason = "系統模型尚未就緒，請稍後重新檢查。"
        let model = PlannerViewModel(service: fake, writer: WriterSpy(), availability: .unavailable(reason))
        model.generate()
        #expect(fake.requests.isEmpty)
        #expect(fake.partials.isEmpty)
        #expect(model.task == nil)
        #expect(model.isLoading == false)
        #expect(model.event == nil)
        #expect(model.availability == .unavailable(reason))
    }
    @Test func staleGenerationCannotUpdateDraftOrPartialOrSave() async throws {
        let fake = ControlledGenerator()
        let spy = WriterSpy()
        let model = PlannerViewModel(service: fake, writer: spy, availability: .available)
        model.generate()
        let old = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        model.generate()
        let current = try #require(model.task)
        try await eventually { fake.requests.count == 2 }
        fake.partials[0](try EventDraft.PartiallyGenerated(draft("OLD").generatedContent))
        #expect(model.partial == nil)
        fake.requests[0].resume(returning: .revision(EventRevision(changes: [.attendee], values: draft("OLD"))))
        await old.value
        #expect(model.event == nil)
        fake.requests[1].resume(returning: .initial(draft("NEW")))
        await current.value
        #expect(model.event?.title == "NEW")
        #expect(spy.calls == 0)
        #expect(fake.resets == 1)
    }
    @Test func canceledErrorDoesNotOverwriteNewState() async throws {
        let fake = ControlledGenerator()
        let model = PlannerViewModel(service: fake, writer: WriterSpy(), availability: .available)
        model.generate()
        let old = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        model.reset()
        fake.requests[0].resume(throwing: PlannerError.invalidDate)
        await old.value
        #expect(model.error == nil)
        #expect(model.isLoading == false)
        #expect(model.ledger.activity.isEmpty)
    }
    @Test func missingTimeFollowUpUsesRevisionAndPreservesDate() async throws {
        let fake = ControlledGenerator()
        fake.automaticClock = ClockCompletion(clockPhrase: nil, hasExplicitStartTime: false, hour: nil, minute: 0)
        let model = PlannerViewModel(service: fake, writer: WriterSpy(), availability: .available)
        model.generate()
        let first = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        var incomplete = draft(); incomplete.hour = nil; incomplete.date.kind = "nextWeek"; incomplete.date.weekday = 5
        fake.requests[0].resume(returning: .initial(incomplete))
        await first.value
        #expect(model.event == nil)
        #expect(model.draft?.attendeeQuery == "小明")
        model.input = "晚上七點"
        model.generate()
        let second = try #require(model.task)
        try await eventually { fake.requests.count == 2 }
        var complete = incomplete; complete.hour = 19; complete.minute = 0; complete.date.weekday = 1
        fake.requests[1].resume(returning: .revision(EventRevision(changes: [.time], values: complete)))
        await second.value
        #expect(fake.revisionFlags == [false, true])
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        #expect(model.event.map { calendar.component(.weekday, from: $0.start) } == 6)
        #expect(model.draft?.date.kind == "explicit")
        #expect(model.event?.attendeeQuery == "小明")
        #expect(model.event?.durationMinutes == 60)
        #expect(model.event != nil)
        #expect(model.error == nil)
    }
    @Test func manualTimeUsesFixedDateReviewsAndNeverWrites() async throws {
        let fake = ControlledGenerator(); let spy = WriterSpy()
        let model = PlannerViewModel(service: fake, writer: spy, availability: .available)
        var pending = draft(); pending.hour = nil
        pending.date = DateIntent(kind: "explicit", dayOffset: 0, weekday: 1, year: 2026, month: 10, day: 30)
        model.draft = pending
        let zone = TimeZone(identifier: "Asia/Taipei")!
        let choice = ISO8601DateFormatter().date(from: "2026-10-21T19:00:00+08:00")!
        model.completePendingTime(choice, now: choice, timeZone: zone)
        let task = try #require(model.task)
        #expect(model.isLoading)
        #expect(!model.canSave)
        await task.value
        #expect(model.event?.start == ISO8601DateFormatter().date(from: "2026-10-30T19:00:00+08:00"))
        #expect(model.event?.attendeeQuery == "小明")
        #expect(fake.reviewedContexts.count == 1)
        #expect(fake.requests.isEmpty)
        #expect(spy.calls == 0)
    }
    @Test func invalidPendingDateCannotStartManualReview() {
        let fake = ControlledGenerator()
        let model = PlannerViewModel(service: fake, writer: WriterSpy(), availability: .available)
        var pending = draft(); pending.hour = nil
        pending.date = DateIntent(kind: "explicit", dayOffset: 0, weekday: 1, year: 2026, month: 2, day: 30)
        model.draft = pending
        model.completePendingTime(.now)
        #expect(model.event == nil)
        #expect(fake.reviewedContexts.isEmpty)
        #expect(model.error != nil)
    }
    @Test func canceledManualReviewCannotRestoreResetDraft() async throws {
        let fake = ControlledGenerator(); fake.pauseReview = true
        let model = PlannerViewModel(service: fake, writer: WriterSpy(), availability: .available)
        var pending = draft(); pending.hour = nil
        model.draft = pending
        model.completePendingTime(.now)
        let task = try #require(model.task)
        try await eventually { fake.pendingReview != nil }
        model.reset()
        fake.pendingReview?.resume()
        await task.value
        #expect(model.event == nil)
        #expect(model.draft == nil)
        #expect(!model.isLoading)
        #expect(model.ledger.activity.isEmpty)
    }
    @Test func invalidRevisionPreservesPreviousUsableDraft() async throws {
        let fake = ControlledGenerator()
        let model = PlannerViewModel(service: fake, writer: WriterSpy(), availability: .available)
        let original = try reviewed()
        model.event = original
        model.generate()
        let current = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        var values = draft(); values.hour = nil
        fake.requests[0].resume(returning: .revision(EventRevision(changes: [.time], values: values)))
        await current.value
        #expect(model.event == original)
        #expect(model.error?.contains("保留前一份草稿") == true)
        #expect(model.isLoading == false)
    }
    @Test func pendingAuthorizationCannotSaveAfterInvalidationOrDoubleTap() async throws {
        let spy = WriterSpy()
        spy.pause = true
        let gate = SaveCoordinator(writer: spy)
        gate.prepare(event: try reviewed(), contact: nil)
        let review = try #require(gate.review)
        let first = Task { try await gate.confirm(review) }
        try await eventually { spy.authorization != nil }
        await #expect(throws: PlannerError.self) { try await gate.confirm(review) }
        gate.invalidate()
        spy.authorization?.resume()
        _ = try? await first.value
        #expect(spy.calls == 0)
        #expect(gate.isSaving == false)
    }
    @Test func deniedToolsPreserveDraftAndUnknownAvailability() async throws {
        let ledger = ToolLedger(contacts: DeniedContacts(), calendar: DeniedCalendar())
        let event = try reviewed()
        let context = ledger.prepare(event: event, generation: UUID())
        _ = try await FindContactTool(ledger: ledger).call(arguments: .init(query: "小明", draftID: context.draftID))
        _ = try await CheckCalendarTool(ledger: ledger).call(arguments: .init(draftID: context.draftID))
        #expect(ledger.context?.event == event)
        #expect(ledger.contactError != nil)
        #expect(ledger.calendarError != nil)
        #expect(ledger.conflicts == nil)
        #expect(ledger.nextSlot == nil)
    }
    @Test func staleToolCompletionIsDiscarded() async throws {
        let contacts = PausedContacts()
        let ledger = ToolLedger(contacts: contacts, calendar: DeniedCalendar())
        let context = ledger.prepare(event: try reviewed(), generation: UUID())
        let query = Task { try await ledger.find(query: "小明", draftID: context.draftID) }
        try await eventually { contacts.continuation != nil }
        ledger.reset()
        contacts.continuation?.resume(returning: [ContactCandidate(id: "old", displayName: "過期結果")])
        _ = try? await query.value
        #expect(ledger.candidates == nil)
        #expect(ledger.activity.isEmpty)
    }
    @Test func mismatchedToolArgumentsNeverQuery() async throws {
        let contacts = PausedContacts()
        let ledger = ToolLedger(contacts: contacts, calendar: DeniedCalendar())
        let context = ledger.prepare(event: try reviewed(), generation: UUID())
        let value = try await ledger.find(query: "不同姓名", draftID: context.draftID)
        #expect(value.contains("Rejected"))
        #expect(contacts.continuation == nil)
    }
    @Test func editingInvalidatesEvidenceAndContactSelection() throws {
        let model = PlannerViewModel(writer: WriterSpy(), availability: .available)
        model.event = try reviewed()
        model.selectedContact = ContactCandidate(id: "a", displayName: "王小明")
        _ = model.ledger.prepare(event: try reviewed(), generation: UUID())
        model.prepareSave()
        #expect(model.presentedReview != nil)
        model.event?.attendeeQuery = "Amy"
        #expect(model.selectedContact == nil)
        #expect(model.ledger.context == nil)
        #expect(model.presentedReview == nil)
        #expect(model.canSave == false)
    }
    @Test func fixtureOnlyReadsAndSlotAcceptanceInvalidatesEvidence() async throws {
        let ledger = ToolLedger(contacts: DemoContacts(), calendar: DemoCalendar(now: Date(timeIntervalSince1970: 0), timeZone: TimeZone(secondsFromGMT: 0)!))
        let spy = WriterSpy()
        let model = PlannerViewModel(ledger: ledger, writer: spy, availability: .available)
        var event = try reviewed()
        event.start = try DateResolver.resolve(DateIntent(kind: "nextWeek", dayOffset: 0, weekday: 3, year: 0, month: 0, day: 0), hour: 15, minute: 0, now: Date(timeIntervalSince1970: 0), timeZone: TimeZone(secondsFromGMT: 0)!)
        model.event = event
        let context = ledger.prepare(event: event, generation: UUID())
        _ = try await ledger.check(draftID: context.draftID)
        #expect(ledger.nextSlot == event.start.addingTimeInterval(5400))
        model.acceptSlot()
        #expect(model.event?.start == event.start.addingTimeInterval(5400))
        #expect(ledger.conflicts == nil)
        #expect(ledger.nextSlot == nil)
        #expect(spy.calls == 0)
    }
}
