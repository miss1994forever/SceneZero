import SwiftData

@MainActor
struct InspirationFileMaintenanceService {
    private let imageStorage = ImageStorageService()
    private let mediaStorage = InspirationMediaStorageService()

    func removeOrphanedFiles(in context: ModelContext) throws {
        let entries = try context.fetch(FetchDescriptor<LookbookEntry>())
        let assets = try context.fetch(FetchDescriptor<InspirationAsset>())

        var imagePaths = Set(entries.map(\.imagePath).filter { !$0.isEmpty })
        var mediaPaths = Set<String>()

        for asset in assets {
            switch asset.kind {
            case .image:
                if let path = asset.relativePath {
                    imagePaths.insert(path)
                }
            case .audio, .video, .music:
                if let path = asset.relativePath {
                    mediaPaths.insert(path)
                }
                if let thumbnailPath = asset.thumbnailPath {
                    imagePaths.insert(thumbnailPath)
                }
            case .text:
                break
            }
        }

        try imageStorage.deleteOrphans(keeping: imagePaths)
        try mediaStorage.deleteOrphans(keeping: mediaPaths)
    }
}
