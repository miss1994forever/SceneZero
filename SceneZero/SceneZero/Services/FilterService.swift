import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct FilterService {
    private let context = CIContext()

    func apply(_ preset: FilterPreset, to image: UIImage) -> UIImage {
        guard let input = CIImage(image: image) else {
            return image
        }

        let output: CIImage
        switch preset {
        case .realistic:
            output = colorControls(input, saturation: 0.82, contrast: 1.08, brightness: 0.0)
        case .tealOrange:
            let controlled = colorControls(input, saturation: 1.16, contrast: 1.12, brightness: 0.01)
            output = temperature(controlled, neutral: CIVector(x: 6800, y: 0), target: CIVector(x: 5200, y: 0))
        case .neonNight:
            let controlled = colorControls(input, saturation: 1.28, contrast: 1.22, brightness: -0.02)
            output = temperature(controlled, neutral: CIVector(x: 9000, y: 0), target: CIVector(x: 5600, y: 0))
        case .noirGold:
            let controlled = colorControls(input, saturation: 0.72, contrast: 1.35, brightness: -0.03)
            output = temperature(controlled, neutral: CIVector(x: 4200, y: 0), target: CIVector(x: 5600, y: 0))
        }

        guard let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func colorControls(_ input: CIImage, saturation: Float, contrast: Float, brightness: Float) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = input
        filter.saturation = saturation
        filter.contrast = contrast
        filter.brightness = brightness
        return filter.outputImage ?? input
    }

    private func temperature(_ input: CIImage, neutral: CIVector, target: CIVector) -> CIImage {
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = input
        filter.neutral = neutral
        filter.targetNeutral = target
        return filter.outputImage ?? input
    }
}
