import CoreGraphics
import UIKit

struct LightingOverlayService {
    func applyOverlay(
        to image: UIImage,
        lightPreset: LightPreset,
        colorTemperature: ColorTemperature,
        intensity: Double,
        radius: Double,
        isEnabled: Bool
    ) -> UIImage {
        guard isEnabled else { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            drawLightOverlay(
                in: context.cgContext,
                imageSize: image.size,
                lightPreset: lightPreset,
                color: colorTemperature.uiColor,
                intensity: intensity,
                radius: radius
            )
        }
    }

    private func drawLightOverlay(
        in context: CGContext,
        imageSize: CGSize,
        lightPreset: LightPreset,
        color: UIColor,
        intensity: Double,
        radius: Double
    ) {
        context.saveGState()
        context.setBlendMode(.screen)

        let center = overlayCenter(for: lightPreset, imageSize: imageSize)
        let maxRadius = max(imageSize.width, imageSize.height) * CGFloat(0.28 + radius * 0.42)

        let colors = [
            color.withAlphaComponent(0.42 * intensity).cgColor,
            color.withAlphaComponent(0.14 * intensity).cgColor,
            color.withAlphaComponent(0.0).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.42, 1.0]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: maxRadius,
                options: [.drawsAfterEndLocation]
            )
        }

        let wash = color.withAlphaComponent(0.09 * intensity).cgColor
        context.setFillColor(wash)
        context.fill(CGRect(origin: .zero, size: imageSize))
        context.restoreGState()
    }

    private func overlayCenter(for preset: LightPreset, imageSize: CGSize) -> CGPoint {
        switch preset {
        case .keyLeft:
            CGPoint(x: imageSize.width * 0.18, y: imageSize.height * 0.18)
        case .rimRight:
            CGPoint(x: imageSize.width * 0.84, y: imageSize.height * 0.22)
        case .frontSoft:
            CGPoint(x: imageSize.width * 0.5, y: imageSize.height * 0.45)
        case .topDown:
            CGPoint(x: imageSize.width * 0.5, y: imageSize.height * 0.08)
        case .lowSide:
            CGPoint(x: imageSize.width * 0.18, y: imageSize.height * 0.82)
        }
    }
}
