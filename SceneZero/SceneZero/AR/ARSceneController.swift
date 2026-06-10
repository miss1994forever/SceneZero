import ARKit
import RealityKit
import SwiftUI

@MainActor
final class ARSceneController: ObservableObject {
    @Published var selectedTool: SceneTool = .subject
    @Published var lightPreset: LightPreset = .keyLeft {
        didSet { updatePlacedLights() }
    }
    @Published var colorTemperature: ColorTemperature = .daylight5600 {
        didSet { updatePlacedLights() }
    }
    @Published var filterPreset: FilterPreset = .realistic
    @Published var shotType: ShotType = .wide
    @Published var objectScale = 0.75
    @Published var lightIntensity = 0.65 {
        didSet { updatePlacedLights() }
    }
    @Published var lightRadius = 0.55
    @Published var hasLightingOverlay = false
    @Published var locationDescription = "realistic interior location"
    @Published var statusText = "Move your device to find a surface"
    @Published var isCapturing = false

    private weak var arView: ARView?
    private var hasSubjectAnchor = false
    private var layoutOriginPosition: SIMD3<Float>?
    private var records: [SceneObjectRecord] = []
    private var spotLights: [SpotLight] = []

    func attach(_ arView: ARView) {
        guard self.arView !== arView else { return }
        self.arView = arView
        configureSession(on: arView)
    }

    func handleTap(at point: CGPoint, in arView: ARView) {
        let results = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .any)
        guard let result = results.first else {
            statusText = "No surface found yet"
            return
        }

        let worldPosition = SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )

        place(tool: selectedTool, at: result.worldTransform, worldPosition: worldPosition, in: arView)
    }

    func capture(completion: @escaping (Result<CapturedScene, Error>) -> Void) {
        guard let arView else { return }
        guard !isCapturing else { return }

        isCapturing = true
        statusText = "Capturing frame..."

        arView.snapshot(saveToHDR: false) { [weak self] image in
            Task { @MainActor in
                guard let self else { return }
                self.isCapturing = false

                guard let image else {
                    self.statusText = "Capture failed"
                    completion(.failure(CaptureError.snapshotFailed))
                    return
                }

                let prompt = PromptService.makePrompt(
                    shotType: self.shotType,
                    lightPreset: self.lightPreset,
                    colorTemperature: self.colorTemperature,
                    filterPreset: self.filterPreset,
                    hasSubject: self.hasSubjectAnchor,
                    locationDescription: self.locationDescription
                )

                self.statusText = "Frame captured"
                completion(.success(CapturedScene(
                    image: image,
                    prompt: prompt,
                    filterPreset: self.filterPreset,
                    shotType: self.shotType,
                    lightPreset: self.lightPreset,
                    colorTemperature: self.colorTemperature,
                    lightIntensity: self.lightIntensity,
                    lightRadius: self.lightRadius,
                    shouldRenderLightingOverlay: self.hasLightingOverlay,
                    layoutRecords: self.records
                )))
            }
        }
    }

    func resetScene() {
        arView?.scene.anchors.removeAll()
        records.removeAll()
        hasSubjectAnchor = false
        layoutOriginPosition = nil
        hasLightingOverlay = false
        spotLights.removeAll()
        statusText = "Scene cleared"
    }

    private func configureSession(on arView: ARView) {
        arView.automaticallyConfigureSession = false
        arView.environment.sceneUnderstanding.options.insert(.occlusion)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        arView.session.run(configuration)
    }

    private func place(
        tool: SceneTool,
        at transform: simd_float4x4,
        worldPosition: SIMD3<Float>,
        in arView: ARView
    ) {
        let anchor = AnchorEntity(world: transform)
        let scale = Float(objectScale)
        let entity = makeEntity(for: tool, scale: scale)
        entity.generateCollisionShapes(recursive: true)
        anchor.addChild(entity)

        if tool == .light {
            addLightMarker(to: anchor, scale: scale)
            addRealityKitLight(to: anchor, scale: scale)
            hasLightingOverlay = true
        }

        if layoutOriginPosition == nil {
            layoutOriginPosition = worldPosition
        }

        if tool == .subject {
            hasSubjectAnchor = true
            statusText = "Subject placed"
        } else {
            statusText = "\(tool.rawValue) placed"
        }

        arView.scene.addAnchor(anchor)
        addShadowReceiver(near: worldPosition, scale: scale, in: arView)
        records.append(record(for: tool, worldPosition: worldPosition, scale: scale))
    }

    private func makeEntity(for tool: SceneTool, scale: Float) -> ModelEntity {
        switch tool {
        case .subject:
            let width = 0.28 * scale
            let height = 1.65 * scale
            let depth = 0.28 * scale
            let mesh = MeshResource.generateBox(width: width, height: height, depth: depth)
            let material = SimpleMaterial(color: UIColor.systemBlue.withAlphaComponent(0.72), isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position.y = height / 2
            return entity
        case .prop:
            let width = 0.45 * scale
            let height = 0.35 * scale
            let depth = 0.45 * scale
            let mesh = MeshResource.generateBox(width: width, height: height, depth: depth)
            let material = SimpleMaterial(color: UIColor.systemGray.withAlphaComponent(0.82), isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position.y = height / 2
            return entity
        case .camera:
            let width = 0.35 * scale
            let height = 0.2 * scale
            let depth = 0.24 * scale
            let mesh = MeshResource.generateBox(width: width, height: height, depth: depth)
            let material = SimpleMaterial(color: UIColor.label.withAlphaComponent(0.82), isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position.y = 0.45 * scale
            return entity
        case .light:
            let mesh = MeshResource.generateSphere(radius: 0.12 * scale)
            let material = SimpleMaterial(color: colorTemperature.uiColor, isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position.y = 1.35 * scale
            return entity
        }
    }

    private func addLightMarker(to anchor: AnchorEntity, scale: Float) {
        let mesh = MeshResource.generateBox(width: 0.05 * scale, height: 0.05 * scale, depth: 0.65 * scale)
        let material = SimpleMaterial(color: UIColor.systemYellow.withAlphaComponent(0.45), isMetallic: false)
        let beam = ModelEntity(mesh: mesh, materials: [material])
        beam.position = SIMD3<Float>(0, 1.25 * scale, -0.35 * scale)
        beam.orientation = lightPreset.lightRotation
        anchor.addChild(beam)
    }

    private func addRealityKitLight(to anchor: AnchorEntity, scale: Float) {
        let light = SpotLight()
        light.position = SIMD3<Float>(0, 1.35 * scale, 0)
        light.orientation = lightPreset.lightRotation
        light.light.color = colorTemperature.uiColor
        light.light.intensity = Float(2_500 + lightIntensity * 12_000)
        light.light.innerAngleInDegrees = 18
        light.light.outerAngleInDegrees = Float(38 + lightRadius * 34)
        anchor.addChild(light)
        spotLights.append(light)
    }

    private func updatePlacedLights() {
        for light in spotLights {
            light.orientation = lightPreset.lightRotation
            light.light.color = colorTemperature.uiColor
            light.light.intensity = Float(2_500 + lightIntensity * 12_000)
            light.light.outerAngleInDegrees = Float(38 + lightRadius * 34)
        }
    }

    private func addShadowReceiver(near position: SIMD3<Float>, scale: Float, in arView: ARView) {
        let anchor = AnchorEntity(world: position)
        let receiverSize = max(0.8, 1.2 * scale)
        let mesh = MeshResource.generatePlane(width: receiverSize, depth: receiverSize)
        let material = SimpleMaterial(color: UIColor.black.withAlphaComponent(0.08), isMetallic: false)
        let plane = ModelEntity(mesh: mesh, materials: [material])
        anchor.addChild(plane)
        arView.scene.addAnchor(anchor)
    }

    private func record(for tool: SceneTool, worldPosition: SIMD3<Float>, scale: Float) -> SceneObjectRecord {
        let origin = layoutOriginPosition ?? worldPosition
        let relative = worldPosition - origin
        return SceneObjectRecord(
            type: tool,
            relativeX: relative.x,
            relativeY: relative.y,
            relativeZ: relative.z,
            scale: scale,
            lightPreset: tool == .light ? lightPreset : nil,
            colorTemperature: tool == .light ? colorTemperature : nil,
            lightIntensity: tool == .light ? lightIntensity : nil,
            lightRadius: tool == .light ? lightRadius : nil,
            yaw: 0
        )
    }
}

enum CaptureError: Error {
    case snapshotFailed
}
