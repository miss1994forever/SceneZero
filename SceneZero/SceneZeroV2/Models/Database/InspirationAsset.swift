import Foundation
import SwiftData

enum AssetStorageState: String, Codable {
    case local
    case externalReference
    case missing
    case pendingDeletion
}

@Model
final class InspirationAsset {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var storageStateRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var sortIndex: Int
    var textContent: String
    var relativePath: String?
    var thumbnailPath: String?
    var externalURLString: String?
    var originalFilename: String?
    var contentType: String?
    var checksum: String?
    var byteCount: Int64
    var title: String
    var subtitle: String
    var duration: Double
    var pixelWidth: Double
    var pixelHeight: Double
    var isLegacyReference: Bool
    var inspiration: Inspiration?

    init(
        id: UUID = UUID(),
        kind: InspirationAssetKind,
        createdAt: Date = .now,
        sortIndex: Int = 0,
        textContent: String = "",
        relativePath: String? = nil,
        thumbnailPath: String? = nil,
        externalURLString: String? = nil,
        title: String = "",
        subtitle: String = "",
        duration: Double = 0,
        pixelWidth: Double = 0,
        pixelHeight: Double = 0,
        isLegacyReference: Bool = false,
        entry: Inspiration? = nil
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.storageStateRawValue = externalURLString == nil ? AssetStorageState.local.rawValue : AssetStorageState.externalReference.rawValue
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.sortIndex = sortIndex
        self.textContent = textContent
        self.relativePath = relativePath
        self.thumbnailPath = thumbnailPath
        self.externalURLString = externalURLString
        self.originalFilename = nil
        self.contentType = nil
        self.checksum = nil
        self.byteCount = 0
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.isLegacyReference = isLegacyReference
        self.inspiration = entry
    }

    var kind: InspirationAssetKind {
        get { InspirationAssetKind(rawValue: kindRawValue) ?? .image }
        set { kindRawValue = newValue.rawValue }
    }

    var storageState: AssetStorageState {
        get { AssetStorageState(rawValue: storageStateRawValue) ?? .missing }
        set { storageStateRawValue = newValue.rawValue }
    }

    var entry: Inspiration? {
        get { inspiration }
        set { inspiration = newValue }
    }

    var externalURL: URL? {
        externalURLString.flatMap(URL.init(string:))
    }
}
