import SwiftUI

struct CaptureTopBar: View {
    @Binding var selectedMode: SceneZeroMode

    let hasCreativeSuggestion: Bool
    let showsCompositionGuides: Bool
    let trailingInset: CGFloat
    let openCreativeSuggestions: () -> Void
    let toggleCompositionGuides: () -> Void
    let openLensSettings: () -> Void
    let resetScene: () -> Void

    var body: some View {
        ZStack {
            SceneZeroModeSwitcher(selection: $selectedMode, surface: .camera)

            HStack(spacing: 8) {
                Spacer(minLength: 0)

                Button("创作建议", systemImage: hasCreativeSuggestion ? "lightbulb.fill" : "lightbulb", action: openCreativeSuggestions)
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if hasCreativeSuggestion {
                            Circle()
                                .fill(SceneZeroTheme.accent)
                                .frame(width: 9, height: 9)
                                .overlay {
                                    Circle().strokeBorder(.black.opacity(0.45), lineWidth: 1)
                                }
                        }
                    }
                    .accessibilityValue(hasCreativeSuggestion ? "有新建议" : "暂无建议")

                Menu("更多取景操作", systemImage: "ellipsis") {
                    Button(
                        showsCompositionGuides ? "隐藏构图辅助线" : "显示构图辅助线",
                        systemImage: showsCompositionGuides ? "grid.circle.fill" : "grid.circle",
                        action: toggleCompositionGuides
                    )
                    Button("镜头设置", systemImage: "camera.aperture", action: openLensSettings)
                    Divider()
                    Button("重置场景", systemImage: "arrow.counterclockwise", role: .destructive, action: resetScene)
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.leading, 12)
        .padding(.trailing, trailingInset)
    }
}
