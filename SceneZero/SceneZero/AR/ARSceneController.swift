import ARKit
import RealityKit
import SwiftUI

@MainActor
final class ARSceneController: ObservableObject {
    @Published var selectedTool: SceneTool = .subject
    @Published var lightPreset: LightPreset = .keyLeft
    @Published var colorTemperature: ColorTemperature = .daylight5600
    @Published var filterPreset: FilterPreset = .realistic
    @Published var shotType: ShotType = .wide
    @Published var locationDescription = "realistic interior location"
    @Published var statusText = "Move your device to find a surface"
    @Published var isCapturing = false

    private weak var arView: ARView?
    private var hasSubjectAnchor = false
    private var subjectWorldPosition: SIMD3<Float>?
    private var records: [SceneObjectRecord] = []

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

        let tool = hasSubjectAnchor ? selectedTool : .subject
        place(tool: tool, at: result.worldTransform, worldPosition: worldPosition, in: arView)
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
                    layoutRecords: self.records
                )))
            }
        }
    }

    func resetScene() {
        arView?.scene.anchors.removeAll()
        records.removeAll()
        hasSubjectAnchor = false
        subjectWorldPosition = nil
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
        let entity = makeEntity(for: tool)
        entity.generateCollisionShapes(recursive: true)
        anchor.addChild(entity)

        if tool == .light {
            addLightMarker(to: anchor)
        }

        if tool == .subject {
            hasSubjectAnchor = true
            subjectWorldPosition = worldPosition
            statusText = "Subject anchor placed"
        } else {
            statusText = "\(tool.rawValue) placed"
        }

        arView.scene.addAnchor(anchor)
        addShadowReceiver(near: worldPosition, in: arView)
        records.append(record(for: tool, worldPosition: worldPosition))
    }

    private func makeEntity(for tool: SceneTool) -> ModelEntity {
        switch tool {
        case .subject:
            let mesh = MeshResource.generateBox(width: 0.28, height: 1.65, depth: 0.28)
            let material = SimpleMaterial(color: UIColor.systemBlue.withAlphaComponent(0.72), isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position.y = 0.825
            return entity
        case .prop:
            let mesh = MeshResource.generateBox(width: 0.45, height: 0.35, depth: 0.45)
            let material = SimpleMaterial(color: UIColor.systemGray.withAlphaComponent(0.82), isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position.y = 0.175
            return entity
        case .camera:
            let mesh = MeshResource.generateBox(width: 0.35, height: 0.2, depth: 0.24)
            let material = SimpleMaterial(color: UIColor.label.withAlphaComponent(0.82), isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position.y = 0.45
            return entity
        case .light:
            let mesh = MeshResource.generateSphere(radius: 0.12)
            let material = SimpleMaterial(color: colorTemperature.uiColor, isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position.y = 1.35
            return entity
        }
    }

    private func addLightMarker(to anchor: AnchorEntity) {
        let mesh = MeshResource.generateBox(width: 0.05, height: 0.05, depth: 0.65)
        let material = SimpleMaterial(color: UIColor.systemYellow.withAlphaComponent(0.45), isMetallic: false)
        let beam = ModelEntity(mesh: mesh, materials: [material])
        beam.position = SIMD3<Float>(0, 1.25, -0.35)
        anchor.addChild(beam)
    }

    private func addShadowReceiver(near position: SIMD3<Float>, in arView: ARView) {
        let anchor = AnchorEntity(world: position)
        let mesh = MeshResource.generatePlane(width: 1.2, depth: 1.2)
        let material = SimpleMaterial(color: UIColor.black.withAlphaComponent(0.08), isMetallic: false)
        let plane = ModelEntity(mesh: mesh, materials: [material])
        anchor.addChild(plane)
        arView.scene.addAnchor(anchor)
    }

    private func record(for tool: SceneTool, worldPosition: SIMD3<Float>) -> SceneObjectRecord {
        let origin = subjectWorldPosition ?? worldPosition
        let relative = worldPosition - origin
        return SceneObjectRecord(
            type: tool,
            relativeX: relative.x,
            relativeY: relative.y,
            relativeZ: relative.z,
            yaw: 0
        )
    }
}

enum CaptureError: Error {
    case snapshotFailed
}
