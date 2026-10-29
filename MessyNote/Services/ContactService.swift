import Contacts

@MainActor
protocol ContactSearching: Sendable {
    func candidates(matching query: String) async throws -> [ContactCandidate]
}

@MainActor
final class ContactService: ContactSearching {
    private let store = CNContactStore()
    func candidates(matching query: String) async throws -> [ContactCandidate] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
            guard try await store.requestAccess(for: .contacts) else { throw PlannerError.denied("聯絡人") }
        }
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized || status == .limited else { throw PlannerError.denied("聯絡人") }
        try Task.checkCancellation()
        let keys = [CNContactIdentifierKey, CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey] as [CNKeyDescriptor]
        let contacts = try store.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: query), keysToFetch: keys)
        return contacts.prefix(20).map {
            let name = [$0.familyName, $0.givenName].filter { !$0.isEmpty }.joined(separator: " ")
            return ContactCandidate(id: $0.identifier, displayName: name.isEmpty ? $0.nickname : name)
        }
    }
}
