import Foundation
import simd

enum SpatialRelationResolver {
    enum HorizontalZone: String, Codable, Equatable {
        case leading
        case center
        case trailing

        var promptText: String {
            switch self {
            case .leading: "画面左侧"
            case .center: "画面中央"
            case .trailing: "画面右侧"
            }
        }
    }

    enum DepthZone: String, Codable, Equatable {
        case foreground
        case midground
        case background

        var promptText: String {
            switch self {
            case .foreground: "前景"
            case .midground: "中景"
            case .background: "背景"
            }
        }
    }

    enum Facing: String, Codable, Equatable {
        case towardCamera
        case awayFromCamera
        case sideOn
        case notApplicable

        var promptText: String? {
            switch self {
            case .towardCamera: "朝向镜头"
            case .awayFromCamera: "背向镜头"
            case .sideOn: "侧向镜头"
            case .notApplicable: nil
            }
        }
    }

    static func horizontalZone(for cameraPosition: SIMD3<Float>) -> HorizontalZone {
        switch cameraPosition.x {
        case ..<(-0.35): .leading
        case 0.35...: .trailing
        default: .center
        }
    }

    static func depthZone(for cameraPosition: SIMD3<Float>) -> DepthZone {
        let distanceForward = max(0, -cameraPosition.z)
        if distanceForward < 1.4 {
            return DepthZone.foreground
        }
        if distanceForward < 3.2 {
            return DepthZone.midground
        }
        return DepthZone.background
    }

    static func facing(
        type: SceneTool,
        worldPosition: SIMD3<Float>,
        yaw: Float,
        cameraPosition: SIMD3<Float>
    ) -> Facing {
        guard type == .subject else { return .notApplicable }
        let towardCamera = cameraPosition - worldPosition
        let flatDistance = simd_length(SIMD2(towardCamera.x, towardCamera.z))
        guard flatDistance > 0.001 else { return .sideOn }

        let entityForward = SIMD2(-sin(yaw), -cos(yaw))
        let targetDirection = SIMD2(towardCamera.x, towardCamera.z) / flatDistance
        let alignment = simd_dot(entityForward, targetDirection)
        if alignment > 0.6 { return .towardCamera }
        if alignment < -0.6 { return .awayFromCamera }
        return .sideOn
    }
}
