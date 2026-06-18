import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: SceneZeroTab = .capture

    var body: some View {
        TabView(selection: $selectedTab) {
            MainView()
                .tabItem {
                    Label("Capture", systemImage: "camera.viewfinder")
                }
                .tag(SceneZeroTab.capture)

            LookbookView()
                .tabItem {
                    Label("Lookbook", systemImage: "rectangle.stack")
                }
                .tag(SceneZeroTab.lookbook)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(SceneZeroTab.profile)
        }
    }
}

private enum SceneZeroTab: Hashable {
    case capture
    case lookbook
    case profile
}

#Preview {
    RootTabView()
        .modelContainer(for: [LookbookEntry.self, LookbookBoard.self], inMemory: true)
}
