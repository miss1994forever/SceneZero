import ARKit
import RealityKit
import SwiftUI

@MainActor
final class ARSceneController: ObservableObject {
    @Published var selectedTool: SceneTool = .subject {
        didSet {
            guard oldValue != selectedTool else { return }
            guard let selectedObjectID,
                  let selected = placedObjects.first(where: { $0.id == selectedObjectID }),
                  selected.tool != selectedTool else { return }
            self.selectedObjectID = nil
        }
    }
    @Published var lightPreset: LightPreset = .keyLeft {
        didSet { updatePlacedLights() }
    }
    @Published var colorTemperature: ColorTemperature = .daylight5600 {
        didSet { updatePlacedLights() }
    }
    @Published var filterPreset: FilterPreset = .realistic
    @Published var shotType: ShotType = .wide
    @Published var frameAspectRatio: FrameAspectRatio = .cinema239
    @Published var lensPreset: LensPreset = .standard35
    @Published var showsCompositionGuides = true
    @Published var subjectAssetPreset: AssetPreset = .subjectBlock
    @Published var propAssetPreset: AssetPreset = .propBox
    @Published var objectScale = 0.75 {
        didSet {
            guard !isUpdatingObjectScaleFromSelection else { return }
            updateActiveObjectScale()
        }
    }
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
    private var placedObjects: [PlacedObject] = []
    private var selectedObjectID: UUID?
    private var isUpdatingObjectScaleFromSelection = false

    func attach(_ arView: ARView) {
        guard self.arView !== arView else { return }
        self.arView = arView
        configureSession(on: arView)
    }

    func handleTap(at point: CGPoint, in arView: ARView) {
        if let entity = arView.entity(at: point), selectPlacedObject(containing: entity) {
            return
        }

        guard selectedTool != .frame else {
            statusText = "\(frameAspectRatio.rawValue) frame active"
            return
        }

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

        syncRecordsFromPlacedObjects()
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
                    frameAspectRatio: self.frameAspectRatio,
                    lensPreset: self.lensPreset,
                    lightRecords: PromptService.lightRecords(from: self.records),
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
                    frameAspectRatio: self.frameAspectRatio,
                    lensPreset: self.lensPreset,
                    showsCompositionGuides: self.showsCompositionGuides,
                    shouldRenderLightingOverlay: self.hasLightingOverlay,
                    layoutRecords: self.records
                )))
            }
        }
    }

    func resetScene() {
        arView?.scene.anchors.removeAll()
        records.removeAll()
        placedObjects.removeAll()
        selectedObjectID = nil
        hasSubjectAnchor = false
        layoutOriginPosition = nil
        hasLightingOverlay = false
        spotLights.removeAll()
        statusText = "Scene cleared"
    }

    func resetSelectedObjectScale() {
        guard let placedObject = activePlacedObject() else {
            statusText = "Select an object first"
            return
        }

        let presetScale = placedObject.assetPreset?.defaultScale ?? 0.75
        isUpdatingObjectScaleFromSelection = true
        objectScale = presetScale
        isUpdatingObjectScaleFromSelection = false

        let newScale = Float(presetScale)
        let relativeScale = max(0.01, newScale / placedObject.initialScale)
        placedObject.entity.scale = SIMD3<Float>(repeating: relativeScale)
        placedObject.entity.position.y = baseHeightOffset(for: placedObject, scale: newScale)
        syncRecord(for: placedObject)

        statusText = "\(placedObject.tool.rawValue) reset"
    }

    func assetPreset(for tool: SceneTool) -> AssetPreset {
        switch tool {
        case .subject:
            subjectAssetPreset
        case .prop:
            propAssetPreset
        case .light:
            .lampStand
        case .frame:
            .subjectBlock
        }
    }

    func setAssetPreset(_ preset: AssetPreset, for tool: SceneTool) {
        switch tool {
        case .subject:
            subjectAssetPreset = preset
            selectedObjectID = nil
            isUpdatingObjectScaleFromSelection = true
            objectScale = preset.defaultScale
            isUpdatingObjectScaleFromSelection = false
            statusText = "\(preset.rawValue) ready"
        case .prop:
            propAssetPreset = preset
            selectedObjectID = nil
            isUpdatingObjectScaleFromSelection = true
            objectScale = preset.defaultScale
            isUpdatingObjectScaleFromSelection = false
            statusText = "\(preset.rawValue) ready"
        case .light, .frame:
            break
        }
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
        let assetPreset = currentAssetPreset(for: tool)
        guard let entity = makeEntity(for: tool, assetPreset: assetPreset, scale: scale) else { return }
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
        installDirectManipulationGesturesIfNeeded(for: entity, tool: tool, in: arView)
        addShadowReceiver(near: worldPosition, scale: scale, in: arView)
        let record = record(for: tool, assetPreset: assetPreset, worldPosition: worldPosition, scale: scale)
        records.append(record)
        placedObjects.append(PlacedObject(
            id: record.id,
            tool: tool,
            assetPreset: assetPreset,
            entity: entity,
            initialScale: scale
        ))
        selectPlacedObject(id: record.id)
    }

    private func makeEntity(for tool: SceneTool, assetPreset: AssetPreset?, scale: Float) -> ModelEntity? {
        if let assetPreset,
           let bundledEntity = makeBundledAssetEntity(for: assetPreset, scale: scale) {
            statusText = "\(assetPreset.rawValue) USDZ loaded"
            return bundledEntity
        }

        switch tool {
        case .subject:
            if assetPreset == .human {
                return makeHuman(scale: scale)
            }
            return makeSubjectBlock(scale: scale)
        case .prop:
            switch assetPreset {
            case .chair:
                return makeChair(scale: scale)
            case .table:
                return makeTable(scale: scale)
            case .sofa:
                return makeSofa(scale: scale)
            default:
                return makePropBox(scale: scale)
            }
        case .frame:
            return nil
        case .light:
            let mesh = MeshResource.generateSphere(radius: 0.12 * scale)
            let material = SimpleMaterial(color: colorTemperature.uiColor, isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position.y = 1.35 * scale
            return entity
        }
    }

    private func makeBundledAssetEntity(for assetPreset: AssetPreset, scale: Float) -> ModelEntity? {
        guard let modelURL = bundledModelURL(for: assetPreset) else {
            return nil
        }

        do {
            let model = try Entity.load(contentsOf: modelURL)
            let proxy = collisionProxyEntity(for: assetPreset, scale: scale)
            model.scale = SIMD3<Float>(repeating: scale)
            alignBundledModelToGround(model, assetPreset: assetPreset, scale: scale)
            proxy.addChild(model)
            proxy.position.y = baseHeightOffset(for: assetPreset, scale: scale)
            return proxy
        } catch {
            return nil
        }
    }

    private func bundledModelURL(for assetPreset: AssetPreset) -> URL? {
        guard let modelName = assetPreset.bundleModelName else {
            return nil
        }

        if let url = Bundle.main.url(forResource: modelName, withExtension: "usdz", subdirectory: "Assets3D") {
            return url
        }

        return Bundle.main.url(forResource: modelName, withExtension: "usdz")
    }

    private func alignBundledModelToGround(_ model: Entity, assetPreset: AssetPreset, scale: Float) {
        let bounds = model.visualBounds(relativeTo: model)
        let localGroundY = -baseHeightOffset(for: assetPreset, scale: scale)
        model.position.y = localGroundY - bounds.min.y * scale
    }

    private func collisionProxyEntity(for assetPreset: AssetPreset, scale: Float) -> ModelEntity {
        let size = proxySize(for: assetPreset, scale: scale)
        let mesh = MeshResource.generateBox(width: size.x, height: size.y, depth: size.z)
        let material = SimpleMaterial(color: UIColor.white.withAlphaComponent(0.001), isMetallic: false)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private func proxySize(for assetPreset: AssetPreset, scale: Float) -> SIMD3<Float> {
        switch assetPreset {
        case .subjectBlock:
            SIMD3<Float>(0.28 * scale, 1.65 * scale, 0.28 * scale)
        case .human:
            SIMD3<Float>(0.58 * scale, 1.75 * scale, 0.28 * scale)
        case .propBox:
            SIMD3<Float>(0.45 * scale, 0.35 * scale, 0.45 * scale)
        case .chair:
            SIMD3<Float>(0.50 * scale, 0.90 * scale, 0.50 * scale)
        case .table:
            SIMD3<Float>(0.88 * scale, 0.76 * scale, 0.58 * scale)
        case .sofa:
            SIMD3<Float>(1.15 * scale, 0.75 * scale, 0.55 * scale)
        case .lampStand:
            SIMD3<Float>(0.24 * scale, 1.45 * scale, 0.24 * scale)
        }
    }

    private func makeSubjectBlock(scale: Float) -> ModelEntity {
        let width = 0.28 * scale
        let height = 1.65 * scale
        let depth = 0.28 * scale
        let entity = makeBox(
            width: width,
            height: height,
            depth: depth,
            color: UIColor.systemBlue.withAlphaComponent(0.72)
        )
        entity.position.y = height / 2
        return entity
    }

    private func makeHuman(scale: Float) -> ModelEntity {
        let root = makeBox(
            width: 0.34 * scale,
            height: 1.05 * scale,
            depth: 0.22 * scale,
            color: UIColor.systemBlue.withAlphaComponent(0.68)
        )
        root.position.y = 0.82 * scale

        let head = ModelEntity(
            mesh: MeshResource.generateSphere(radius: 0.17 * scale),
            materials: [SimpleMaterial(color: UIColor.systemCyan.withAlphaComponent(0.74), isMetallic: false)]
        )
        head.position.y = 0.68 * scale
        root.addChild(head)

        let shoulder = makeBox(
            width: 0.58 * scale,
            height: 0.08 * scale,
            depth: 0.16 * scale,
            color: UIColor.systemBlue.withAlphaComponent(0.5)
        )
        shoulder.position.y = 0.44 * scale
        root.addChild(shoulder)

        return root
    }

    private func makePropBox(scale: Float) -> ModelEntity {
        let width = 0.45 * scale
        let height = 0.35 * scale
        let depth = 0.45 * scale
        let entity = makeBox(
            width: width,
            height: height,
            depth: depth,
            color: UIColor.systemGray.withAlphaComponent(0.82)
        )
        entity.position.y = height / 2
        return entity
    }

    private func makeChair(scale: Float) -> ModelEntity {
        let root = makeBox(
            width: 0.46 * scale,
            height: 0.10 * scale,
            depth: 0.46 * scale,
            color: UIColor.systemGray3.withAlphaComponent(0.86)
        )
        root.position.y = 0.45 * scale

        let back = makeBox(
            width: 0.46 * scale,
            height: 0.62 * scale,
            depth: 0.08 * scale,
            color: UIColor.systemGray2.withAlphaComponent(0.82)
        )
        back.position = SIMD3<Float>(0, 0.30 * scale, 0.19 * scale)
        root.addChild(back)

        addLegs(to: root, scale: scale, x: 0.17, z: 0.17, height: 0.40, color: UIColor.systemGray)
        return root
    }

    private func makeTable(scale: Float) -> ModelEntity {
        let root = makeBox(
            width: 0.85 * scale,
            height: 0.08 * scale,
            depth: 0.56 * scale,
            color: UIColor.systemBrown.withAlphaComponent(0.82)
        )
        root.position.y = 0.72 * scale

        addLegs(to: root, scale: scale, x: 0.34, z: 0.20, height: 0.68, color: UIColor.systemBrown)
        return root
    }

    private func makeSofa(scale: Float) -> ModelEntity {
        let root = makeBox(
            width: 1.05 * scale,
            height: 0.26 * scale,
            depth: 0.45 * scale,
            color: UIColor.systemTeal.withAlphaComponent(0.72)
        )
        root.position.y = 0.27 * scale

        let back = makeBox(
            width: 1.05 * scale,
            height: 0.48 * scale,
            depth: 0.10 * scale,
            color: UIColor.systemTeal.withAlphaComponent(0.62)
        )
        back.position = SIMD3<Float>(0, 0.25 * scale, 0.22 * scale)
        root.addChild(back)

        for xOffset in [-0.57 * scale, 0.57 * scale] {
            let arm = makeBox(
                width: 0.10 * scale,
                height: 0.36 * scale,
                depth: 0.48 * scale,
                color: UIColor.systemTeal.withAlphaComponent(0.66)
            )
            arm.position = SIMD3<Float>(xOffset, 0.08 * scale, 0)
            root.addChild(arm)
        }

        return root
    }

    private func addLegs(
        to root: ModelEntity,
        scale: Float,
        x: Float,
        z: Float,
        height: Float,
        color: UIColor
    ) {
        for xOffset in [-x * scale, x * scale] {
            for zOffset in [-z * scale, z * scale] {
                let leg = makeBox(
                    width: 0.045 * scale,
                    height: height * scale,
                    depth: 0.045 * scale,
                    color: color.withAlphaComponent(0.78)
                )
                leg.position = SIMD3<Float>(xOffset, -(height * scale) / 2, zOffset)
                root.addChild(leg)
            }
        }
    }

    private func makeBox(width: Float, height: Float, depth: Float, color: UIColor) -> ModelEntity {
        let mesh = MeshResource.generateBox(width: width, height: height, depth: depth)
        let material = SimpleMaterial(color: color, isMetallic: false)
        return ModelEntity(mesh: mesh, materials: [material])
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

    private func updateActiveObjectScale() {
        guard let placedObject = activePlacedObject() else {
            return
        }

        let newScale = Float(objectScale)
        let relativeScale = max(0.01, newScale / placedObject.initialScale)
        placedObject.entity.scale = SIMD3<Float>(repeating: relativeScale)
        placedObject.entity.position.y = baseHeightOffset(for: placedObject, scale: newScale)

        syncRecord(for: placedObject)

        statusText = "\(selectedTool.rawValue) size \(Int(objectScale * 100))%"
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

    private func baseHeightOffset(for tool: SceneTool, scale: Float) -> Float {
        switch tool {
        case .subject:
            (1.65 * scale) / 2
        case .prop:
            (0.35 * scale) / 2
        case .frame:
            0
        case .light:
            1.35 * scale
        }
    }

    private func baseHeightOffset(for placedObject: PlacedObject, scale: Float) -> Float {
        if let assetPreset = placedObject.assetPreset {
            return baseHeightOffset(for: assetPreset, scale: scale)
        }
        return baseHeightOffset(for: placedObject.tool, scale: scale)
    }

    private func baseHeightOffset(for assetPreset: AssetPreset, scale: Float) -> Float {
        switch assetPreset {
        case .subjectBlock:
            (1.65 * scale) / 2
        case .human:
            0.82 * scale
        case .propBox:
            (0.35 * scale) / 2
        case .chair:
            0.45 * scale
        case .table:
            0.72 * scale
        case .sofa:
            0.27 * scale
        case .lampStand:
            1.35 * scale
        }
    }

    private func currentAssetPreset(for tool: SceneTool) -> AssetPreset? {
        switch tool {
        case .subject, .prop, .light:
            assetPreset(for: tool)
        case .frame:
            nil
        }
    }

    private func record(
        for tool: SceneTool,
        assetPreset: AssetPreset?,
        worldPosition: SIMD3<Float>,
        scale: Float
    ) -> SceneObjectRecord {
        let origin = layoutOriginPosition ?? worldPosition
        let relative = worldPosition - origin
        return SceneObjectRecord(
            type: tool,
            assetPreset: assetPreset,
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

    private func installDirectManipulationGesturesIfNeeded(for entity: ModelEntity, tool: SceneTool, in arView: ARView) {
        guard tool == .subject || tool == .prop else { return }
        arView.installGestures([.translation, .rotation, .scale], for: entity)
    }

    private func selectPlacedObject(containing entity: Entity) -> Bool {
        guard let placedObject = placedObjects.first(where: { isEntity(entity, containedIn: $0.entity) }) else {
            return false
        }

        selectPlacedObject(id: placedObject.id)
        return true
    }

    private func selectPlacedObject(id: UUID) {
        guard let placedObject = placedObjects.first(where: { $0.id == id }) else { return }

        selectedObjectID = id
        selectedTool = placedObject.tool
        syncRecord(for: placedObject)

        if let assetPreset = placedObject.assetPreset {
            switch placedObject.tool {
            case .subject:
                subjectAssetPreset = assetPreset
            case .prop:
                propAssetPreset = assetPreset
            case .light, .frame:
                break
            }
        }

        isUpdatingObjectScaleFromSelection = true
        objectScale = Double(currentScale(for: placedObject))
        isUpdatingObjectScaleFromSelection = false

        statusText = "\(placedObject.tool.rawValue) selected"
    }

    private func activePlacedObject() -> PlacedObject? {
        if let selectedObjectID,
           let selected = placedObjects.first(where: { $0.id == selectedObjectID }) {
            return selected
        }

        return nil
    }

    private func isEntity(_ entity: Entity, containedIn root: Entity) -> Bool {
        var current: Entity? = entity
        while let candidate = current {
            if candidate === root {
                return true
            }
            current = candidate.parent
        }
        return false
    }

    private func syncRecordsFromPlacedObjects() {
        for placedObject in placedObjects {
            syncRecord(for: placedObject)
        }
    }

    private func syncRecord(for placedObject: PlacedObject) {
        guard let index = records.firstIndex(where: { $0.id == placedObject.id }) else { return }

        let scale = currentScale(for: placedObject)
        var worldPosition = placedObject.entity.position(relativeTo: nil)
        worldPosition.y -= baseHeightOffset(for: placedObject, scale: scale)

        let origin = layoutOriginPosition ?? worldPosition
        let relative = worldPosition - origin

        records[index].relativeX = relative.x
        records[index].relativeY = relative.y
        records[index].relativeZ = relative.z
        records[index].scale = scale
        records[index].yaw = yawAngle(from: placedObject.entity.orientation(relativeTo: nil))
    }

    private func currentScale(for placedObject: PlacedObject) -> Float {
        placedObject.initialScale * placedObject.entity.scale.x
    }

    private func yawAngle(from orientation: simd_quatf) -> Float {
        let matrix = simd_float3x3(orientation)
        return atan2(matrix.columns.0.z, matrix.columns.0.x)
    }
}

enum CaptureError: Error {
    case snapshotFailed
}

private struct PlacedObject {
    let id: UUID
    let tool: SceneTool
    let assetPreset: AssetPreset?
    let entity: ModelEntity
    let initialScale: Float
}
