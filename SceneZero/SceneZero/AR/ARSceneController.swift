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

        let results = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal)
        guard let result = results.first else {
            statusText = "Find a horizontal surface"
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
        if entity.components[CollisionComponent.self] == nil {
            entity.generateCollisionShapes(recursive: true)
        }
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
            case .desk, .bookcase, .bed, .nightStand:
                return makePropBox(scale: scale)
            default:
                return makePropBox(scale: scale)
            }
        case .frame:
            return nil
        case .light:
            return makeLampStand(scale: scale)
        }
    }

    private func makeBundledAssetEntity(for assetPreset: AssetPreset, scale: Float) -> ModelEntity? {
        guard let modelURL = bundledModelURL(for: assetPreset) else {
            return nil
        }

        do {
            let model = try Entity.load(contentsOf: modelURL)
            let proxy = collisionProxyEntity(for: assetPreset, scale: scale)
            let unscaledBounds = model.visualBounds(relativeTo: model)
            let modelScale = normalizedModelScale(
                for: unscaledBounds,
                assetPreset: assetPreset,
                scale: scale
            )
            model.scale = SIMD3<Float>(repeating: modelScale)
            alignBundledModelToGround(
                model,
                bounds: unscaledBounds,
                assetPreset: assetPreset,
                scale: scale,
                modelScale: modelScale
            )
            proxy.model = nil
            proxy.addChild(model)
            configureCollisionProxy(proxy, for: model, assetPreset: assetPreset, scale: scale)
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

    private func normalizedModelScale(
        for bounds: BoundingBox,
        assetPreset: AssetPreset,
        scale: Float
    ) -> Float {
        let dimensions = bounds.max - bounds.min
        let targetSize = proxySize(for: assetPreset, scale: scale) * 0.9
        let validRatios = [
            dimensions.x > 0 ? targetSize.x / dimensions.x : nil,
            dimensions.y > 0 ? targetSize.y / dimensions.y : nil,
            dimensions.z > 0 ? targetSize.z / dimensions.z : nil
        ].compactMap { $0 }

        guard let ratio = validRatios.min(), ratio.isFinite, ratio > 0 else {
            return scale
        }

        return ratio
    }

    private func alignBundledModelToGround(
        _ model: Entity,
        bounds: BoundingBox,
        assetPreset: AssetPreset,
        scale: Float,
        modelScale: Float
    ) {
        let localGroundY = -baseHeightOffset(for: assetPreset, scale: scale)
        model.position.y = localGroundY - bounds.min.y * modelScale
    }

    private func collisionProxyEntity(for assetPreset: AssetPreset, scale: Float) -> ModelEntity {
        let size = proxySize(for: assetPreset, scale: scale)
        let mesh = MeshResource.generateBox(width: size.x, height: size.y, depth: size.z)
        let material = SimpleMaterial(color: UIColor.white.withAlphaComponent(0.001), isMetallic: false)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private func configureCollisionProxy(
        _ proxy: ModelEntity,
        for model: Entity,
        assetPreset: AssetPreset,
        scale: Float
    ) {
        let bounds = model.visualBounds(relativeTo: proxy)
        let dimensions = bounds.max - bounds.min
        let minimumSize = proxySize(for: assetPreset, scale: scale) * 0.35
        let paddedSize = SIMD3<Float>(
            max(minimumSize.x, dimensions.x * 0.92),
            max(minimumSize.y, dimensions.y * 0.92),
            max(minimumSize.z, dimensions.z * 0.92)
        )
        let center = (bounds.min + bounds.max) / 2

        proxy.collision = CollisionComponent(shapes: [
            ShapeResource.generateBox(size: paddedSize).offsetBy(translation: center)
        ])
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
        case .desk:
            SIMD3<Float>(1.15 * scale, 0.72 * scale, 0.55 * scale)
        case .bookcase:
            SIMD3<Float>(0.85 * scale, 1.55 * scale, 0.35 * scale)
        case .bed:
            SIMD3<Float>(1.35 * scale, 0.55 * scale, 1.8 * scale)
        case .nightStand:
            SIMD3<Float>(0.48 * scale, 0.50 * scale, 0.48 * scale)
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
            color: UIColor(red: 0.10, green: 0.36, blue: 0.74, alpha: 1.0)
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
        let frameColor = UIColor(red: 0.52, green: 0.39, blue: 0.27, alpha: 0.96)
        let cushionColor = UIColor(red: 0.84, green: 0.88, blue: 0.90, alpha: 0.96)
        let accentColor = UIColor(red: 0.37, green: 0.50, blue: 0.58, alpha: 0.95)
        let root = makeBox(
            width: 0.50 * scale,
            height: 0.08 * scale,
            depth: 0.48 * scale,
            color: frameColor
        )
        root.position.y = 0.45 * scale

        let cushion = makeBox(
            width: 0.46 * scale,
            height: 0.08 * scale,
            depth: 0.42 * scale,
            color: cushionColor
        )
        cushion.position = SIMD3<Float>(0, 0.06 * scale, -0.02 * scale)
        root.addChild(cushion)

        let back = makeBox(
            width: 0.50 * scale,
            height: 0.10 * scale,
            depth: 0.06 * scale,
            color: frameColor
        )
        back.position = SIMD3<Float>(0, 0.56 * scale, 0.21 * scale)
        root.addChild(back)

        let backPanel = makeBox(
            width: 0.42 * scale,
            height: 0.42 * scale,
            depth: 0.055 * scale,
            color: accentColor
        )
        backPanel.position = SIMD3<Float>(0, 0.34 * scale, 0.21 * scale)
        root.addChild(backPanel)

        for xOffset in [-0.18 * scale, 0.18 * scale] {
            let upright = makeBox(
                width: 0.055 * scale,
                height: 0.58 * scale,
                depth: 0.055 * scale,
                color: frameColor
            )
            upright.position = SIMD3<Float>(xOffset, 0.28 * scale, 0.21 * scale)
            root.addChild(upright)
        }

        addLegs(to: root, scale: scale, x: 0.18, z: 0.16, height: 0.42, color: frameColor)
        addCrossbar(to: root, scale: scale, x: 0, y: -0.26, z: 0.18, width: 0.44, depth: 0.035, color: frameColor)
        return root
    }

    private func makeTable(scale: Float) -> ModelEntity {
        let woodColor = UIColor(red: 0.56, green: 0.37, blue: 0.22, alpha: 0.96)
        let topColor = UIColor(red: 0.66, green: 0.47, blue: 0.31, alpha: 0.96)
        let darkWoodColor = UIColor(red: 0.38, green: 0.25, blue: 0.16, alpha: 0.94)
        let root = makeBox(
            width: 0.92 * scale,
            height: 0.08 * scale,
            depth: 0.60 * scale,
            color: topColor
        )
        root.position.y = 0.72 * scale

        let topInset = makeBox(
            width: 0.78 * scale,
            height: 0.025 * scale,
            depth: 0.46 * scale,
            color: UIColor(red: 0.74, green: 0.56, blue: 0.39, alpha: 0.96)
        )
        topInset.position = SIMD3<Float>(0, 0.055 * scale, 0)
        root.addChild(topInset)

        let apronFront = makeBox(width: 0.86 * scale, height: 0.08 * scale, depth: 0.035 * scale, color: darkWoodColor)
        apronFront.position = SIMD3<Float>(0, -0.08 * scale, -0.28 * scale)
        root.addChild(apronFront)

        let apronBack = makeBox(width: 0.86 * scale, height: 0.08 * scale, depth: 0.035 * scale, color: darkWoodColor)
        apronBack.position = SIMD3<Float>(0, -0.08 * scale, 0.28 * scale)
        root.addChild(apronBack)

        addLegs(to: root, scale: scale, x: 0.36, z: 0.22, height: 0.68, color: woodColor)
        addCrossbar(to: root, scale: scale, x: 0, y: -0.42, z: 0.22, width: 0.76, depth: 0.035, color: darkWoodColor)
        return root
    }

    private func makeSofa(scale: Float) -> ModelEntity {
        let baseColor = UIColor(red: 0.18, green: 0.48, blue: 0.54, alpha: 0.94)
        let cushionColor = UIColor(red: 0.34, green: 0.70, blue: 0.73, alpha: 0.95)
        let pillowColor = UIColor(red: 0.94, green: 0.74, blue: 0.48, alpha: 0.96)
        let root = makeBox(
            width: 1.16 * scale,
            height: 0.22 * scale,
            depth: 0.50 * scale,
            color: baseColor
        )
        root.position.y = 0.28 * scale

        for xOffset in [-0.30 * scale, 0.30 * scale] {
            let seat = makeBox(
                width: 0.52 * scale,
                height: 0.12 * scale,
                depth: 0.43 * scale,
                color: cushionColor
            )
            seat.position = SIMD3<Float>(xOffset, 0.13 * scale, -0.03 * scale)
            root.addChild(seat)
        }

        let back = makeBox(
            width: 1.16 * scale,
            height: 0.50 * scale,
            depth: 0.11 * scale,
            color: baseColor.withAlphaComponent(0.96)
        )
        back.position = SIMD3<Float>(0, 0.25 * scale, 0.22 * scale)
        root.addChild(back)

        for xOffset in [-0.30 * scale, 0.30 * scale] {
            let backCushion = makeBox(
                width: 0.48 * scale,
                height: 0.35 * scale,
                depth: 0.075 * scale,
                color: cushionColor.withAlphaComponent(0.92)
            )
            backCushion.position = SIMD3<Float>(xOffset, 0.28 * scale, 0.15 * scale)
            root.addChild(backCushion)
        }

        for xOffset in [-0.63 * scale, 0.63 * scale] {
            let arm = makeBox(
                width: 0.12 * scale,
                height: 0.40 * scale,
                depth: 0.52 * scale,
                color: baseColor.withAlphaComponent(0.96)
            )
            arm.position = SIMD3<Float>(xOffset, 0.10 * scale, 0)
            root.addChild(arm)
        }

        for xOffset in [-0.43 * scale, 0.43 * scale] {
            let pillow = makeBox(
                width: 0.18 * scale,
                height: 0.18 * scale,
                depth: 0.08 * scale,
                color: pillowColor
            )
            pillow.position = SIMD3<Float>(xOffset, 0.30 * scale, -0.12 * scale)
            root.addChild(pillow)
        }

        addLegs(to: root, scale: scale, x: 0.42, z: 0.18, height: 0.16, color: UIColor.darkGray.withAlphaComponent(0.78))
        return root
    }

    private func makeLampStand(scale: Float) -> ModelEntity {
        let lampColor = colorTemperature.uiColor.withAlphaComponent(0.92)
        let metalColor = UIColor.systemGray2.withAlphaComponent(0.86)
        let root = ModelEntity(
            mesh: MeshResource.generateSphere(radius: 0.13 * scale),
            materials: [SimpleMaterial(color: lampColor, isMetallic: false)]
        )
        root.position.y = 1.35 * scale

        let yOffsetToGround = -1.35 * scale
        let pole = makeBox(
            width: 0.035 * scale,
            height: 1.08 * scale,
            depth: 0.035 * scale,
            color: metalColor
        )
        pole.position = SIMD3<Float>(0, yOffsetToGround + 0.64 * scale, 0)
        root.addChild(pole)

        let base = makeBox(
            width: 0.36 * scale,
            height: 0.035 * scale,
            depth: 0.36 * scale,
            color: metalColor.withAlphaComponent(0.7)
        )
        base.position = SIMD3<Float>(0, yOffsetToGround + 0.03 * scale, 0)
        root.addChild(base)

        let yoke = makeBox(
            width: 0.28 * scale,
            height: 0.04 * scale,
            depth: 0.04 * scale,
            color: metalColor
        )
        yoke.position = SIMD3<Float>(0, -0.13 * scale, 0)
        root.addChild(yoke)

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

    private func addCrossbar(
        to root: ModelEntity,
        scale: Float,
        x: Float,
        y: Float,
        z: Float,
        width: Float,
        depth: Float,
        color: UIColor
    ) {
        let bar = makeBox(
            width: width * scale,
            height: 0.035 * scale,
            depth: depth * scale,
            color: color.withAlphaComponent(0.9)
        )
        bar.position = SIMD3<Float>(x * scale, y * scale, z * scale)
        root.addChild(bar)
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
        case .desk:
            0.72 * scale
        case .bookcase:
            0.78 * scale
        case .bed:
            0.28 * scale
        case .nightStand:
            0.25 * scale
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
        guard let placedObject = placedObjects.reversed().first(where: { isEntity(entity, containedIn: $0.entity) }) else {
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
