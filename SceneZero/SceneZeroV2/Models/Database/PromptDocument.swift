import Foundation
import SwiftData

@Model
final class PromptDocument {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var canonicalText: String
    var structuredData: Data?
    var schemaVersion: Int
    var inspiration: Inspiration?

    init(id: UUID = UUID(), title: String = "结构化提示词", canonicalText: String = "", structuredData: Data? = nil, schemaVersion: Int = 1, inspiration: Inspiration? = nil) {
        self.id = id
        self.createdAt = .now
        self.updatedAt = .now
        self.title = title
        self.canonicalText = canonicalText
        self.structuredData = structuredData
        self.schemaVersion = schemaVersion
        self.inspiration = inspiration
    }
}
