import SwiftUI

struct ContentView: View {
    var body: some View {
        RootTabView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [LookbookEntry.self, LookbookBoard.self], inMemory: true)
}
