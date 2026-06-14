import CoreGraphics
import UIKit

enum FramingGeometry {
    static func frameRect(
        in bounds: CGRect,
        aspectRatio: FrameAspectRatio,
        shotType: ShotType
    ) -> CGRect {
        let safeBounds = bounds.insetBy(dx: bounds.width * 0.04, dy: bounds.height * 0.08)
        let targetRatio = aspectRatio.ratio

        var width = safeBounds.width
        var height = width / targetRatio
        if height > safeBounds.height {
            height = safeBounds.height
            width = height * targetRatio
        }

        width *= shotType.framingScale
        height *= shotType.framingScale

        let yOffset = safeBounds.height * shotType.framingYOffset
        return CGRect(
            x: safeBounds.midX - width / 2,
            y: safeBounds.midY - height / 2 + yOffset,
            width: width,
            height: height
        ).integral
    }
}

struct FramingOverlayService {
    func applyOverlay(
        to image: UIImage,
        aspectRatio: FrameAspectRatio,
        shotType: ShotType,
        lensPreset: LensPreset,
        showsGuides: Bool
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: image.size)
            image.draw(in: bounds)

            let frameRect = FramingGeometry.frameRect(
                in: bounds,
                aspectRatio: aspectRatio,
                shotType: shotType
            )
            drawMask(in: context.cgContext, bounds: bounds, frameRect: frameRect)
            drawFrame(in: context.cgContext, frameRect: frameRect, showsGuides: showsGuides)
        }
    }

    private func drawMask(in context: CGContext, bounds: CGRect, frameRect: CGRect) {
        context.saveGState()
        context.setFillColor(UIColor.black.withAlphaComponent(0.42).cgColor)
        context.addRect(bounds)
        context.addRect(frameRect)
        context.drawPath(using: .eoFill)
        context.restoreGState()
    }

    private func drawFrame(in context: CGContext, frameRect: CGRect, showsGuides: Bool) {
        context.saveGState()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.88).cgColor)
        context.setLineWidth(2)
        context.stroke(frameRect)

        guard showsGuides else {
            context.restoreGState()
            return
        }

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.45).cgColor)
        context.setLineWidth(1)

        let thirdWidth = frameRect.width / 3
        let thirdHeight = frameRect.height / 3
        for index in 1...2 {
            let x = frameRect.minX + thirdWidth * CGFloat(index)
            context.move(to: CGPoint(x: x, y: frameRect.minY))
            context.addLine(to: CGPoint(x: x, y: frameRect.maxY))

            let y = frameRect.minY + thirdHeight * CGFloat(index)
            context.move(to: CGPoint(x: frameRect.minX, y: y))
            context.addLine(to: CGPoint(x: frameRect.maxX, y: y))
        }

        let center = CGPoint(x: frameRect.midX, y: frameRect.midY)
        context.move(to: CGPoint(x: center.x - 22, y: center.y))
        context.addLine(to: CGPoint(x: center.x + 22, y: center.y))
        context.move(to: CGPoint(x: center.x, y: center.y - 22))
        context.addLine(to: CGPoint(x: center.x, y: center.y + 22))

        let safeRect = frameRect.insetBy(dx: frameRect.width * 0.06, dy: frameRect.height * 0.06)
        context.stroke(safeRect)
        context.strokePath()
        context.restoreGState()
    }
}
