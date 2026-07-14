import SwiftUI

enum PhoneCaptureControlPlacement {
    case bottom
    case trailing
}

/// The only persistent capture controls on iPhone. Secondary choices remain
/// in sheets so the live camera canvas stays visually dominant.
struct PhoneCaptureControlDock: View {
    let placement: PhoneCaptureControlPlacement
    let safeAreaInset: CGFloat
    let selectedTool: SceneTool
    let isCapturing: Bool
    let openToolPicker: () -> Void
    let openAdjustments: () -> Void
    let capture: () -> Void

    var body: some View {
        Group {
            switch placement {
            case .bottom:
                bottomControls
            case .trailing:
                trailingControls
            }
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.58))
        }
        .accessibilityElement(children: .contain)
    }

    private var bottomControls: some View {
        HStack(spacing: 0) {
            toolButton

            Spacer(minLength: 24)

            ShutterButton(isCapturing: isCapturing, size: 72, action: capture)

            Spacer(minLength: 24)

            adjustmentButton
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, max(12, safeAreaInset))
        .frame(maxWidth: .infinity)
    }

    private var trailingControls: some View {
        VStack(spacing: 0) {
            toolButton

            Spacer(minLength: 20)

            ShutterButton(isCapturing: isCapturing, size: 64, action: capture)

            Spacer(minLength: 20)

            adjustmentButton
        }
        .padding(.leading, 10)
        .padding(.trailing, max(10, safeAreaInset))
        .padding(.vertical, 20)
        .frame(maxHeight: .infinity)
    }

    private var toolButton: some View {
        Button("选择\(selectedTool.displayName)", systemImage: selectedTool.systemImage, action: openToolPicker)
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(SceneZeroTheme.accent.opacity(0.24), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(SceneZeroTheme.accent.opacity(0.72), lineWidth: 1)
            }
    }

    private var adjustmentButton: some View {
        Button("调整\(selectedTool.displayName)", systemImage: "slider.horizontal.3", action: openAdjustments)
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(.white.opacity(0.12), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
            }
    }
}
