import SwiftUI

enum SceneZeroMode: String, CaseIterable, Identifiable {
    case capture
    case inspiration

    var id: Self { self }

    var title: String {
        switch self {
        case .capture: "取景"
        case .inspiration: "灵感"
        }
    }
}

enum SceneZeroModeSwitcherSurface {
    case camera
    case library
}

struct SceneZeroModeSwitcher: View {
    @Binding var selection: SceneZeroMode
    let surface: SceneZeroModeSwitcherSurface

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SceneZeroMode.allCases) { mode in
                Button(mode.title) {
                    selection = mode
                }
                .font(.subheadline.bold())
                .foregroundStyle(selection == mode ? SceneZeroTheme.accent : secondaryLabelStyle)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background {
                    if selection == mode {
                        Capsule()
                            .fill(SceneZeroTheme.accent.opacity(surface == .camera ? 0.20 : 0.14))
                    }
                }
                .contentShape(Capsule())
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .padding(2)
        .frame(width: 142, height: 40)
        .background(switcherBackground, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(borderStyle, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("创作模式")
    }

    private var switcherBackground: some ShapeStyle {
        switch surface {
        case .camera:
            return AnyShapeStyle(.ultraThinMaterial)
        case .library:
            return AnyShapeStyle(SceneZeroTheme.secondaryBackground)
        }
    }

    private var secondaryLabelStyle: Color {
        surface == .camera ? .white.opacity(0.82) : .secondary
    }

    private var borderStyle: Color {
        surface == .camera ? .white.opacity(0.22) : .primary.opacity(0.08)
    }
}

#Preview("Camera") {
    ZStack {
        Color.black.ignoresSafeArea()
        SceneZeroModeSwitcher(selection: .constant(.capture), surface: .camera)
    }
}

#Preview("Library") {
    SceneZeroModeSwitcher(selection: .constant(.inspiration), surface: .library)
        .padding()
}
