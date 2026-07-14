import Foundation

/// Deliberately user-authored context. Empty values mean unknown, never inferred facts.
struct CreatorIntent: Codable, Equatable {
    var narrativeIntent: String
    var emotionalIntent: String
    var relationshipIntent: String
    var mustPreserve: [String]
    var avoid: [String]

    init(
        narrativeIntent: String = "",
        emotionalIntent: String = "",
        relationshipIntent: String = "",
        mustPreserve: [String] = [],
        avoid: [String] = []
    ) {
        self.narrativeIntent = narrativeIntent
        self.emotionalIntent = emotionalIntent
        self.relationshipIntent = relationshipIntent
        self.mustPreserve = mustPreserve
        self.avoid = avoid
    }

    init(note: String) {
        self.init(narrativeIntent: note.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
