import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: SceneZeroTab = .inspiration

    var body: some View {
        TabView(selection: $selectedTab) {
            LookbookView()
                .tabItem {
                    Label(
                        SceneZeroTab.inspiration.title,
                        systemImage: selectedTab == .inspiration
                            ? SceneZeroTab.inspiration.selectedSystemImage
                            : SceneZeroTab.inspiration.systemImage
                    )
                }
                .tag(SceneZeroTab.inspiration)

            MainView()
                .tabItem {
                    Label(
                        SceneZeroTab.capture.title,
                        systemImage: selectedTab == .capture
                            ? SceneZeroTab.capture.selectedSystemImage
                            : SceneZeroTab.capture.systemImage
                    )
                }
                .tag(SceneZeroTab.capture)
        }
        .tint(SceneZeroTheme.accent)
    }
}

private enum SceneZeroTab: Hashable {
    case inspiration
    case capture

    var title: String {
        switch self {
        case .inspiration: "灵感"
        case .capture: "取景"
        }
    }

    var systemImage: String {
        switch self {
        case .inspiration: "rectangle.stack"
        case .capture: "viewfinder"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .inspiration: "rectangle.stack.fill"
        case .capture: "viewfinder.circle.fill"
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(
            for: [LookbookEntry.self, InspirationAsset.self, LookbookBoard.self, SceneProject.self],
            inMemory: true
        )
}
