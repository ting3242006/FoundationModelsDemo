import Foundation

struct ActivityEvent: Identifiable, Equatable {
    let id = UUID()
    let message: String
}
