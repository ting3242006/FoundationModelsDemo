import Foundation
import Testing
@testable import MessyNote

@MainActor
struct EditorBindingTests {
    @Test func followUpClearsEventButRetainedEditorBindingRemainsReadable() async throws {
        let helper = LifecycleTests()
        let fake = LifecycleTests.ControlledGenerator()
        let writer = LifecycleTests.WriterSpy()
        let model = PlannerViewModel(service: fake, writer: writer, availability: .available)
        let original = try helper.reviewed()
        model.event = original
        let editor = model.editorBinding(for: original)
        model.input = "改成16:30"
        model.generate()
        let task = try #require(model.task)
        #expect(model.event == nil)
        #expect(model.isLoading)
        // SwiftUI may read a retained editor during the update that removes it.
        #expect(editor.wrappedValue == original)
        var lateEdit = original
        lateEdit.title = "Late editor write"
        editor.wrappedValue = lateEdit
        #expect(model.event == nil)
        #expect(!model.canSave)
        model.prepareSave()
        #expect(model.presentedReview == nil)
        #expect(writer.calls == 0)
        try await helper.eventually { fake.requests.count == 1 }
        model.cancel()
        fake.requests[0].resume(throwing: CancellationError())
        await task.value
        #expect(editor.wrappedValue == original)
        #expect(model.event == nil)
    }

    @Test func oldEditorCannotOverwriteAReplacementGeneration() throws {
        let helper = LifecycleTests()
        let writer = LifecycleTests.WriterSpy()
        let model = PlannerViewModel(service: LifecycleTests.ControlledGenerator(), writer: writer, availability: .available)
        let original = try helper.reviewed()
        model.event = original
        let oldEditor = model.editorBinding(for: original)
        model.reset()
        var replacement = original
        replacement.title = "New generation"
        model.event = replacement
        var stale = original
        stale.title = "Stale write"
        oldEditor.wrappedValue = stale
        #expect(model.event == replacement)
        #expect(oldEditor.wrappedValue == original)
        #expect(writer.calls == 0)
    }

    @Test func currentEditorWritesInvalidatePreparedSave() throws {
        let helper = LifecycleTests()
        let writer = LifecycleTests.WriterSpy()
        let model = PlannerViewModel(service: LifecycleTests.ControlledGenerator(), writer: writer, availability: .available)
        let original = try helper.reviewed()
        model.event = original
        model.proceedUnresolved = true
        model.prepareSave()
        #expect(model.presentedReview != nil)
        let editor = model.editorBinding(for: original)
        var edited = original
        edited.title = "Human edit"
        editor.wrappedValue = edited
        #expect(model.event == edited)
        #expect(editor.wrappedValue == edited)
        #expect(model.presentedReview == nil)
        #expect(model.saver.review == nil)
        #expect(writer.calls == 0)
    }
}
