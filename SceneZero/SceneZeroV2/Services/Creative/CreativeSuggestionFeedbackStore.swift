import Foundation

/// Compact local-only feedback. It records rule outcomes, never an image or snapshot.
@MainActor
struct CreativeSuggestionFeedbackStore {
    private static let storageKey = "creativeSuggestionFeedback.v1"
    private static let maximumEntries = 100

    enum Outcome: String, Codable {
        case applied
        case swapped
        case ignored
    }

    private struct Entry: Codable {
        let ruleID: String
        let outcome: Outcome
        let recordedAt: Date
    }

    func record(ruleID: String, outcome: Outcome) {
        let decoder = JSONDecoder()
        let existing = UserDefaults.standard.data(forKey: Self.storageKey)
            .flatMap { try? decoder.decode([Entry].self, from: $0) } ?? []
        let updated = Array((existing + [Entry(ruleID: ruleID, outcome: outcome, recordedAt: .now)]).suffix(Self.maximumEntries))
        UserDefaults.standard.set(try? JSONEncoder().encode(updated), forKey: Self.storageKey)
    }
}
