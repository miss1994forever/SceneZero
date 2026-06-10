import SwiftUI

struct LightingOverlayView: View {
    let lightPreset: LightPreset
    let colorTemperature: ColorTemperature
    let intensity: Double
    let radius: Double
    let isVisible: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [
                        overlayColor.opacity(isVisible ? 0.24 * intensity : 0),
                        overlayColor.opacity(isVisible ? 0.07 * intensity : 0),
                        .clear
                    ],
                    startPoint: lightPreset.overlayStartPoint,
                    endPoint: lightPreset.overlayEndPoint
                )

                RadialGradient(
                    colors: [
                        overlayColor.opacity(isVisible ? 0.36 * intensity : 0),
                        overlayColor.opacity(isVisible ? 0.12 * intensity : 0),
                        .clear
                    ],
                    center: lightPreset.overlayStartPoint,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * (0.28 + radius * 0.42)
                )
            }
            .blendMode(.screen)
            .animation(.smooth(duration: 0.22), value: lightPreset)
            .animation(.smooth(duration: 0.22), value: colorTemperature)
            .animation(.smooth(duration: 0.18), value: intensity)
            .animation(.smooth(duration: 0.18), value: radius)
            .animation(.smooth(duration: 0.18), value: isVisible)
        }
    }

    private var overlayColor: Color {
        Color(uiColor: colorTemperature.uiColor)
    }
}

#Preview {
    LightingOverlayView(
        lightPreset: .keyLeft,
        colorTemperature: .warm3200,
        intensity: 0.75,
        radius: 0.6,
        isVisible: true
    )
    .background(Color.black)
}
