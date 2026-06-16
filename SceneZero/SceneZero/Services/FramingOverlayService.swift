import CoreGraphics
import UIKit

struct FramingSafeInsets: Equatable {
    var top: CGFloat = 0
    var leading: CGFloat = 0
    var bottom: CGFloat = 0
    var trailing: CGFloat = 0

    static let zero = FramingSafeInsets()

    func scaled(x: CGFloat, y: CGFloat) -> FramingSafeInsets {
        FramingSafeInsets(
            top: top * y,
            leading: leading * x,
            bottom: bottom * y,
            trailing: trailing * x
        )
    }

    var uiEdgeInsets: UIEdgeInsets {
        UIEdgeInsets(top: top, left: leading, bottom: bottom, right: trailing)
    }
}

enum FramingGeometry {
    static func frameRect(
        in bounds: CGRect,
        aspectRatio: FrameAspectRatio,
        shotType: ShotType,
        contentInsets: FramingSafeInsets = .zero
    ) -> CGRect {
        let contentBounds = bounds.inset(by: contentInsets.uiEdgeInsets)
        let usableBounds = contentBounds.width > 80 && contentBounds.height > 80 ? contentBounds : bounds
        let safeBounds = usableBounds.insetBy(dx: usableBounds.width * 0.04, dy: usableBounds.height * 0.08)
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
        showsGuides: Bool,
        viewportSize: CGSize? = nil,
        contentInsets: FramingSafeInsets = .zero,
        cropsToFrame: Bool = true
    ) -> UIImage {
        if cropsToFrame {
            return croppedReferenceImage(
                from: image,
                aspectRatio: aspectRatio,
                shotType: shotType,
                showsGuides: showsGuides,
                viewportSize: viewportSize,
                contentInsets: contentInsets
            )
        }

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
                shotType: shotType,
                contentInsets: contentInsets
            )
            drawMask(in: context.cgContext, bounds: bounds, frameRect: frameRect)
            drawFrame(in: context.cgContext, frameRect: frameRect, showsGuides: showsGuides)
        }
    }

    private func croppedReferenceImage(
        from image: UIImage,
        aspectRatio: FrameAspectRatio,
        shotType: ShotType,
        showsGuides: Bool,
        viewportSize: CGSize?,
        contentInsets: FramingSafeInsets
    ) -> UIImage {
        let viewportSize = viewportSize ?? image.size
        let viewportBounds = CGRect(origin: .zero, size: viewportSize)
        let viewportFrameRect = FramingGeometry.frameRect(
            in: viewportBounds,
            aspectRatio: aspectRatio,
            shotType: shotType,
            contentInsets: contentInsets
        )

        let scaleX = image.size.width / max(viewportSize.width, 1)
        let scaleY = image.size.height / max(viewportSize.height, 1)
        let imageFrameRect = CGRect(
            x: viewportFrameRect.minX * scaleX,
            y: viewportFrameRect.minY * scaleY,
            width: viewportFrameRect.width * scaleX,
            height: viewportFrameRect.height * scaleY
        )

        guard let cropped = crop(image, to: imageFrameRect) else {
            return image
        }

        guard showsGuides else {
            return cropped
        }

        return drawReferenceGuides(on: cropped)
    }

    private func crop(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let pixelScaleX = CGFloat(cgImage.width) / max(image.size.width, 1)
        let pixelScaleY = CGFloat(cgImage.height) / max(image.size.height, 1)
        let pixelRect = CGRect(
            x: rect.minX * pixelScaleX,
            y: rect.minY * pixelScaleY,
            width: rect.width * pixelScaleX,
            height: rect.height * pixelScaleY
        )
        .integral
        .intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        guard pixelRect.width > 1,
              pixelRect.height > 1,
              let croppedCGImage = cgImage.cropping(to: pixelRect) else {
            return nil
        }

        return UIImage(
            cgImage: croppedCGImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    private func drawReferenceGuides(on image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: image.size)
            image.draw(in: bounds)
            drawGuideLines(in: context.cgContext, frameRect: bounds.insetBy(dx: 1, dy: 1))
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

    private func drawGuideLines(in context: CGContext, frameRect: CGRect) {
        context.saveGState()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.38).cgColor)
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

        context.strokePath()
        context.restoreGState()
    }
}
