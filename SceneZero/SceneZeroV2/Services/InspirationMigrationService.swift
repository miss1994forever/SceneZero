import SwiftData

@MainActor
struct InspirationMigrationService {
    func migrateLegacyImages(in context: ModelContext) throws {
        let entries = try context.fetch(FetchDescriptor<LookbookEntry>())
        var didChange = false

        for entry in entries where entry.assets.isEmpty && !entry.imagePath.isEmpty {
            let asset = InspirationAsset(
                kind: .image,
                relativePath: entry.imagePath,
                title: entry.title,
                isLegacyReference: true,
                entry: entry
            )
            context.insert(asset)
            entry.assets.append(asset)
            didChange = true
        }

        if didChange {
            try context.save()
        }
    }
}
