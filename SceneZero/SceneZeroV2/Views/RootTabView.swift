import SwiftUI

struct RootTabView: View {
    @State private var selectedMode: SceneZeroMode = .capture

    var body: some View {
        Group {
            switch selectedMode {
            case .capture:
                MainView(selectedMode: $selectedMode)
            case .inspiration:
                LookbookView(selectedMode: $selectedMode)
            }
        }
        .tint(SceneZeroTheme.accent)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: SceneZeroSchemaV1.models, inMemory: true)
}
