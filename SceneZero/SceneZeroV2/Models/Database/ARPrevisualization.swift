import Foundation
import SwiftData

@Model
final class ARPrevisualization {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var layoutData: Data
    var frameAspectRatio: String
    var lensPreset: String
    var showsCompositionGuides: Bool
    var inspiration: Inspiration?

    init(id: UUID = UUID(), layoutData: Data = Data(), frameAspectRatio: String = FrameAspectRatio.cinema239.rawValue, lensPreset: String = LensPreset.standard35.rawValue, showsCompositionGuides: Bool = true, inspiration: Inspiration? = nil) {
        self.id = id
        self.createdAt = .now
        self.updatedAt = .now
        self.layoutData = layoutData
        self.frameAspectRatio = frameAspectRatio
        self.lensPreset = lensPreset
        self.showsCompositionGuides = showsCompositionGuides
        self.inspiration = inspiration
    }
}
