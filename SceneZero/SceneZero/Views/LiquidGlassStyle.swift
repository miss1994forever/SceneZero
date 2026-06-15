import SwiftUI

private struct LiquidGlassCapsuleModifier: ViewModifier {
    let material: Material
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(material, in: Capsule())
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
    let cornerRadius: CGFloat
    let material: Material

    func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background {
                Circle()
                    .fill(isSelected ? .white.opacity(0.88) : .black.opacity(0.30))
                    .background(.ultraThinMaterial, in: Circle())
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
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isSelected ? .black : .white)
            .background {
                Capsule()
                    .fill(isSelected ? .white.opacity(0.90) : .white.opacity(0.14))
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .overlay {
                Capsule()
                    .stroke(.white.opacity(isSelected ? 0.64 : 0.22), lineWidth: 1)
            }
    }
}

extension View {
    func liquidGlassCapsule(
        material: Material = .ultraThinMaterial,
        shadowOpacity: Double = 0.18
    ) -> some View {
        modifier(LiquidGlassCapsuleModifier(material: material, shadowOpacity: shadowOpacity))
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
}
