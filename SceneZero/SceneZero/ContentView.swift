import SwiftUI

struct ContentView: View {
    var body: some View {
        RootTabView()
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [LookbookEntry.self, InspirationAsset.self, LookbookBoard.self, SceneProject.self],
            inMemory: true
        )
}
