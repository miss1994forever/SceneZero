import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: SceneZeroTab = .capture

    var body: some View {
        Group {
            switch selectedTab {
            case .capture:
                MainView()
            case .lookbook:
                LookbookView()
            case .profile:
                ProfileView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomTabBar
        }
        .animation(.snappy(duration: 0.22), value: selectedTab)
    }

    private var bottomTabBar: some View {
        HStack(spacing: 8) {
            ForEach(SceneZeroTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: selectedTab == tab ? tab.selectedSystemImage : tab.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(height: 22)
                        Text(tab.title)
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(selectedTab == tab ? SceneZeroTheme.accent : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(SceneZeroTheme.accentSoft.opacity(0.84))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityValue(selectedTab == tab ? "已选中" : "")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SceneZeroTheme.separator.opacity(0.24))
                .frame(height: 0.5)
        }
    }
}

private enum SceneZeroTab: Hashable, CaseIterable, Identifiable {
    case capture
    case lookbook
    case profile

    var id: Self { self }

    var title: String {
        switch self {
        case .capture: "取景"
        case .lookbook: "灵感库"
        case .profile: "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .capture: "viewfinder"
        case .lookbook: "rectangle.stack"
        case .profile: "person.crop.circle"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .capture: "viewfinder.circle.fill"
        case .lookbook: "rectangle.stack.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [LookbookEntry.self, LookbookBoard.self], inMemory: true)
}
