import Foundation
import Testing
@testable import MessyNote

@MainActor
struct InitialDurationTests {
    @Test func initialExplicitDurationCorrectsThirtyMinutesAndKeepsOtherFields() async throws {
        let helper = LifecycleTests(); let fake = LifecycleTests.ControlledGenerator()
        let writer = LifecycleTests.WriterSpy()
        fake.automaticDuration = DurationCompletion(durationMinutes: 30)
        let model = PlannerViewModel(service: fake, writer: writer, availability: .available)
        model.input = "明天下午四點跟Amy開會半小時，兩小時前提醒我"
        model.generate(); let task = try #require(model.task)
        try await helper.eventually { fake.requests.count == 1 }
        var initial = helper.draft(); initial.hour = 16; initial.attendeeQuery = "Amy"; initial.reminderMinutesBefore = 120
        fake.requests[0].resume(returning: .initial(initial))
        await task.value
        let event = try #require(model.event)
        #expect(fake.durationNotes == [model.input])
        #expect(event.durationMinutes == 30)
        #expect(event.title == initial.title)
        #expect(event.start == (try DateResolver.resolve(initial.date, hour: 16, minute: 0, now: .now, timeZone: .current)))
        #expect(event.attendeeQuery == "Amy")
        #expect(event.location == initial.location)
        #expect(event.notes == initial.notes)
        #expect(event.reminderMinutesBefore == 120)
        #expect(fake.clockNotes.isEmpty)
        #expect(fake.reviewedContexts.count == 1)
        #expect(writer.calls == 0)
    }

    @Test func absentDurationPreservesInitialDefault() async throws {
        let helper = LifecycleTests(); let fake = LifecycleTests.ControlledGenerator()
        let model = PlannerViewModel(service: fake, writer: LifecycleTests.WriterSpy(), availability: .available)
        model.input = "明天下午四點開會，提前兩小時提醒"
        model.generate(); let task = try #require(model.task)
        try await helper.eventually { fake.requests.count == 1 }
        let initial = helper.draft()
        fake.requests[0].resume(returning: .initial(initial))
        await task.value
        #expect(fake.durationNotes == [model.input])
        #expect(model.event?.durationMinutes == 60)
        #expect(fake.reviewedContexts.count == 1)
    }

    @Test(arguments: [0, 481])
    func invalidInitialDurationPreventsReviewAndSave(_ minutes: Int) async throws {
        let helper = LifecycleTests(); let fake = LifecycleTests.ControlledGenerator()
        let writer = LifecycleTests.WriterSpy()
        fake.automaticDuration = DurationCompletion(durationMinutes: minutes)
        let model = PlannerViewModel(service: fake, writer: writer, availability: .available)
        model.generate(); let task = try #require(model.task)
        try await helper.eventually { fake.requests.count == 1 }
        fake.requests[0].resume(returning: .initial(helper.draft()))
        await task.value
        #expect(model.event == nil)
        #expect(model.draft?.durationMinutes == 60)
        #expect(model.error != nil)
        #expect(fake.reviewedContexts.isEmpty)
        #expect(!model.canSave)
        #expect(writer.calls == 0)
    }

    @Test func revisionNeverRequestsDurationExtraction() async throws {
        let helper = LifecycleTests(); let fake = LifecycleTests.ControlledGenerator()
        fake.automaticDuration = DurationCompletion(durationMinutes: 30)
        let model = PlannerViewModel(service: fake, writer: LifecycleTests.WriterSpy(), availability: .available)
        let initial = try helper.reviewed()
        model.event = initial
        model.input = "改成16:30"
        model.generate(); let task = try #require(model.task)
        try await helper.eventually { fake.requests.count == 1 }
        var values = initial.asDraft(); values.hour = 16; values.minute = 30
        fake.requests[0].resume(returning: .revision(EventRevision(changes: [.time], values: values)))
        await task.value
        #expect(fake.durationNotes.isEmpty)
        #expect(model.event?.durationMinutes == initial.durationMinutes)
        #expect(fake.reviewedContexts.count == 1)
    }

    @Test func canceledDurationCannotOverwriteNewGeneration() async throws {
        let helper = LifecycleTests(); let fake = LifecycleTests.ControlledGenerator()
        let writer = LifecycleTests.WriterSpy()
        fake.pauseDuration = true
        let model = PlannerViewModel(service: fake, writer: writer, availability: .available)
        model.generate(); let old = try #require(model.task)
        try await helper.eventually { fake.requests.count == 1 }
        fake.requests[0].resume(returning: .initial(helper.draft("Old")))
        try await helper.eventually { fake.durationRequests.count == 1 }
        model.reset()
        fake.pauseDuration = false
        fake.automaticDuration = DurationCompletion(durationMinutes: 45)
        model.input = "明天下午四點開會四十五分鐘"
        model.generate(); let current = try #require(model.task)
        try await helper.eventually { fake.requests.count == 2 }
        fake.requests[1].resume(returning: .initial(helper.draft("New")))
        await current.value
        fake.durationRequests[0].resume(returning: DurationCompletion(durationMinutes: 30))
        await old.value
        #expect(model.event?.title == "New")
        #expect(model.event?.durationMinutes == 45)
        #expect(fake.reviewedContexts.count == 1)
        #expect(writer.calls == 0)
    }
}
