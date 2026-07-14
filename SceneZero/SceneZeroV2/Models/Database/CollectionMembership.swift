import Foundation
import SwiftData

@Model
final class CollectionMembership {
    @Attribute(.unique) var id: UUID
    var addedAt: Date
    var sortIndex: Int
    var note: String
    var inspiration: Inspiration?
    var collection: InspirationCollection?

    init(id: UUID = UUID(), inspiration: Inspiration? = nil, collection: InspirationCollection? = nil, addedAt: Date = .now, sortIndex: Int = 0) {
        self.id = id
        self.addedAt = addedAt
        self.sortIndex = sortIndex
        self.note = ""
        self.inspiration = inspiration
        self.collection = collection
    }
}
