import SwiftData

/// First frozen database baseline for SceneZeroV2.
/// Product iterations and Codable blob versions do not change this SwiftData schema.
enum SceneZeroSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = [
        Inspiration.self,
        InspirationAsset.self,
        InspirationCollection.self,
        CollectionMembership.self,
        Tag.self,
        ARPrevisualization.self,
        PromptDocument.self
    ]
}

enum SceneZeroMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [SceneZeroSchemaV1.self]
    static let stages: [MigrationStage] = []
}
