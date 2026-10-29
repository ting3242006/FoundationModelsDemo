import Foundation
import Observation

@MainActor @Observable
final class SaveCoordinator {
    private let writer: any CalendarWriting
    private(set) var review: SaveReview?
    private(set) var isSaving = false
    private(set) var saved = false
    init(writer: any CalendarWriting) { self.writer = writer }
    func prepare(event: ReviewedEvent, contact: ContactCandidate?) {
        guard !isSaving, !saved else { return }
        review = SaveReview(event: event, contact: contact)
    }
    func invalidate() { review = nil; saved = false }
    func confirm(_ snapshot: SaveReview) async throws -> Bool {
        guard !isSaving, !saved, review == snapshot else { throw PlannerError.staleReview }
        try snapshot.event.validate()
        isSaving = true
        defer { isSaving = false }
        try await writer.authorize()
        try Task.checkCancellation()
        guard review == snapshot else { throw PlannerError.staleReview }
        // No suspension between the final validity check and the side effect.
        _ = try writer.save(snapshot.event, contact: snapshot.contact)
        saved = true
        review = nil
        return true
    }
}
