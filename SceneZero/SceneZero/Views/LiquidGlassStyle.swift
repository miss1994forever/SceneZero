import SwiftUI

private struct LiquidGlassCapsuleModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let material: Material
    let shadowOpacity: Double
    let tint: Color
    let tintOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(reduceTransparency ? AnyShapeStyle(SceneZeroTheme.cardBackground) : AnyShapeStyle(material), in: Capsule())
            .background {
                Capsule()
                    .fill(tint.opacity(tintOpacity))
            }
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.34),
                                .white.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            }
            .overlay {
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.58),
                                .white.opacity(0.18),
                                .black.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .white.opacity(0.12), radius: 1, x: -0.5, y: -0.5)
            .shadow(color: .black.opacity(shadowOpacity), radius: 18, x: 0, y: 10)
    }
}

private struct LiquidGlassRoundedModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let cornerRadius: CGFloat
    let material: Material

    func body(content: Content) -> some View {
        content
            .background(
                reduceTransparency ? AnyShapeStyle(SceneZeroTheme.cardBackground) : AnyShapeStyle(material),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.30),
                                .white.opacity(0.08),
                                .black.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.56),
                                .white.opacity(0.16),
                                .black.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .white.opacity(0.10), radius: 1, x: -0.5, y: -0.5)
            .shadow(color: .black.opacity(0.20), radius: 20, x: 0, y: 12)
    }
}

private struct LiquidGlassCircleModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background {
                Circle()
                    .fill(isSelected ? .white.opacity(0.88) : .white.opacity(0.18))
                    .background(
                        reduceTransparency ? AnyShapeStyle(SceneZeroTheme.cardBackground) : AnyShapeStyle(.ultraThinMaterial),
                        in: Circle()
                    )
            }
            .overlay {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.62),
                                .white.opacity(0.18),
                                .black.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 7)
    }
}

private struct LiquidGlassChipModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isSelected ? .black : .white)
            .background {
                Capsule()
                    .fill(isSelected ? .white.opacity(0.90) : .white.opacity(0.14))
                    .background(
                        reduceTransparency ? AnyShapeStyle(SceneZeroTheme.cardBackground) : AnyShapeStyle(.ultraThinMaterial),
                        in: Capsule()
                    )
            }
            .overlay {
                Capsule()
                    .stroke(.white.opacity(isSelected ? 0.64 : 0.22), lineWidth: 1)
            }
    }
}

private struct LiquidGlassPanelModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                reduceTransparency ? AnyShapeStyle(SceneZeroTheme.cardBackground) : AnyShapeStyle(.thinMaterial),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.46), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 14)
    }
}

private struct GroupedCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(SceneZeroTheme.cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(SceneZeroTheme.separator.opacity(0.18), lineWidth: 0.5)
            }
    }
}

extension View {
    func liquidGlassCapsule(
        material: Material = .ultraThinMaterial,
        shadowOpacity: Double = 0.18,
        tint: Color = .clear,
        tintOpacity: Double = 0
    ) -> some View {
        modifier(LiquidGlassCapsuleModifier(
            material: material,
            shadowOpacity: shadowOpacity,
            tint: tint,
            tintOpacity: tintOpacity
        ))
    }

    func liquidGlassRounded(
        cornerRadius: CGFloat = 20,
        material: Material = .regularMaterial
    ) -> some View {
        modifier(LiquidGlassRoundedModifier(cornerRadius: cornerRadius, material: material))
    }

    func liquidGlassCircle(isSelected: Bool = false) -> some View {
        modifier(LiquidGlassCircleModifier(isSelected: isSelected))
    }

    func liquidGlassChip(isSelected: Bool = false) -> some View {
        modifier(LiquidGlassChipModifier(isSelected: isSelected))
    }

    func liquidGlassPanel(cornerRadius: CGFloat = 24) -> some View {
        modifier(LiquidGlassPanelModifier(cornerRadius: cornerRadius))
    }

    func groupedCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(GroupedCardModifier(cornerRadius: cornerRadius))
    }
}
