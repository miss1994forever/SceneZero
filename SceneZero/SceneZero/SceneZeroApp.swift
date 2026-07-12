//
//  SceneZeroApp.swift
//  SceneZero
//
//  Created by haojun on 2026/6/8.
//

import SwiftUI
import SwiftData

@main
struct SceneZeroApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            LookbookEntry.self,
            InspirationAsset.self,
            LookbookBoard.self,
            SceneProject.self
        ])
    }
}
