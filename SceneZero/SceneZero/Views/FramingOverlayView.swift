import SwiftUI

struct FramingOverlayView: View {
    let aspectRatio: FrameAspectRatio
    let shotType: ShotType
    let lensPreset: LensPreset
    let showsGuides: Bool
    let contentInsets: FramingSafeInsets

    var body: some View {
        GeometryReader { proxy in
            let rect = frameRect(in: proxy.size)

            ZStack {
                maskPath(size: proxy.size, rect: rect)
                    .fill(Color.black.opacity(0.42), style: FillStyle(eoFill: true))

                Path { path in
                    path.addRect(rect)
                }
                .stroke(.white.opacity(0.88), lineWidth: 1.2)

                if showsGuides {
                    guideLines(in: rect)
                        .stroke(.white.opacity(0.45), lineWidth: 0.8)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(aspectRatio.rawValue)  \(lensPreset.rawValue)  \(shotType.rawValue)")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .liquidGlassCapsule(shadowOpacity: 0.12)
                            .padding(.trailing, max(16, contentInsets.trailing + 12))
                            .padding(.bottom, max(20, proxy.safeAreaInsets.bottom + 8))
                    }
                }
            }
        }
    }

    private func frameRect(in size: CGSize) -> CGRect {
        FramingGeometry.frameRect(
            in: CGRect(origin: .zero, size: size),
            aspectRatio: aspectRatio,
            shotType: shotType,
            contentInsets: contentInsets
        )
    }

    private func maskPath(size: CGSize, rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(origin: .zero, size: size))
        path.addRect(rect)
        return path
    }

    private func guideLines(in rect: CGRect) -> Path {
        var path = Path()

        let thirdWidth = rect.width / 3
        let thirdHeight = rect.height / 3
        for index in 1...2 {
            let x = rect.minX + thirdWidth * CGFloat(index)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))

            let y = rect.minY + thirdHeight * CGFloat(index)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: CGPoint(x: center.x - 14, y: center.y))
        path.addLine(to: CGPoint(x: center.x + 14, y: center.y))
        path.move(to: CGPoint(x: center.x, y: center.y - 14))
        path.addLine(to: CGPoint(x: center.x, y: center.y + 14))

        let safeRect = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06)
        path.addRect(safeRect)
        return path
    }
}

#Preview {
    FramingOverlayView(
        aspectRatio: .cinema239,
        shotType: .closeUp,
        lensPreset: .standard35,
        showsGuides: true,
        contentInsets: .zero
    )
    .background(Color.gray)
}
