import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var controller = ARSceneController()
    @State private var showsLookbook = false
    @State private var alertMessage: String?
    @State private var activeAdjustment: CaptureAdjustment?

    private let filterService = FilterService()
    private let imageStorage = ImageStorageService()
    private let framingOverlayService = FramingOverlayService()
    private let lightingOverlayService = LightingOverlayService()

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let framingInsets = framingContentInsets(
                size: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
                isLandscape: isLandscape
            )

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
                    showsGuides: controller.showsCompositionGuides,
                    contentInsets: framingInsets
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                controlsOverlay(
                    size: proxy.size,
                    safeAreaInsets: proxy.safeAreaInsets,
                    isLandscape: isLandscape
                )
            }
            .onChange(of: isLandscape) { _, newValue in
                withAnimation(.snappy(duration: 0.24)) {
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
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                topBar(isCompact: size.width < 430)
                Spacer()
            }

            cameraControls(
                availableSize: size,
                safeAreaInsets: safeAreaInsets,
                isLandscape: isLandscape
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
    }

    private func cameraControls(
        availableSize: CGSize,
        safeAreaInsets: EdgeInsets,
        isLandscape: Bool
    ) -> some View {
        let trailingPadding: CGFloat = isLandscape ? 18 : 12
        let controlTrailingPadding = max(trailingPadding, safeAreaInsets.trailing + 8)
        let shutterToPickerSpacing: CGFloat = 18
        let adjustmentToShutterSpacing: CGFloat = 30
        let shutterSize: CGFloat = isCompactWidth(availableSize.width) ? 62 : 68
        let adjustmentButtonSize: CGFloat = 44
        let railWidth = controlRailWidth(availableSize: availableSize, isLandscape: isLandscape)
        let pickerHeight = toolPickerHeight(availableSize: availableSize, isLandscape: isLandscape)
        let adjustmentHeight = adjustmentButtonColumnHeight(for: controller.selectedTool)
        let adjustmentOffset = adjustmentColumnOffset(
            availableSize: availableSize,
            safeAreaInsets: safeAreaInsets,
            shutterSize: shutterSize,
            spacing: adjustmentToShutterSpacing,
            columnHeight: adjustmentHeight,
            isLandscape: isLandscape
        )

        return ZStack(alignment: .trailing) {
            AdjustmentButtonColumn(
                controller: controller,
                activeAdjustment: $activeAdjustment,
                maxWidth: railWidth,
                onReset: {
                    controller.resetSelectedObjectScale()
                }
            )
            .padding(.trailing, controlTrailingPadding + max(0, (shutterSize - adjustmentButtonSize) / 2))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .offset(y: adjustmentOffset)

            ShutterButton(
                isCapturing: controller.isCapturing,
                size: shutterSize,
                action: {
                    captureAndSave(
                        viewportSize: availableSize,
                        framingInsets: framingContentInsets(
                            size: availableSize,
                            safeAreaInsets: safeAreaInsets,
                            isLandscape: isLandscape
                        )
                    )
                }
            )
            .padding(.trailing, controlTrailingPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

            ToolModePicker(
                selectedTool: $controller.selectedTool,
                onTap: dismissAdjustment,
                displayHeight: pickerHeight
            )
            .frame(width: 64, height: pickerHeight, alignment: .center)
            .padding(.trailing, controlTrailingPadding + max(0, (shutterSize - 64) / 2))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .offset(y: shutterSize / 2 + shutterToPickerSpacing + pickerHeight / 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func isCompactWidth(_ width: CGFloat) -> Bool {
        width < 390
    }

    private func controlRailWidth(availableSize: CGSize, isLandscape: Bool) -> CGFloat {
        let screenLimitedWidth = availableSize.width * (isLandscape ? 0.30 : 0.52)
        let maxWidth: CGFloat = isLandscape ? 280 : 220
        return max(150, min(maxWidth, screenLimitedWidth))
    }

    private func toolPickerHeight(availableSize: CGSize, isLandscape: Bool) -> CGFloat {
        let maxHeight = availableSize.height * (isLandscape ? 0.32 : 0.30)
        let minimumHeight: CGFloat = isLandscape ? 132 : 178
        return max(minimumHeight, min(240, maxHeight))
    }

    private func framingContentInsets(
        size: CGSize,
        safeAreaInsets: EdgeInsets,
        isLandscape: Bool
    ) -> FramingSafeInsets {
        let trailingPadding = max(isLandscape ? 18 : 12, safeAreaInsets.trailing + 8)
        let shutterSize: CGFloat = isCompactWidth(size.width) ? 62 : 68
        let trailingReserve = trailingPadding + shutterSize + (isLandscape ? 32 : 26)
        let topReserve = max(safeAreaInsets.top + (isLandscape ? 54 : 64), isLandscape ? 58 : 76)
        let bottomReserve = max(safeAreaInsets.bottom + 12, isLandscape ? 14 : 24)

        return FramingSafeInsets(
            top: topReserve,
            leading: 12,
            bottom: bottomReserve,
            trailing: trailingReserve
        )
    }

    private func adjustmentButtonColumnHeight(for tool: SceneTool) -> CGFloat {
        let count = CGFloat(CaptureAdjustment.items(for: tool).count)
        let buttonSize: CGFloat = 44
        let spacing: CGFloat = 8
        return count * buttonSize + max(0, count - 1) * spacing
    }

    private func adjustmentColumnOffset(
        availableSize: CGSize,
        safeAreaInsets: EdgeInsets,
        shutterSize: CGFloat,
        spacing: CGFloat,
        columnHeight: CGFloat,
        isLandscape: Bool
    ) -> CGFloat {
        let idealOffset = -(shutterSize / 2 + spacing + columnHeight / 2)
        let topProtection = safeAreaInsets.top + (isLandscape ? 62 : 94)
        let centerY = availableSize.height / 2
        let minimumOffset = topProtection + columnHeight / 2 - centerY
        return max(idealOffset, minimumOffset)
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
                withAnimation(.snappy(duration: 0.2)) {
                    controller.showsCompositionGuides.toggle()
                }
            } label: {
                Image(systemName: controller.showsCompositionGuides ? "grid.circle.fill" : "grid.circle")
                    .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                    .frame(width: isCompact ? 30 : 32, height: isCompact ? 30 : 32)
                    .liquidGlassCircle(isSelected: controller.showsCompositionGuides)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Composition guides")
        }
        .padding(.horizontal, isCompact ? 12 : 16)
        .padding(.vertical, isCompact ? 8 : 10)
        .liquidGlassCapsule(material: .regularMaterial, shadowOpacity: 0.16)
        .padding(.horizontal, isCompact ? 10 : 16)
        .padding(.top, 12)
    }

    private func dismissAdjustment() {
        withAnimation(.snappy(duration: 0.2)) {
            activeAdjustment = nil
        }
    }

    private func captureAndSave(viewportSize: CGSize, framingInsets: FramingSafeInsets) {
        dismissAdjustment()

        controller.capture { result in
            switch result {
            case .success(let captured):
                let framedImage = framingOverlayService.applyOverlay(
                    to: captured.image,
                    aspectRatio: captured.frameAspectRatio,
                    shotType: captured.shotType,
                    lensPreset: captured.lensPreset,
                    showsGuides: false,
                    viewportSize: viewportSize,
                    contentInsets: framingInsets,
                    cropsToFrame: true
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
                    let lightSummary = PromptService.lightSummary(for: captured.layoutRecords)
                    let entry = LookbookEntry(
                        title: "Scene \(Date().formatted(date: .numeric, time: .shortened))",
                        imagePath: imagePath,
                        prompt: captured.prompt,
                        shotType: captured.shotType.rawValue,
                        lightPreset: lightSummary,
                        colorTemperature: captured.shouldRenderLightingOverlay ? captured.colorTemperature.rawValue : "None",
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
    case direction = "Direction"
    case color = "Color"
    case intensity = "Intensity"
    case spread = "Spread"
    case filter = "Filter"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .asset: "square.grid.2x2"
        case .reset: "arrow.counterclockwise"
        case .frame: "rectangle.on.rectangle"
        case .lens: "camera.aperture"
        case .shot: "viewfinder"
        case .direction: "light.beacon.max"
        case .color: "thermometer.sun"
        case .intensity: "sun.max"
        case .spread: "circle.dotted"
        case .filter: "camera.filters"
        }
    }

    static func items(for tool: SceneTool) -> [CaptureAdjustment] {
        switch tool {
        case .subject, .prop:
            [.asset, .reset]
        case .frame:
            [.frame, .lens, .shot, .filter]
        case .light:
            [.direction, .color, .intensity, .spread]
        }
    }
}

private struct AdjustmentButtonColumn: View {
    @ObservedObject var controller: ARSceneController
    @Binding var activeAdjustment: CaptureAdjustment?
    let maxWidth: CGFloat
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            VStack(spacing: 8) {
                ForEach(CaptureAdjustment.items(for: controller.selectedTool)) { adjustment in
                    HStack(spacing: 8) {
                        if activeAdjustment == adjustment {
                            InlineAdjustmentBar(
                                adjustment: adjustment,
                                controller: controller,
                                maxWidth: max(86, maxWidth - 56),
                                onClose: closeAdjustment
                            )
                            .transition(.scale(scale: 0.92, anchor: .trailing).combined(with: .opacity))
                        }

                        Button {
                            handleSelection(adjustment)
                        } label: {
                            Image(systemName: adjustment.systemImage)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(activeAdjustment == adjustment ? .black : .white)
                                .frame(width: 44, height: 44)
                                .liquidGlassCircle(isSelected: activeAdjustment == adjustment)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(adjustment.rawValue)
                    }
                    .frame(maxWidth: maxWidth, alignment: .trailing)
                }
            }
        }
        .frame(width: maxWidth, alignment: .bottomTrailing)
        .animation(.snappy(duration: 0.22), value: activeAdjustment)
    }

    private func handleSelection(_ adjustment: CaptureAdjustment) {
        switch adjustment {
        case .reset:
            onReset()
            activeAdjustment = nil
        default:
            activeAdjustment = activeAdjustment == adjustment ? nil : adjustment
        }
    }

    private func closeAdjustment() {
        activeAdjustment = nil
    }
}

private struct InlineAdjustmentBar: View {
    let adjustment: CaptureAdjustment
    @ObservedObject var controller: ARSceneController
    let maxWidth: CGFloat
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: maxWidth, alignment: .trailing)
        .liquidGlassCapsule(material: .ultraThinMaterial, shadowOpacity: 0.12)
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
        case .filter:
            optionChips(FilterPreset.allCases, selection: $controller.filterPreset)
        case .direction:
            optionChips(LightPreset.allCases, selection: $controller.lightPreset)
        case .color:
            optionChips(ColorTemperature.allCases, selection: $controller.colorTemperature)
        case .intensity:
            sliderControl(value: $controller.lightIntensity, range: 0.1...1.0)
        case .spread:
            sliderControl(value: $controller.lightRadius, range: 0.2...1.0)
        case .reset:
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
                                .font(.system(size: 13, weight: .semibold))
                            Text(shortTitle(for: preset.rawValue))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 34)
                        .liquidGlassChip(isSelected: isSelected(preset))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: maxWidth - 16)
        .clipShape(Capsule())
    }

    private func optionChips<Option: Identifiable & RawRepresentable & Hashable>(
        _ options: [Option],
        selection: Binding<Option>
    ) -> some View where Option.RawValue == String {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options) { option in
                    Button {
                        selection.wrappedValue = option
                        onClose()
                    } label: {
                        Text(option.rawValue)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .liquidGlassChip(isSelected: selection.wrappedValue == option)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: maxWidth - 16)
        .clipShape(Capsule())
    }

    private func sliderControl(value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 9) {
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38, alignment: .leading)

            Slider(value: value, in: range, step: 0.05)
                .frame(width: max(56, maxWidth - 78))
        }
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
    let displayHeight: CGFloat

    @State private var dragTranslation: CGFloat = 0
    @State private var dragStartIndex: Int?
    @State private var previewIndex: Int?

    private let tools = SceneTool.allCases
    private let itemSize: CGFloat = 44
    private let itemSpacing: CGFloat = 52
    private let dragDamping: CGFloat = 0.62

    var body: some View {
        ZStack {
            Capsule()
                .frame(width: 56, height: 56)
                .foregroundStyle(.clear)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.34), lineWidth: 1)
                }

            VStack(spacing: itemSpacing - itemSize) {
                ForEach(tools) { tool in
                    toolIcon(tool)
                }
            }
            .offset(y: pickerOffset)
        }
        .frame(width: 64, height: displayHeight)
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
                let dampedTranslation = value.translation.height * dragDamping
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
            .font(.system(size: isActive ? 22 : 18, weight: .semibold))
            .foregroundStyle(isActive ? .white : .white.opacity(0.74))
            .frame(width: itemSize, height: itemSize)
            .background(
                Circle()
                    .fill(isActive ? Color.accentColor : Color.clear)
            )
            .accessibilityLabel("Select \(tool.rawValue)")
    }
}
