import Foundation
import simd
import SwiftData
import SwiftUI
import UIKit

enum SceneTool: String, CaseIterable, Identifiable, Codable {
    case subject = "Subject"
    case prop = "Prop"
    case frame = "Frame"
    case light = "Light"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .subject: "person.crop.rectangle"
        case .prop: "cube"
        case .frame: "viewfinder"
        case .light: "lightbulb"
        }
    }
}

enum AssetCategory: String, CaseIterable, Identifiable, Codable {
    case subject = "Subject"
    case prop = "Prop"
    case lightMarker = "Light Marker"

    var id: String { rawValue }
}

enum FallbackPrimitive: String, Codable {
    case box
    case verticalBox
    case sphere
}

enum AssetPreset: String, CaseIterable, Identifiable, Codable {
    case subjectBlock = "Subject Block"
    case human = "Human"
    case propBox = "Prop Box"
    case chair = "Chair"
    case table = "Table"
    case sofa = "Sofa"
    case desk = "Desk"
    case bookcase = "Bookcase"
    case bed = "Bed"
    case nightStand = "Night Stand"
    case lampStand = "Lamp Stand"

    var id: String { rawValue }

    var category: AssetCategory {
        switch self {
        case .subjectBlock, .human:
            .subject
        case .propBox, .chair, .table, .sofa, .desk, .bookcase, .bed, .nightStand:
            .prop
        case .lampStand:
            .lightMarker
        }
    }

    var bundleModelName: String? {
        switch self {
        case .subjectBlock, .propBox:
            nil
        case .human:
            "Human"
        case .chair:
            "Chair"
        case .table:
            "Table"
        case .sofa:
            "Sofa"
        case .desk:
            "Desk"
        case .bookcase:
            "Bookcase"
        case .bed:
            "Bed"
        case .nightStand:
            "NightStand"
        case .lampStand:
            "LampStand"
        }
    }

    var defaultScale: Double {
        switch self {
        case .subjectBlock, .human:
            0.75
        case .propBox:
            0.75
        case .chair:
            0.95
        case .table:
            0.95
        case .sofa:
            0.9
        case .desk:
            0.9
        case .bookcase:
            0.75
        case .bed:
            0.85
        case .nightStand:
            0.85
        case .lampStand:
            0.75
        }
    }

    var fallbackPrimitive: FallbackPrimitive {
        switch self {
        case .subjectBlock, .human:
            .verticalBox
        case .propBox, .chair, .table, .sofa, .desk, .bookcase, .bed, .nightStand:
            .box
        case .lampStand:
            .sphere
        }
    }

    var systemImage: String {
        switch self {
        case .subjectBlock:
            "person.crop.rectangle"
        case .human:
            "figure.stand"
        case .propBox:
            "cube"
        case .chair:
            "chair"
        case .table:
            "table.furniture"
        case .sofa:
            "sofa"
        case .desk:
            "studentdesk"
        case .bookcase:
            "books.vertical"
        case .bed:
            "bed.double"
        case .nightStand:
            "cabinet"
        case .lampStand:
            "lightbulb"
        }
    }

    static func presets(for tool: SceneTool) -> [AssetPreset] {
        switch tool {
        case .subject:
            [.subjectBlock, .human]
        case .prop:
            [.propBox, .chair, .table, .sofa, .desk, .bookcase, .bed, .nightStand]
        case .light:
            [.lampStand]
        case .frame:
            []
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

    var framingScale: CGFloat {
        switch self {
        case .wide: 1.0
        case .medium: 0.86
        case .closeUp: 0.66
        case .lowAngle: 0.9
        }
    }

    var framingYOffset: CGFloat {
        switch self {
        case .lowAngle: 0.08
        default: 0
        }
    }
}

enum FrameAspectRatio: String, CaseIterable, Identifiable, Codable {
    case wide16x9 = "16:9"
    case cinema239 = "2.39:1"
    case square1x1 = "1:1"
    case vertical9x16 = "9:16"

    var id: String { rawValue }

    var ratio: CGFloat {
        switch self {
        case .wide16x9: 16.0 / 9.0
        case .cinema239: 2.39
        case .square1x1: 1.0
        case .vertical9x16: 9.0 / 16.0
        }
    }

    var promptText: String {
        switch self {
        case .wide16x9: "16:9 widescreen frame"
        case .cinema239: "2.39:1 cinematic anamorphic frame"
        case .square1x1: "1:1 square frame"
        case .vertical9x16: "9:16 vertical frame"
        }
    }
}

enum LensPreset: String, CaseIterable, Identifiable, Codable {
    case wide24 = "24mm"
    case standard35 = "35mm"
    case normal50 = "50mm"
    case portrait85 = "85mm"

    var id: String { rawValue }

    var promptText: String {
        switch self {
        case .wide24: "24mm wide lens language"
        case .standard35: "35mm standard lens language"
        case .normal50: "50mm natural perspective lens language"
        case .portrait85: "85mm portrait lens language"
        }
    }
}

struct SceneObjectRecord: Codable, Identifiable {
    var id = UUID()
    var type: SceneTool
    var assetPreset: AssetPreset?
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
    let frameAspectRatio: FrameAspectRatio
    let lensPreset: LensPreset
    let showsCompositionGuides: Bool
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
    var frameAspectRatio: String = FrameAspectRatio.cinema239.rawValue
    var lensPreset: String = LensPreset.standard35.rawValue
    var showsCompositionGuides: Bool = true
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
        frameAspectRatio: String = FrameAspectRatio.cinema239.rawValue,
        lensPreset: String = LensPreset.standard35.rawValue,
        showsCompositionGuides: Bool = true,
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
        self.frameAspectRatio = frameAspectRatio
        self.lensPreset = lensPreset
        self.showsCompositionGuides = showsCompositionGuides
        self.filterName = filterName
        self.layoutJSON = layoutJSON
    }
}
