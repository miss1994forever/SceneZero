import Foundation

extension LookbookEntry {
    var orderedAssets: [InspirationAsset] {
        assets.sorted {
            if $0.sortIndex == $1.sortIndex {
                $0.createdAt < $1.createdAt
            } else {
                $0.sortIndex < $1.sortIndex
            }
        }
    }

    var primaryAsset: InspirationAsset? {
        orderedAssets.first
    }

    var inspirationKind: InspirationAssetKind {
        primaryAsset?.kind ?? (imagePath.isEmpty ? .text : .image)
    }
}
