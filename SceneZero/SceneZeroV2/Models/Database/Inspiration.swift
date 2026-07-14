import Foundation
import SwiftData

@Model
final class Inspiration {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var capturedAt: Date?
    var note: String
    var locationName: String
    var isFavorite: Bool
    var isInTrash: Bool
    var trashedAt: Date?

    // Capture metadata remains available while capture/AR screens move to dedicated records.
    var imagePath: String
    var prompt: String
    var shotType: String
    var lightPreset: String
    var colorTemperature: String
    var lightIntensity: Double
    var lightRadius: Double
    var frameAspectRatio: String
    var lensPreset: String
    var showsCompositionGuides: Bool
    var filterName: String
    var layoutJSON: String

    // Temporary presentation bridge. CollectionMembership is the source of truth for new writes.
    var boardName: String
    var sortIndex: Int
    var tagsText: String

    @Relationship(deleteRule: .cascade, inverse: \InspirationAsset.inspiration)
    var assets: [InspirationAsset]
    @Relationship(deleteRule: .cascade, inverse: \CollectionMembership.inspiration)
    var memberships: [CollectionMembership]
    @Relationship(deleteRule: .cascade, inverse: \ARPrevisualization.inspiration)
    var previsualizations: [ARPrevisualization]
    @Relationship(deleteRule: .cascade, inverse: \PromptDocument.inspiration)
    var promptDocuments: [PromptDocument]
    @Relationship(inverse: \Tag.inspirations)
    var tags: [Tag]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        imagePath: String = "",
        prompt: String = "",
        shotType: String = "",
        lightPreset: String = "",
        colorTemperature: String = "",
        lightIntensity: Double = 0.65,
        lightRadius: Double = 0.55,
        frameAspectRatio: String = FrameAspectRatio.cinema239.rawValue,
        lensPreset: String = LensPreset.standard35.rawValue,
        showsCompositionGuides: Bool = true,
        filterName: String = "",
        layoutJSON: String = "",
        boardName: String = InspirationCollection.defaultBoardName,
        sortIndex: Int = 0,
        isFavorite: Bool = false,
        note: String = "",
        tagsText: String = "",
        locationName: String = "真实现场空间"
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.capturedAt = nil
        self.note = note
        self.locationName = locationName
        self.isFavorite = isFavorite
        self.isInTrash = false
        self.trashedAt = nil
        self.imagePath = imagePath
        self.prompt = prompt
        self.shotType = shotType
        self.lightPreset = lightPreset
        self.colorTemperature = colorTemperature
        self.lightIntensity = lightIntensity
        self.lightRadius = lightRadius
        self.frameAspectRatio = frameAspectRatio
        self.lensPreset = lensPreset
        self.showsCompositionGuides = showsCompositionGuides
        self.filterName = filterName
        self.layoutJSON = layoutJSON
        self.boardName = boardName
        self.sortIndex = sortIndex
        self.tagsText = tagsText
        self.assets = []
        self.memberships = []
        self.previsualizations = []
        self.promptDocuments = []
        self.tags = []
    }
}

typealias LookbookEntry = Inspiration
