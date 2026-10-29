import Foundation
import FoundationModels
import Testing
@testable import MessyNote

@MainActor
struct PendingClockTests {
    let zone = TimeZone.current
    func pending() -> EventDraft {
        EventDraft(title: "吃飯", date: DateIntent(kind: "explicit", dayOffset: 0, weekday: 5, year: 2026, month: 10, day: 30), hour: nil, minute: 0, durationMinutes: 60, attendeeQuery: nil, location: "台北", notes: "帶合約", reminderMinutesBefore: 1440)
    }
    func expected(day: Int = 30, hour: Int = 19) throws -> Date {
        try DateResolver.resolve(DateIntent(kind: "explicit", dayOffset: 0, weekday: 1, year: 2026, month: 10, day: day), hour: hour, minute: 0, now: .now, timeZone: zone)
    }
    func eventually(_ predicate: () -> Bool) async throws {
        for _ in 0..<1000 { if predicate() { return }; await Task.yield() }
        try #require(predicate())
    }
    @Test func omittedTimeMaskCompletesClockWithoutReplacingFriday() async throws {
        let fake = LifecycleTests.ControlledGenerator(); let writer = LifecycleTests.WriterSpy()
        let model = PlannerViewModel(service: fake, writer: writer, availability: .available)
        model.draft = pending(); model.input = "晚上七點，吃飯一個半小時，同行者叫阿不存在，取消提醒"
        model.generate(); let task = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        var values = pending(); values.title = "吃飯約會"; values.hour = 19
        values.date.day = 26; values.attendeeQuery = "阿不存在"; values.durationMinutes = 90; values.reminderMinutesBefore = nil
        fake.requests[0].resume(returning: .revision(EventRevision(changes: [.title, .attendee, .duration, .reminder], values: values)))
        try await eventually { fake.clockRequests.count == 1 }
        #expect(fake.clockNotes == [model.input])
        #expect(model.draft?.attendeeQuery == "阿不存在")
        #expect(model.event == nil)
        fake.clockPartials[0](try ClockCompletion.PartiallyGenerated(ClockCompletion(clockPhrase: "19:00", hasExplicitStartTime: true, hour: 19, minute: 0).generatedContent))
        #expect(model.clockPartial?.hour == 19)
        #expect(!model.canSave)
        fake.clockRequests[0].resume(returning: ClockCompletion(clockPhrase: "19:00", hasExplicitStartTime: true, hour: 19, minute: 0))
        await task.value
        #expect(model.event?.start == (try expected()))
        #expect(model.event?.attendeeQuery == "阿不存在")
        #expect(model.event?.durationMinutes == 90)
        #expect(model.event?.reminderMinutesBefore == nil)
        #expect(model.event?.location == "台北")
        #expect(fake.reviewedContexts.count == 1)
        #expect(writer.calls == 0)
    }
    @Test func explicitDateAndClearSurviveClockCompletion() async throws {
        let fake = LifecycleTests.ControlledGenerator()
        let model = PlannerViewModel(service: fake, writer: LifecycleTests.WriterSpy(), availability: .available)
        var baseline = pending(); baseline.attendeeQuery = "小明"
        model.draft = baseline; model.input = "改到十月三十一日晚上七點，移除參與者與筆記"
        model.generate(); let task = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        var values = pending(); values.date.day = 31; values.attendeeQuery = nil; values.notes = nil
        fake.requests[0].resume(returning: .revision(EventRevision(changes: [.date, .attendee, .notes], values: values)))
        try await eventually { fake.clockRequests.count == 1 }
        fake.clockRequests[0].resume(returning: ClockCompletion(clockPhrase: "19:00", hasExplicitStartTime: true, hour: 19, minute: 0))
        await task.value
        #expect(model.event?.start == (try expected(day: 31)))
        #expect(model.event?.attendeeQuery == "")
        #expect(model.event?.notes == "")
        #expect(model.event?.reminderMinutesBefore == 1440)
    }
    @Test(arguments: [ClockCompletion(clockPhrase: nil, hasExplicitStartTime: false, hour: nil, minute: 0), ClockCompletion(clockPhrase: "24:00", hasExplicitStartTime: true, hour: 24, minute: 0), ClockCompletion(clockPhrase: "19:60", hasExplicitStartTime: true, hour: 19, minute: 60)])
    func absentOrInvalidClockStaysPending(_ clock: ClockCompletion) async throws {
        let fake = LifecycleTests.ControlledGenerator(); let writer = LifecycleTests.WriterSpy()
        let model = PlannerViewModel(service: fake, writer: writer, availability: .available)
        model.draft = pending(); model.input = "晚上跟阿不存在吃飯"
        model.generate(); let task = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        var values = pending(); values.hour = 19; values.attendeeQuery = "阿不存在"
        fake.requests[0].resume(returning: .revision(EventRevision(changes: [.attendee], values: values)))
        try await eventually { fake.clockRequests.count == 1 }
        fake.clockRequests[0].resume(returning: clock)
        await task.value
        #expect(model.event == nil)
        #expect(model.draft?.hour == nil)
        #expect(model.draft?.attendeeQuery == "阿不存在")
        #expect(fake.reviewedContexts.isEmpty)
        #expect(fake.clockRequests.count == 1)
        #expect(writer.calls == 0)
    }
    @Test(arguments: ["cancel", "reset", "mode"])
    func obsoleteClockCannotPublish(_ action: String) async throws {
        let fake = LifecycleTests.ControlledGenerator(); let writer = LifecycleTests.WriterSpy()
        let model = PlannerViewModel(service: fake, writer: writer, availability: .available)
        model.draft = pending(); model.input = "晚上七點"
        model.generate(); let task = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        fake.requests[0].resume(returning: .revision(EventRevision(changes: [], values: pending())))
        try await eventually { fake.clockRequests.count == 1 }
        fake.clockPartials[0](try ClockCompletion.PartiallyGenerated(ClockCompletion(clockPhrase: "19:00", hasExplicitStartTime: true, hour: 19, minute: 0).generatedContent))
        if action == "cancel" { model.cancel() }
        else if action == "reset" { model.reset() }
        else { model.fixtureMode = true }
        fake.clockPartials[0](try ClockCompletion.PartiallyGenerated(ClockCompletion(clockPhrase: "20:00", hasExplicitStartTime: true, hour: 20, minute: 0).generatedContent))
        fake.clockRequests[0].resume(returning: ClockCompletion(clockPhrase: "19:00", hasExplicitStartTime: true, hour: 19, minute: 0))
        await task.value
        #expect(model.event == nil)
        #expect(model.clockPartial == nil)
        #expect(!model.isLoading)
        #expect(fake.reviewedContexts.isEmpty)
        #expect(writer.calls == 0)
    }
    @Test(arguments: [false, true])
    func existingClockDoesNotTriggerExtraExtraction(_ hasReviewedEvent: Bool) async throws {
        let fake = LifecycleTests.ControlledGenerator()
        let model = PlannerViewModel(service: fake, writer: LifecycleTests.WriterSpy(), availability: .available)
        var baseline = pending()
        if hasReviewedEvent {
            baseline.hour = 15
            model.event = try ReviewedEvent(draft: baseline, now: .now, timeZone: zone)
        }
        model.draft = baseline; model.input = "晚上七點"
        model.generate(); let task = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        var values = baseline; values.hour = 19
        fake.requests[0].resume(returning: .revision(EventRevision(changes: [.time], values: values)))
        await task.value
        #expect(fake.clockRequests.isEmpty)
        #expect(model.event?.start == (try expected()))
        #expect(fake.reviewedContexts.count == 1)
    }
    @Test func explicitTimeClearDoesNotTriggerClockExtraction() async throws {
        let fake = LifecycleTests.ControlledGenerator(); fake.automaticClock = ClockCompletion(clockPhrase: "19:00", hasExplicitStartTime: true, hour: 19, minute: 0)
        let model = PlannerViewModel(service: fake, writer: LifecycleTests.WriterSpy(), availability: .available)
        model.draft = pending(); model.input = "先不要設定時間"
        model.generate(); let task = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        fake.requests[0].resume(returning: .revision(EventRevision(changes: [.time], values: pending())))
        await task.value
        #expect(fake.clockNotes.isEmpty)
        #expect(model.event == nil)
        #expect(model.draft?.hour == nil)
        #expect(fake.reviewedContexts.isEmpty)
    }

    @Test func initialMissingClockUsesSameNoteAndPreservesOtherFields() async throws {
        let fake = LifecycleTests.ControlledGenerator(); let writer = LifecycleTests.WriterSpy()
        fake.automaticClock = ClockCompletion(clockPhrase: "19:00", hasExplicitStartTime: true, hour: 19, minute: 0)
        let model = PlannerViewModel(service: fake, writer: writer, availability: .available)
        model.input = "十月三十日晚上七點在台北吃飯一個半小時，帶合約，前一天提醒"
        model.generate(); let task = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        var initial = pending(); initial.durationMinutes = 90; initial.attendeeQuery = "Amy"
        fake.requests[0].resume(returning: .initial(initial))
        await task.value
        #expect(fake.clockNotes == [model.input])
        #expect(model.event?.start == (try expected()))
        #expect(model.event?.title == initial.title)
        #expect(model.event?.durationMinutes == 90)
        #expect(model.event?.attendeeQuery == "Amy")
        #expect(model.event?.location == "台北")
        #expect(model.event?.notes == "帶合約")
        #expect(model.event?.reminderMinutesBefore == 1440)
        #expect(fake.reviewedContexts.count == 1)
        #expect(writer.calls == 0)
    }

    @Test(arguments: [ClockCompletion(clockPhrase: nil, hasExplicitStartTime: false, hour: nil, minute: 0), ClockCompletion(clockPhrase: "24:00", hasExplicitStartTime: true, hour: 24, minute: 0), ClockCompletion(clockPhrase: "19:60", hasExplicitStartTime: true, hour: 19, minute: 60)])
    func initialAbsentOrInvalidClockStaysPending(_ clock: ClockCompletion) async throws {
        let fake = LifecycleTests.ControlledGenerator(); let writer = LifecycleTests.WriterSpy()
        fake.automaticClock = clock
        let model = PlannerViewModel(service: fake, writer: writer, availability: .available)
        model.input = "下週五晚上吃飯一小時"
        model.generate(); let task = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        fake.requests[0].resume(returning: .initial(pending()))
        await task.value
        #expect(fake.clockNotes == [model.input])
        #expect(model.event == nil)
        #expect(model.draft?.hour == nil)
        #expect(model.draft?.date.day == 30)
        #expect(model.draft?.durationMinutes == 60)
        #expect(fake.reviewedContexts.isEmpty)
        #expect(writer.calls == 0)
    }

    @Test func initialExistingClockBypassesExtractionAndKeepsOtherFields() async throws {
        let fake = LifecycleTests.ControlledGenerator()
        fake.automaticClock = ClockCompletion(clockPhrase: nil, hasExplicitStartTime: false, hour: nil, minute: nil)
        let model = PlannerViewModel(service: fake, writer: LifecycleTests.WriterSpy(), availability: .available)
        model.generate(); let task = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        var initial = pending(); initial.hour = 18; initial.minute = 30; initial.attendeeQuery = "Amy"
        fake.requests[0].resume(returning: .initial(initial))
        await task.value
        #expect(fake.clockNotes.isEmpty)
        #expect(model.event?.start == (try DateResolver.resolve(initial.date, hour: initial.hour, minute: initial.minute, now: .now, timeZone: zone)))
        #expect(model.event?.title == initial.title)
        #expect(model.event?.durationMinutes == initial.durationMinutes)
        #expect(model.event?.attendeeQuery == initial.attendeeQuery)
        #expect(model.event?.location == initial.location)
        #expect(model.event?.notes == initial.notes)
        #expect(model.event?.reminderMinutesBefore == initial.reminderMinutesBefore)
        #expect(fake.reviewedContexts.count == 1)
    }

    @Test(arguments: ["cancel", "reset", "mode"])
    func obsoleteInitialClockCannotPublish(_ action: String) async throws {
        let fake = LifecycleTests.ControlledGenerator(); let writer = LifecycleTests.WriterSpy()
        let model = PlannerViewModel(service: fake, writer: writer, availability: .available)
        model.input = "明天晚上七點吃飯"
        model.generate(); let task = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        fake.requests[0].resume(returning: .initial(pending()))
        try await eventually { fake.clockRequests.count == 1 }
        fake.clockPartials[0](try ClockCompletion.PartiallyGenerated(ClockCompletion(clockPhrase: "19:00", hasExplicitStartTime: true, hour: 19, minute: 0).generatedContent))
        #expect(model.clockPartial?.hour == 19)
        #expect(!model.canSave)
        if action == "cancel" { model.cancel() }
        else if action == "reset" { model.reset() }
        else { model.fixtureMode = true }
        fake.clockPartials[0](try ClockCompletion.PartiallyGenerated(ClockCompletion(clockPhrase: "20:00", hasExplicitStartTime: true, hour: 20, minute: 0).generatedContent))
        fake.clockRequests[0].resume(returning: ClockCompletion(clockPhrase: "19:00", hasExplicitStartTime: true, hour: 19, minute: 0))
        await task.value
        #expect(model.event == nil)
        #expect(model.clockPartial == nil)
        #expect(!model.isLoading)
        #expect(fake.reviewedContexts.isEmpty)
        #expect(writer.calls == 0)
    }

    @Test(arguments: [nil, 30, 45] as [Int?])
    func explicitHourUsesOnlySuppliedMinuteAndPreservesOtherFields(_ minute: Int?) throws {
        var baseline = pending()
        baseline.hour = 14; baseline.minute = 45; baseline.attendeeQuery = "Amy"
        let result = try ClockCompletion(clockPhrase: "15:00", hasExplicitStartTime: true, hour: 15, minute: minute).applying(to: baseline, now: .now, timeZone: zone)
        #expect(result.hour == 15)
        #expect(result.minute == (minute ?? 0))
        #expect(result.date.kind == "explicit")
        #expect(result.date.year == baseline.date.year)
        #expect(result.date.month == baseline.date.month)
        #expect(result.date.day == baseline.date.day)
        #expect(result.title == baseline.title)
        #expect(result.durationMinutes == baseline.durationMinutes)
        #expect(result.attendeeQuery == baseline.attendeeQuery)
        #expect(result.location == baseline.location)
        #expect(result.notes == baseline.notes)
        #expect(result.reminderMinutesBefore == baseline.reminderMinutesBefore)
        let event = try ReviewedEvent(draft: result, now: .now, timeZone: zone)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        #expect(calendar.component(.hour, from: event.start) == 15)
        #expect(calendar.component(.minute, from: event.start) == (minute ?? 0))
    }

    @Test func absentHourAndMinuteLeaveTheEntireDraftUnchanged() throws {
        var baseline = pending(); baseline.hour = 14; baseline.minute = 45
        let result = try ClockCompletion(clockPhrase: nil, hasExplicitStartTime: true, hour: nil, minute: nil).applying(to: baseline, now: .now, timeZone: zone)
        #expect(result.title == baseline.title)
        #expect(result.date.kind == baseline.date.kind)
        #expect(result.date.dayOffset == baseline.date.dayOffset)
        #expect(result.date.weekday == baseline.date.weekday)
        #expect(result.date.year == baseline.date.year)
        #expect(result.date.month == baseline.date.month)
        #expect(result.date.day == baseline.date.day)
        #expect(result.hour == baseline.hour)
        #expect(result.minute == baseline.minute)
        #expect(result.durationMinutes == baseline.durationMinutes)
        #expect(result.attendeeQuery == baseline.attendeeQuery)
        #expect(result.location == baseline.location)
        #expect(result.notes == baseline.notes)
        #expect(result.reminderMinutesBefore == baseline.reminderMinutesBefore)
    }

    @Test(arguments: [ClockCompletion(clockPhrase: "18:30", hasExplicitStartTime: false, hour: 18, minute: 30), ClockCompletion(clockPhrase: nil, hasExplicitStartTime: true, hour: nil, minute: nil)])
    func initialMissingClockStaysPendingWhenExtractionIsNotExplicit(_ clock: ClockCompletion) async throws {
        let fake = LifecycleTests.ControlledGenerator(); let writer = LifecycleTests.WriterSpy()
        fake.automaticClock = clock
        let model = PlannerViewModel(service: fake, writer: writer, availability: .available)
        model.input = "下週五晚上吃飯"
        model.generate(); let task = try #require(model.task)
        try await eventually { fake.requests.count == 1 }
        let initial = pending()
        fake.requests[0].resume(returning: .initial(initial))
        await task.value
        #expect(fake.clockNotes == [model.input])
        #expect(model.event == nil)
        #expect(model.draft?.hour == nil)
        #expect(model.draft?.minute == 0)
        #expect(model.draft?.date.year == initial.date.year)
        #expect(model.draft?.date.month == initial.date.month)
        #expect(model.draft?.date.day == initial.date.day)
        #expect(model.draft?.title == initial.title)
        #expect(model.draft?.durationMinutes == initial.durationMinutes)
        #expect(model.draft?.location == initial.location)
        #expect(model.draft?.notes == initial.notes)
        #expect(model.draft?.reminderMinutesBefore == initial.reminderMinutesBefore)
        #expect(fake.reviewedContexts.isEmpty)
        #expect(!model.canSave)
        #expect(writer.calls == 0)
    }

    @Test func nonExplicitClockCannotApplyHallucinatedHour() throws {
        var baseline = pending(); baseline.hour = 14; baseline.minute = 45; baseline.attendeeQuery = "Amy"
        let result = try ClockCompletion(clockPhrase: "18:30", hasExplicitStartTime: false, hour: 18, minute: 30)
            .applying(to: baseline, now: .now, timeZone: zone)
        #expect(result.title == baseline.title)
        #expect(result.date.kind == baseline.date.kind)
        #expect(result.date.dayOffset == baseline.date.dayOffset)
        #expect(result.date.weekday == baseline.date.weekday)
        #expect(result.date.year == baseline.date.year)
        #expect(result.date.month == baseline.date.month)
        #expect(result.date.day == baseline.date.day)
        #expect(result.hour == baseline.hour)
        #expect(result.minute == baseline.minute)
        #expect(result.durationMinutes == baseline.durationMinutes)
        #expect(result.attendeeQuery == baseline.attendeeQuery)
        #expect(result.location == baseline.location)
        #expect(result.notes == baseline.notes)
        #expect(result.reminderMinutesBefore == baseline.reminderMinutesBefore)
    }

    @Test(arguments: [nil, "", "   ", "凌晨四點"] as [String?])
    func ungroundedClockPhrasesAreRejected(_ phrase: String?) {
        let output = ClockCompletion(clockPhrase: phrase, hasExplicitStartTime: true, hour: 18, minute: 30)
            .grounded(in: "明天晚上聚餐一小時，提前兩小時提醒")
        #expect(!output.hasExplicitStartTime)
        #expect(output.clockPhrase == nil)
        #expect(output.hour == nil)
        #expect(output.minute == nil)
    }

    @Test(arguments: [("下午兩點", 14, nil), ("14:45", 14, 45)] as [(String, Int, Int?)])
    func sourceClockInMixedNotePreservesDraft(_ phrase: String, _ hour: Int, _ minute: Int?) throws {
        let note = "週五\(phrase)討論，持續半小時，提前兩小時提醒"
        let clock = ClockCompletion(clockPhrase: phrase, hasExplicitStartTime: true, hour: hour, minute: minute)
            .grounded(in: note)
        #expect(clock.clockPhrase == phrase)
        #expect(clock.hasExplicitStartTime)
        var baseline = pending(); baseline.minute = 45; baseline.attendeeQuery = "Amy"
        let output = try clock.applying(to: baseline, now: .now, timeZone: zone)
        #expect(output.hour == hour)
        #expect(output.minute == (minute ?? 0))
        #expect(output.date.kind == baseline.date.kind)
        #expect(output.date.year == baseline.date.year)
        #expect(output.date.month == baseline.date.month)
        #expect(output.date.day == baseline.date.day)
        #expect(output.title == baseline.title)
        #expect(output.durationMinutes == baseline.durationMinutes)
        #expect(output.attendeeQuery == baseline.attendeeQuery)
        #expect(output.location == baseline.location)
        #expect(output.notes == baseline.notes)
        #expect(output.reminderMinutesBefore == baseline.reminderMinutesBefore)
    }

    @Test func sourceSubstringDoesNotOverrideNonExplicitClassification() throws {
        let output = ClockCompletion(clockPhrase: "晚上", hasExplicitStartTime: false, hour: 18, minute: 30)
            .grounded(in: "晚上聚餐")
        #expect(output.clockPhrase == nil)
        #expect(!output.hasExplicitStartTime)
        #expect(output.hour == nil)
        #expect(output.minute == nil)
        let draft = try output.applying(to: pending(), now: .now, timeZone: zone)
        #expect(draft.hour == nil)
        #expect(draft.date.day == 30)
    }

    @Test func missingPhraseCannotPublishNumericClock() throws {
        let output = try ClockCompletion(clockPhrase: nil, hasExplicitStartTime: true, hour: 18, minute: 30)
            .applying(to: pending(), now: .now, timeZone: zone)
        #expect(output.hour == nil)
        #expect(output.minute == 0)
        #expect(output.date.day == 30)
    }

}
