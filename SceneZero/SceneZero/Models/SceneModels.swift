import Foundation
import simd
import SwiftData
import SwiftUI
import UIKit

enum SceneTool: String, CaseIterable, Identifiable, Codable {
    case subject = "Subject"
    case prop = "Prop"
    case camera = "Camera"
    case light = "Light"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .subject: "person.crop.rectangle"
        case .prop: "cube"
        case .camera: "video"
        case .light: "lightbulb"
        }
    }
}

enum LightPreset: String, CaseIterable, Identifiable, Codable {
    case keyLeft = "Key Left 45"
    case rimRight = "Rim Right Back"
    case frontSoft = "Front Soft"
    case topDown = "Top Light"
    case lowSide = "Low Side"

    var id: String { rawValue }

    var promptText: String {
        switch self {
        case .keyLeft: "warm key light from front left"
        case .rimRight: "rim light from rear right"
        case .frontSoft: "soft frontal light"
        case .topDown: "top light from above"
        case .lowSide: "low side light"
        }
    }

    var overlayStartPoint: UnitPoint {
        switch self {
        case .keyLeft: .topLeading
        case .rimRight: .topTrailing
        case .frontSoft: .center
        case .topDown: .top
        case .lowSide: .bottomLeading
        }
    }

    var overlayEndPoint: UnitPoint {
        switch self {
        case .keyLeft: .bottomTrailing
        case .rimRight: .bottomLeading
        case .frontSoft: .center
        case .topDown: .bottom
        case .lowSide: .topTrailing
        }
    }

    var lightRotation: simd_quatf {
        switch self {
        case .keyLeft:
            simd_quatf(angle: -.pi / 5, axis: SIMD3<Float>(0, 1, 0))
        case .rimRight:
            simd_quatf(angle: .pi * 0.75, axis: SIMD3<Float>(0, 1, 0))
        case .frontSoft:
            simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        case .topDown:
            simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        case .lowSide:
            simd_quatf(angle: -.pi / 4, axis: SIMD3<Float>(0, 1, 0))
        }
    }
}

enum ColorTemperature: String, CaseIterable, Identifiable, Codable {
    case warm3200 = "3200K"
    case neutral4500 = "4500K"
    case daylight5600 = "5600K"
    case cool7000 = "7000K"

    var id: String { rawValue }

    var uiColor: UIColor {
        switch self {
        case .warm3200: UIColor(red: 1.0, green: 0.74, blue: 0.42, alpha: 1.0)
        case .neutral4500: UIColor(red: 1.0, green: 0.91, blue: 0.78, alpha: 1.0)
        case .daylight5600: UIColor(red: 0.92, green: 0.95, blue: 1.0, alpha: 1.0)
        case .cool7000: UIColor(red: 0.68, green: 0.80, blue: 1.0, alpha: 1.0)
        }
    }

    var promptText: String {
        switch self {
        case .warm3200: "warm tungsten color temperature"
        case .neutral4500: "neutral white color temperature"
        case .daylight5600: "natural daylight color temperature"
        case .cool7000: "cool blue color temperature"
        }
    }
}

enum FilterPreset: String, CaseIterable, Identifiable, Codable {
    case realistic = "Realistic"
    case tealOrange = "Teal Orange"
    case neonNight = "Neon Night"
    case noirGold = "Noir Gold"

    var id: String { rawValue }

    var promptText: String {
        switch self {
        case .realistic: "low saturation realistic film look"
        case .tealOrange: "teal and orange cinematic color grade"
        case .neonNight: "neon cyberpunk night look"
        case .noirGold: "high contrast noir gold look"
        }
    }
}

enum ShotType: String, CaseIterable, Identifiable, Codable {
    case wide = "Wide Shot"
    case medium = "Medium Shot"
    case closeUp = "Close-Up"
    case lowAngle = "Low Angle"

    var id: String { rawValue }

    var promptText: String {
        switch self {
        case .wide: "cinematic wide shot"
        case .medium: "cinematic medium shot"
        case .closeUp: "cinematic close-up"
        case .lowAngle: "cinematic low angle shot"
        }
    }
}

struct SceneObjectRecord: Codable, Identifiable {
    var id = UUID()
    var type: SceneTool
    var relativeX: Float
    var relativeY: Float
    var relativeZ: Float
    var scale: Float
    var lightPreset: LightPreset?
    var colorTemperature: ColorTemperature?
    var lightIntensity: Double?
    var lightRadius: Double?
    var yaw: Float
}

struct CapturedScene: Identifiable {
    let id = UUID()
    let image: UIImage
    let prompt: String
    let filterPreset: FilterPreset
    let shotType: ShotType
    let lightPreset: LightPreset
    let colorTemperature: ColorTemperature
    let lightIntensity: Double
    let lightRadius: Double
    let shouldRenderLightingOverlay: Bool
    let layoutRecords: [SceneObjectRecord]
}

@Model
final class LookbookEntry {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var imagePath: String
    var prompt: String
    var shotType: String
    var lightPreset: String
    var colorTemperature: String
    var lightIntensity: Double = 0.65
    var lightRadius: Double = 0.55
    var filterName: String
    var layoutJSON: String

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        imagePath: String,
        prompt: String,
        shotType: String,
        lightPreset: String,
        colorTemperature: String,
        lightIntensity: Double = 0.65,
        lightRadius: Double = 0.55,
        filterName: String,
        layoutJSON: String
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.imagePath = imagePath
        self.prompt = prompt
        self.shotType = shotType
        self.lightPreset = lightPreset
        self.colorTemperature = colorTemperature
        self.lightIntensity = lightIntensity
        self.lightRadius = lightRadius
        self.filterName = filterName
        self.layoutJSON = layoutJSON
    }
}
