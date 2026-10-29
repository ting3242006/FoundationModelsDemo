enum ContactResolution: Equatable {
    case none, single(ContactCandidate), multiple([ContactCandidate])
    static func resolve(_ candidates: [ContactCandidate]) -> Self {
        switch candidates.count {
        case 0: .none
        case 1: .single(candidates[0])
        default: .multiple(candidates)
        }
    }
}
