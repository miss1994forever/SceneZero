import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var controller = ARSceneController()
    @State private var showsLookbook = false
    @State private var alertMessage: String?
    @State private var isControlPanelVisible = false
    @State private var activeAdjustment: CaptureAdjustment?

    private let filterService = FilterService()
    private let imageStorage = ImageStorageService()
    private let framingOverlayService = FramingOverlayService()
    private let lightingOverlayService = LightingOverlayService()

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            ZStack {
                ARViewContainer(controller: controller)
                    .ignoresSafeArea()

                LightingOverlayView(
                    lightPreset: controller.lightPreset,
                    colorTemperature: controller.colorTemperature,
                    intensity: controller.lightIntensity,
                    radius: controller.lightRadius,
                    isVisible: controller.hasLightingOverlay
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                FramingOverlayView(
                    aspectRatio: controller.frameAspectRatio,
                    shotType: controller.shotType,
                    lensPreset: controller.lensPreset,
                    showsGuides: controller.showsCompositionGuides
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                controlsOverlay(
                    size: proxy.size,
                    safeAreaInsets: proxy.safeAreaInsets,
                    isLandscape: isLandscape
                )
            }
            .onAppear {
                isControlPanelVisible = false
            }
            .onChange(of: isLandscape) { _, newValue in
                withAnimation(.snappy(duration: 0.24)) {
                    isControlPanelVisible = false
                    activeAdjustment = nil
                }
            }
        }
        .sheet(isPresented: $showsLookbook) {
            LookbookView()
        }
        .alert("SceneZero", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .onChange(of: controller.selectedTool) { _, _ in
            dismissAdjustment()
        }
    }

    private func controlsOverlay(
        size: CGSize,
        safeAreaInsets: EdgeInsets,
        isLandscape: Bool
    ) -> some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                topBar(isCompact: size.width < 430)
                Spacer()
                if isControlPanelVisible {
                    ControlPanelView(
                        controller: controller,
                        onHide: hideControls
                    )
                    .frame(maxWidth: isLandscape ? 460 : .infinity)
                    .frame(height: controlPanelHeight(isLandscape: isLandscape))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            cameraControls(
                availableWidth: size.width,
                safeAreaInsets: safeAreaInsets,
                isLandscape: isLandscape
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, captureButtonBottomPadding(isLandscape: isLandscape))
        }
        .animation(.snappy(duration: 0.24), value: isControlPanelVisible)
    }

    private func controlPanelHeight(isLandscape: Bool) -> CGFloat {
        isLandscape ? 164 : 238
    }

    private func captureButtonBottomPadding(isLandscape: Bool) -> CGFloat {
        isControlPanelVisible ? controlPanelHeight(isLandscape: isLandscape) + 22 : 24
    }

    private func cameraControls(
        availableWidth: CGFloat,
        safeAreaInsets: EdgeInsets,
        isLandscape: Bool
    ) -> some View {
        let horizontalPadding: CGFloat = isLandscape ? 18 : 12
        let spacing: CGFloat = isLandscape ? 16 : 12
        let shutterSize: CGFloat = isCompactWidth(availableWidth) ? 64 : 72
        let sideWidth = controlSideWidth(
            availableWidth: availableWidth,
            horizontalPadding: horizontalPadding,
            spacing: spacing,
            shutterSize: shutterSize,
            isLandscape: isLandscape
        )

        return HStack(spacing: spacing) {
            ToolModePicker(
                selectedTool: $controller.selectedTool,
                onTap: dismissAdjustment,
                displayWidth: sideWidth
            )
            .frame(width: sideWidth, alignment: .trailing)

            ShutterButton(
                isCapturing: controller.isCapturing,
                size: shutterSize,
                action: captureAndSave
            )

            AdjustmentButtonCluster(
                controller: controller,
                activeAdjustment: $activeAdjustment,
                maxWidth: sideWidth,
                onReset: {
                    controller.resetSelectedObjectScale()
                }
            )
            .frame(width: sideWidth, alignment: .leading)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 6)
        .padding(.bottom, max(0, safeAreaInsets.bottom - 6))
    }

    private func isCompactWidth(_ width: CGFloat) -> Bool {
        width < 390
    }

    private func controlSideWidth(
        availableWidth: CGFloat,
        horizontalPadding: CGFloat,
        spacing: CGFloat,
        shutterSize: CGFloat,
        isLandscape: Bool
    ) -> CGFloat {
        let rawWidth = (availableWidth - horizontalPadding * 2 - spacing * 2 - shutterSize) / 2
        let maxWidth: CGFloat = isLandscape ? 320 : 156
        return max(94, min(maxWidth, rawWidth))
    }

    private func topBar(isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 8 : 12) {
            Label(controller.statusText, systemImage: controller.isCapturing ? "camera.aperture" : "arkit")
                .font((isCompact ? Font.caption : Font.footnote).weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                showsLookbook = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                    .frame(width: isCompact ? 30 : 32, height: isCompact ? 30 : 32)
                    .liquidGlassCircle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Lookbook")

            Button {
                controller.resetScene()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                    .frame(width: isCompact ? 30 : 32, height: isCompact ? 30 : 32)
                    .liquidGlassCircle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset scene")

            Button {
                showControls()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                    .frame(width: isCompact ? 30 : 32, height: isCompact ? 30 : 32)
                    .liquidGlassCircle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Advanced controls")
        }
        .padding(.horizontal, isCompact ? 12 : 16)
        .padding(.vertical, isCompact ? 8 : 10)
        .liquidGlassCapsule(material: .regularMaterial, shadowOpacity: 0.16)
        .padding(.horizontal, isCompact ? 10 : 16)
        .padding(.top, 12)
    }

    private func showControls() {
        withAnimation(.snappy(duration: 0.24)) {
            isControlPanelVisible = true
        }
    }

    private func hideControls() {
        withAnimation(.snappy(duration: 0.24)) {
            isControlPanelVisible = false
        }
    }

    private func dismissAdjustment() {
        withAnimation(.snappy(duration: 0.2)) {
            activeAdjustment = nil
        }
    }

    private func captureAndSave() {
        controller.capture { result in
            switch result {
            case .success(let captured):
                let framedImage = framingOverlayService.applyOverlay(
                    to: captured.image,
                    aspectRatio: captured.frameAspectRatio,
                    shotType: captured.shotType,
                    lensPreset: captured.lensPreset,
                    showsGuides: captured.showsCompositionGuides
                )
                let litImage = lightingOverlayService.applyOverlay(
                    to: framedImage,
                    lightPreset: captured.lightPreset,
                    colorTemperature: captured.colorTemperature,
                    intensity: captured.lightIntensity,
                    radius: captured.lightRadius,
                    isEnabled: captured.shouldRenderLightingOverlay
                )
                let filteredImage = filterService.apply(captured.filterPreset, to: litImage)
                do {
                    let imagePath = try imageStorage.save(filteredImage)
                    let layoutData = try JSONEncoder().encode(captured.layoutRecords)
                    let layoutJSON = String(data: layoutData, encoding: .utf8) ?? "[]"
                    let entry = LookbookEntry(
                        title: "Scene \(Date().formatted(date: .numeric, time: .shortened))",
                        imagePath: imagePath,
                        prompt: captured.prompt,
                        shotType: captured.shotType.rawValue,
                        lightPreset: captured.lightPreset.rawValue,
                        colorTemperature: captured.colorTemperature.rawValue,
                        lightIntensity: captured.lightIntensity,
                        lightRadius: captured.lightRadius,
                        frameAspectRatio: captured.frameAspectRatio.rawValue,
                        lensPreset: captured.lensPreset.rawValue,
                        showsCompositionGuides: captured.showsCompositionGuides,
                        filterName: captured.filterPreset.rawValue,
                        layoutJSON: layoutJSON
                    )
                    modelContext.insert(entry)
                    try modelContext.save()
                    alertMessage = "Saved to Lookbook."
                } catch {
                    alertMessage = "Could not save this capture. \(error.localizedDescription)"
                }
            case .failure:
                alertMessage = "Capture failed. Try scanning a surface again."
            }
        }
    }
}

#Preview {
    MainView()
        .modelContainer(for: LookbookEntry.self, inMemory: true)
}

private struct ShutterButton: View {
    let isCapturing: Bool
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.86), lineWidth: 4)
                    .frame(width: size, height: size)
                    .shadow(color: .white.opacity(0.22), radius: 2, x: -1, y: -1)

                Circle()
                    .fill(.white.opacity(0.92))
                    .frame(
                        width: isCapturing ? size * 0.67 : size * 0.80,
                        height: isCapturing ? size * 0.67 : size * 0.80
                    )
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.8), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)

                if isCapturing {
                    ProgressView()
                        .tint(.black.opacity(0.72))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
        .accessibilityLabel(isCapturing ? "Capturing" : "Capture")
    }
}

private enum CaptureAdjustment: String, Identifiable, Equatable {
    case asset = "Asset"
    case reset = "Reset"
    case frame = "Frame"
    case lens = "Lens"
    case shot = "Shot"
    case guides = "Guides"
    case direction = "Direction"
    case color = "Color"
    case intensity = "Intensity"
    case spread = "Spread"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .asset: "square.grid.2x2"
        case .reset: "arrow.counterclockwise"
        case .frame: "rectangle.on.rectangle"
        case .lens: "camera.aperture"
        case .shot: "viewfinder"
        case .guides: "grid"
        case .direction: "light.beacon.max"
        case .color: "thermometer.sun"
        case .intensity: "sun.max"
        case .spread: "circle.dotted"
        }
    }

    static func items(for tool: SceneTool) -> [CaptureAdjustment] {
        switch tool {
        case .subject, .prop:
            [.asset, .reset]
        case .frame:
            [.frame, .lens, .shot, .guides]
        case .light:
            [.direction, .color, .intensity, .spread]
        }
    }
}

private struct AdjustmentButtonCluster: View {
    @ObservedObject var controller: ARSceneController
    @Binding var activeAdjustment: CaptureAdjustment?
    let maxWidth: CGFloat
    let onReset: () -> Void

    var body: some View {
        Group {
            if let activeAdjustment {
                InlineAdjustmentCapsule(
                    adjustment: activeAdjustment,
                    controller: controller,
                    maxWidth: maxWidth,
                    onClose: closeAdjustment
                )
                .transition(.scale(scale: 0.94, anchor: .leading).combined(with: .opacity))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CaptureAdjustment.items(for: controller.selectedTool)) { adjustment in
                            Button {
                                handleSelection(adjustment)
                            } label: {
                                Image(systemName: adjustment.systemImage)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 38)
                                    .liquidGlassCircle()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(adjustment.rawValue)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .frame(width: maxWidth)
                .clipShape(Capsule())
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .liquidGlassCapsule()
                .transition(.scale(scale: 0.94, anchor: .leading).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.22), value: activeAdjustment)
    }

    private func handleSelection(_ adjustment: CaptureAdjustment) {
        switch adjustment {
        case .reset:
            onReset()
        case .guides:
            controller.showsCompositionGuides.toggle()
        default:
            activeAdjustment = adjustment
        }
    }

    private func closeAdjustment() {
        activeAdjustment = nil
    }
}

private struct InlineAdjustmentCapsule: View {
    let adjustment: CaptureAdjustment
    @ObservedObject var controller: ARSceneController
    let maxWidth: CGFloat
    let onClose: () -> Void

    private var contentWidth: CGFloat {
        max(64, maxWidth - 72)
    }

    var body: some View {
        let iconSize: CGFloat = 36

        HStack(spacing: 8) {
            Button(action: onClose) {
                Image(systemName: adjustment.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: iconSize, height: iconSize)
                    .liquidGlassCircle(isSelected: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close \(adjustment.rawValue)")

            Divider()
                .frame(height: 26)
                .overlay(.white.opacity(0.24))

            content
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(width: maxWidth, alignment: .leading)
        .liquidGlassCapsule()
    }

    @ViewBuilder
    private var content: some View {
        switch adjustment {
        case .asset:
            assetOptions
        case .frame:
            optionChips(FrameAspectRatio.allCases, selection: $controller.frameAspectRatio)
        case .lens:
            optionChips(LensPreset.allCases, selection: $controller.lensPreset)
        case .shot:
            optionChips(ShotType.allCases, selection: $controller.shotType)
        case .direction:
            optionChips(LightPreset.allCases, selection: $controller.lightPreset)
        case .color:
            optionChips(ColorTemperature.allCases, selection: $controller.colorTemperature)
        case .intensity:
            sliderControl(value: $controller.lightIntensity, range: 0.1...1.0)
        case .spread:
            sliderControl(value: $controller.lightRadius, range: 0.2...1.0)
        case .reset, .guides:
            EmptyView()
        }
    }

    private var assetOptions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(AssetPreset.presets(for: controller.selectedTool)) { preset in
                    Button {
                        controller.setAssetPreset(preset, for: controller.selectedTool)
                        onClose()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: preset.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                            Text(shortTitle(for: preset.rawValue))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .liquidGlassChip(isSelected: isSelected(preset))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(width: contentWidth)
        .clipShape(Capsule())
    }

    private func optionChips<Option: Identifiable & RawRepresentable & Hashable>(
        _ options: [Option],
        selection: Binding<Option>
    ) -> some View where Option.RawValue == String {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    Button {
                        selection.wrappedValue = option
                        onClose()
                    } label: {
                        Text(option.rawValue)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 11)
                            .frame(height: 34)
                            .liquidGlassChip(isSelected: selection.wrappedValue == option)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(width: contentWidth)
        .clipShape(Capsule())
    }

    private func sliderControl(value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 10) {
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, alignment: .leading)

            Slider(value: value, in: range, step: 0.05)
                .frame(width: max(52, contentWidth - 50))
        }
        .frame(width: contentWidth, alignment: .leading)
    }

    private func isSelected(_ preset: AssetPreset) -> Bool {
        controller.assetPreset(for: controller.selectedTool) == preset
    }

    private func shortTitle(for title: String) -> String {
        title
            .replacingOccurrences(of: "Subject ", with: "")
            .replacingOccurrences(of: "Prop ", with: "")
    }
}

private struct ToolModePicker: View {
    @Binding var selectedTool: SceneTool
    let onTap: () -> Void
    let displayWidth: CGFloat

    @State private var dragTranslation: CGFloat = 0
    @State private var dragStartIndex: Int?
    @State private var previewIndex: Int?

    private let tools = SceneTool.allCases
    private let itemSize: CGFloat = 38
    private let itemSpacing: CGFloat = 44
    private let dragDamping: CGFloat = 0.62

    var body: some View {
        ZStack {
            Capsule()
                .frame(width: 50, height: 50)
                .liquidGlassCapsule()

            HStack(spacing: itemSpacing - itemSize) {
                ForEach(tools) { tool in
                    toolIcon(tool)
                }
            }
            .offset(x: pickerOffset)
        }
        .frame(width: displayWidth, height: 58)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .gesture(toolSelectionGesture)
        .animation(.smooth(duration: 0.14), value: previewIndex)
        .animation(.snappy(duration: 0.2), value: selectedTool)
    }

    private var selectedIndex: Int {
        tools.firstIndex(of: selectedTool) ?? 0
    }

    private var activeIndex: Int {
        previewIndex ?? selectedIndex
    }

    private var pickerOffset: CGFloat {
        let baseIndex = dragStartIndex ?? selectedIndex
        let centerCorrection = CGFloat(tools.count - 1) * itemSpacing / 2
        return centerCorrection - CGFloat(baseIndex) * itemSpacing + dragTranslation
    }

    private var toolSelectionGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let startIndex = dragStartIndex ?? selectedIndex
                dragStartIndex = startIndex
                let dampedTranslation = value.translation.width * dragDamping
                let clampedTranslation = clampedTranslation(dampedTranslation, startingAt: startIndex)
                dragTranslation = clampedTranslation
                previewIndex = index(startingAt: startIndex, translation: clampedTranslation)
            }
            .onEnded { _ in
                if let previewIndex {
                    selectedTool = tools[previewIndex]
                }
                dragStartIndex = nil
                previewIndex = nil
                dragTranslation = 0
            }
    }

    private func index(startingAt startIndex: Int, translation: CGFloat) -> Int {
        let proposedIndex = CGFloat(startIndex) - translation / itemSpacing
        return min(
            tools.count - 1,
            max(0, Int(round(proposedIndex)))
        )
    }

    private func clampedTranslation(_ translation: CGFloat, startingAt startIndex: Int) -> CGFloat {
        let minTranslation = CGFloat(startIndex - (tools.count - 1)) * itemSpacing
        let maxTranslation = CGFloat(startIndex) * itemSpacing
        return min(max(translation, minTranslation), maxTranslation)
    }

    private func toolIcon(_ tool: SceneTool) -> some View {
        let isActive = tools[activeIndex] == tool

        return Image(systemName: tool.systemImage)
            .font(.system(size: isActive ? 20 : 17, weight: .semibold))
            .foregroundStyle(isActive ? .white : .primary)
            .frame(width: itemSize, height: itemSize)
            .background(
                Circle()
                    .fill(isActive ? Color.accentColor : Color.clear)
            )
            .accessibilityLabel("Select \(tool.rawValue)")
    }
}
