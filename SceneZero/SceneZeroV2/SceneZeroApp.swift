//
//  SceneZeroApp.swift
//  SceneZero
//
//  Created by haojun on 2026/6/8.
//

import SwiftUI
import SwiftData

@main
struct SceneZeroV2App: App {
    private let modelContainer: ModelContainer = {
        do {
            let schema = Schema(versionedSchema: SceneZeroSchemaV1.self)
            let storeDirectory = URL.applicationSupportDirectory.appending(path: "SceneZeroV2")
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(
                url: storeDirectory.appending(path: "SceneZeroV2-V1.store"),
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: SceneZeroMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Unable to create SceneZero V2 database: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
