import Foundation
import SwiftData

@Model
final class InspirationCollection {
    static let defaultBoardName = "All Captures"
    static let favoritesBoardName = "Favorites"

    @Attribute(.unique) var id: UUID
    var name: String
    var collectionDescription: String
    var createdAt: Date
    var updatedAt: Date
    var sortIndex: Int
    var coverAssetID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \CollectionMembership.collection)
    var memberships: [CollectionMembership]

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, updatedAt: Date = .now, sortIndex: Int = 0) {
        self.id = id
        self.name = name
        self.collectionDescription = ""
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortIndex = sortIndex
        self.coverAssetID = nil
        self.memberships = []
    }

    static func displayName(for name: String) -> String {
        switch name {
        case defaultBoardName: "所有灵感"
        case favoritesBoardName: "收藏"
        default: name
        }
    }
}

typealias LookbookBoard = InspirationCollection
