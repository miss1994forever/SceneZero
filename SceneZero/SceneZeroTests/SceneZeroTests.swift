//
//  SceneZeroTests.swift
//  SceneZeroTests
//
//  Created by haojun on 2026/6/8.
//

import Testing
import SwiftData
@testable import SceneZero

struct SceneZeroTests {

    @Test @MainActor
    func legacyImageMigrationIsIdempotent() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LookbookEntry.self,
            InspirationAsset.self,
            LookbookBoard.self,
            SceneProject.self,
            configurations: configuration
        )
        let context = container.mainContext
        let entry = LookbookEntry(
            title: "旧图片灵感",
            imagePath: "LookbookImages/legacy.png",
            prompt: "",
            shotType: ShotType.wide.rawValue,
            lightPreset: "未标注",
            colorTemperature: "未标注",
            filterName: FilterPreset.realistic.rawValue,
            layoutJSON: "[]"
        )
        context.insert(entry)
        try context.save()

        let migration = InspirationMigrationService()
        try migration.migrateLegacyImages(in: context)
        try migration.migrateLegacyImages(in: context)

        #expect(entry.assets.count == 1)
        #expect(entry.assets.first?.kind == .image)
        #expect(entry.assets.first?.relativePath == entry.imagePath)
        #expect(entry.assets.first?.isLegacyReference == true)
    }

}
