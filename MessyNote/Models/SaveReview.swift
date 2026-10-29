import Foundation

struct SaveReview: Identifiable, Equatable {
    let id = UUID()
    let event: ReviewedEvent
    let contact: ContactCandidate?
}
