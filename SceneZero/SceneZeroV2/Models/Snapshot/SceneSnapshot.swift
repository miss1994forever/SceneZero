import Foundation
import simd

/// An immutable description of the AR scene at the instant the user presses the shutter.
/// It deliberately contains value types only, so it can be encoded independently of SwiftData.
struct SceneSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let capturedAt: Date
    let camera: CameraSnapshot
    let entities: [SceneEntitySnapshot]
    let lights: [LightingSnapshot]
    let frameAspectRatio: FrameAspectRatio
    let lensPreset: LensPreset
    let shotType: ShotType
    let filterPreset: FilterPreset
    let locationDescription: String

    init(
        capturedAt: Date = .now,
        camera: CameraSnapshot,
        entities: [SceneEntitySnapshot],
        lights: [LightingSnapshot],
        frameAspectRatio: FrameAspectRatio,
        lensPreset: LensPreset,
        shotType: ShotType,
        filterPreset: FilterPreset,
        locationDescription: String
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.capturedAt = capturedAt
        self.camera = camera
        self.entities = entities
        self.lights = lights
        self.frameAspectRatio = frameAspectRatio
        self.lensPreset = lensPreset
        self.shotType = shotType
        self.filterPreset = filterPreset
        self.locationDescription = locationDescription
    }
}

struct CameraSnapshot: Codable, Equatable {
    let transform: [Float]
    let isTrackingPoseAvailable: Bool

    init(transform: simd_float4x4 = matrix_identity_float4x4, isTrackingPoseAvailable: Bool) {
        self.transform = [
            transform.columns.0.x, transform.columns.0.y, transform.columns.0.z, transform.columns.0.w,
            transform.columns.1.x, transform.columns.1.y, transform.columns.1.z, transform.columns.1.w,
            transform.columns.2.x, transform.columns.2.y, transform.columns.2.z, transform.columns.2.w,
            transform.columns.3.x, transform.columns.3.y, transform.columns.3.z, transform.columns.3.w
        ]
        self.isTrackingPoseAvailable = isTrackingPoseAvailable
    }

    var matrix: simd_float4x4 {
        guard transform.count == 16 else { return matrix_identity_float4x4 }
        return simd_float4x4(
            SIMD4(transform[0], transform[1], transform[2], transform[3]),
            SIMD4(transform[4], transform[5], transform[6], transform[7]),
            SIMD4(transform[8], transform[9], transform[10], transform[11]),
            SIMD4(transform[12], transform[13], transform[14], transform[15])
        )
    }

    var worldPosition: SIMD3<Float> {
        let position = matrix.columns.3
        return SIMD3(position.x, position.y, position.z)
    }

    func cameraSpacePosition(for worldPosition: SIMD3<Float>) -> SIMD3<Float> {
        let position = simd_inverse(matrix) * SIMD4(worldPosition.x, worldPosition.y, worldPosition.z, 1)
        return SIMD3(position.x, position.y, position.z)
    }
}

struct SceneEntitySnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let type: SceneTool
    let assetPreset: AssetPreset?
    let worldPosition: [Float]
    let cameraPosition: [Float]
    let yaw: Float
    let scale: Float
    let horizontalZone: SpatialRelationResolver.HorizontalZone
    let depthZone: SpatialRelationResolver.DepthZone
    let facing: SpatialRelationResolver.Facing

    init(
        id: UUID,
        type: SceneTool,
        assetPreset: AssetPreset?,
        worldPosition: SIMD3<Float>,
        cameraPosition: SIMD3<Float>,
        yaw: Float,
        scale: Float,
        horizontalZone: SpatialRelationResolver.HorizontalZone,
        depthZone: SpatialRelationResolver.DepthZone,
        facing: SpatialRelationResolver.Facing
    ) {
        self.id = id
        self.type = type
        self.assetPreset = assetPreset
        self.worldPosition = [worldPosition.x, worldPosition.y, worldPosition.z]
        self.cameraPosition = [cameraPosition.x, cameraPosition.y, cameraPosition.z]
        self.yaw = yaw
        self.scale = scale
        self.horizontalZone = horizontalZone
        self.depthZone = depthZone
        self.facing = facing
    }
}

struct LightingSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let preset: LightPreset?
    let colorTemperature: ColorTemperature?
    let intensity: Double?
    let radius: Double?
    let horizontalZone: SpatialRelationResolver.HorizontalZone
    let depthZone: SpatialRelationResolver.DepthZone
}
