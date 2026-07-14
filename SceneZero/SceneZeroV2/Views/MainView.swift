import SwiftData
import SwiftUI
import UIKit

struct MainView: View {
    @Binding var selectedMode: SceneZeroMode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \LookbookBoard.sortIndex) private var customBoards: [LookbookBoard]

    @AppStorage("usesRealityKitModelLighting") private var usesRealityKitModelLighting = false

    @StateObject private var controller = ARSceneController()
    @State private var alertMessage: String?
    @State private var alertTitle = "无法完成操作"
    @State private var activeAdjustment: CaptureAdjustment?
    @State private var pendingCapture: PendingLookbookCapture?
    @State private var showsDeleteConfirmation = false
    @State private var showsCreativeSuggestion = false
    @State private var creativeSuggestions: [CreativeSuggestion] = []
    @State private var creativeSuggestionIndex = 0
    @State private var ignoredCreativeSuggestionIDs: Set<String> = []
    @State private var showsLensSettings = false
    @State private var showsPhoneToolPicker = false
    @State private var showsPhoneAdjustmentChoices = false
    @State private var phoneAdjustment: CaptureAdjustment?

    private let filterService = FilterService()
    private let imageStorage = ImageStorageService()
    private let framingOverlayService = FramingOverlayService()
    private let lightingOverlayService = LightingOverlayService()
    private let collectionService = InspirationCollectionService()
    private let creativeAdvisor = LocalCreativeAdvisor()
    private let creativeSuggestionFeedbackStore = CreativeSuggestionFeedbackStore()

    private enum OverlayMetrics {
        static let metadataBottomSpacing: CGFloat = 18
        static let metadataCompactMaxWidth: CGFloat = 190
        static let metadataRegularMaxWidth: CGFloat = 240
        static let compactHorizontalPadding: CGFloat = 12
        static let regularHorizontalPadding: CGFloat = 16
        static let compactTrailingPadding: CGFloat = 14
        static let regularTrailingPadding: CGFloat = 18
    }

    var body: some View {
        GeometryReader { proxy in
            let layoutMode = CaptureLayoutMode.resolve(
                size: proxy.size,
                horizontalSizeClass: horizontalSizeClass
            )
            let layoutMetrics = CaptureLayoutMetrics(
                mode: layoutMode,
                size: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets
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
                    showsGuides: controller.showsCompositionGuides,
                    contentInsets: layoutMetrics.framingInsets
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                controlsOverlay(
                    metrics: layoutMetrics
                )
            }
            .onChange(of: layoutMode) { _, _ in
                withAnimation(.snappy(duration: 0.24)) {
                    activeAdjustment = nil
                }
                showsPhoneToolPicker = false
                showsPhoneAdjustmentChoices = false
                phoneAdjustment = nil
            }
        }
        .alert(alertTitle, isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("关闭", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .alert("删除标记？", isPresented: $showsDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                controller.deleteSelectedObject()
            }
        } message: {
            Text("这会从当前取景场景中移除选中的人物、道具或灯光标记。")
        }
        .confirmationDialog(
            "调整\(controller.selectedTool.displayName)",
            isPresented: $showsPhoneAdjustmentChoices,
            titleVisibility: .visible
        ) {
            if controller.selectedTool == .frame {
                Button("镜头设置", systemImage: "camera.aperture") {
                    showsLensSettings = true
                }
            }

            ForEach(CaptureAdjustment.items(for: controller.selectedTool)) { adjustment in
                Button(adjustment.displayName, systemImage: adjustment.systemImage) {
                    openPhoneAdjustment(adjustment)
                }
            }

            if controller.hasSelectedObject {
                Button("删除选中标记", systemImage: "trash", role: .destructive) {
                    showsDeleteConfirmation = true
                }
            }
        }
        .onChange(of: controller.selectedTool) { _, _ in
            dismissAdjustment()
        }
        .onAppear {
            controller.setRealityKitModelLightingEnabled(usesRealityKitModelLighting)
        }
        .onChange(of: usesRealityKitModelLighting) { _, newValue in
            controller.setRealityKitModelLightingEnabled(newValue)
        }
        .task(id: controller.sceneRevision) {
            await refreshCreativeSuggestionsAfterSceneSettles()
        }
        .sheet(item: $pendingCapture) { capture in
            CaptureReviewSheet(
                capture: capture,
                boardNames: movableBoardNames,
                existingBoardNames: allBoardNames,
                onCancel: {
                    pendingCapture = nil
                },
                onSave: { title, boardName, note in
                    savePendingCapture(
                        capture,
                        title: title,
                        boardName: boardName,
                        note: note
                    )
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsLensSettings) {
            LensSettingsSheet(controller: controller)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsPhoneToolPicker) {
            PhoneToolPickerSheet(selectedTool: $controller.selectedTool)
                .presentationDetents([.height(210)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $phoneAdjustment) { adjustment in
            PhoneAdjustmentSheet(controller: controller, adjustment: adjustment)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsCreativeSuggestion) {
            CreativeSuggestionSheet(
                suggestions: creativeSuggestions,
                currentIndex: creativeSuggestionIndex,
                onApply: applyCurrentCreativeSuggestion,
                onSwap: swapCreativeSuggestion,
                onIgnore: ignoreCurrentCreativeSuggestion
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func controlsOverlay(metrics: CaptureLayoutMetrics) -> some View {
        switch metrics.mode {
        case .phonePortrait, .phoneLandscape:
            phoneControls(metrics: metrics)
        case .regularSideRail:
            sideRailControls(metrics: metrics)
        }
    }

    private func phoneControls(metrics: CaptureLayoutMetrics) -> some View {
        ZStack {
            VStack(spacing: 0) {
                CaptureTopBar(
                    selectedMode: $selectedMode,
                    hasCreativeSuggestion: activeCreativeSuggestion != nil,
                    showsCompositionGuides: controller.showsCompositionGuides,
                    trailingInset: metrics.phoneTopBarTrailingInset,
                    openCreativeSuggestions: {
                        refreshCreativeSuggestions()
                        showsCreativeSuggestion = true
                    },
                    toggleCompositionGuides: {
                        withAnimation(.snappy(duration: 0.2)) {
                            controller.showsCompositionGuides.toggle()
                        }
                    },
                    openLensSettings: { showsLensSettings = true },
                    resetScene: controller.resetScene
                )
                    .padding(.top, metrics.topPadding)
                Spacer()
            }

            if metrics.mode == .phonePortrait {
                PhoneCaptureControlDock(
                    placement: .bottom,
                    safeAreaInset: metrics.safeAreaInsets.bottom,
                    selectedTool: controller.selectedTool,
                    isCapturing: controller.isCapturing,
                    openToolPicker: {
                        showsPhoneAdjustmentChoices = false
                        showsPhoneToolPicker = true
                    },
                    openAdjustments: {
                        showsPhoneToolPicker = false
                        showsPhoneAdjustmentChoices = true
                    },
                    capture: {
                        captureAndSave(
                            viewportSize: metrics.size,
                            framingInsets: metrics.framingInsets
                        )
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)
            } else {
                PhoneCaptureControlDock(
                    placement: .trailing,
                    safeAreaInset: metrics.safeAreaInsets.trailing,
                    selectedTool: controller.selectedTool,
                    isCapturing: controller.isCapturing,
                    openToolPicker: {
                        showsPhoneAdjustmentChoices = false
                        showsPhoneToolPicker = true
                    },
                    openAdjustments: {
                        showsPhoneToolPicker = false
                        showsPhoneAdjustmentChoices = true
                    },
                    capture: {
                        captureAndSave(
                            viewportSize: metrics.size,
                            framingInsets: metrics.framingInsets
                        )
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .ignoresSafeArea(edges: .trailing)
            }
        }
    }

    private func sideRailControls(metrics: CaptureLayoutMetrics) -> some View {
        let isLandscape = metrics.size.width > metrics.size.height

        return ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                topBar(isCompact: false)
                Spacer()
                bottomMetadataBar(isCompact: false)
            }

            cameraControls(
                availableSize: metrics.size,
                safeAreaInsets: metrics.safeAreaInsets,
                isLandscape: isLandscape,
                framingInsets: metrics.framingInsets
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
    }

    private func cameraControls(
        availableSize: CGSize,
        safeAreaInsets: EdgeInsets,
        isLandscape: Bool,
        framingInsets: FramingSafeInsets
    ) -> some View {
        let controlTrailingPadding = controlTrailingPadding(
            safeAreaInsets: safeAreaInsets,
            isLandscape: isLandscape
        )
        let shutterToPickerSpacing: CGFloat = 18
        let adjustmentToShutterSpacing: CGFloat = 30
        let shutterSize: CGFloat = isCompactWidth(availableSize.width) ? 62 : 68
        let adjustmentButtonSize: CGFloat = 44
        let pickerFrameWidth: CGFloat = 76
        let controlAxisFromTrailing = shutterSize / 2
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

        func alignedTrailingPadding(for controlWidth: CGFloat) -> CGFloat {
            controlTrailingPadding + controlAxisFromTrailing - controlWidth / 2
        }

        return ZStack(alignment: .trailing) {
            AdjustmentButtonColumn(
                controller: controller,
                activeAdjustment: $activeAdjustment,
                maxWidth: railWidth,
                onReset: {
                    controller.resetSelectedObjectScale()
                },
                onDelete: {
                    activeAdjustment = nil
                    showsDeleteConfirmation = true
                }
            )
            .padding(.trailing, alignedTrailingPadding(for: adjustmentButtonSize))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .offset(y: adjustmentOffset)

            ShutterButton(
                isCapturing: controller.isCapturing,
                size: shutterSize,
                action: {
                    captureAndSave(
                        viewportSize: availableSize,
                        framingInsets: framingInsets
                    )
                }
            )
            .padding(.trailing, alignedTrailingPadding(for: shutterSize))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

            ToolModePicker(
                selectedTool: $controller.selectedTool,
                onTap: dismissAdjustment,
                displayHeight: pickerHeight
            )
            .frame(width: pickerFrameWidth, height: pickerHeight, alignment: .center)
            .padding(.trailing, alignedTrailingPadding(for: pickerFrameWidth))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .offset(y: shutterSize / 2 + shutterToPickerSpacing + pickerHeight / 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controlTrailingPadding(safeAreaInsets: EdgeInsets, isLandscape: Bool) -> CGFloat {
        max(isLandscape ? 18 : 12, safeAreaInsets.trailing + 8)
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
        let maxHeight = availableSize.height * (isLandscape ? 0.46 : 0.36)
        let minimumHeight: CGFloat = isLandscape ? 238 : 252
        return max(minimumHeight, min(276, maxHeight))
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

    private func topBar(isCompact: Bool, statusMaximumWidth: CGFloat? = nil) -> some View {
        HStack(spacing: isCompact ? 8 : 12) {
            Label(topBarStatusText, systemImage: topBarStatusIcon)
                .font((isCompact ? Font.caption : Font.footnote).weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(activeCreativeSuggestion == nil ? .primary : SceneZeroTheme.accent)
                .frame(maxWidth: statusMaximumWidth, alignment: .leading)

            Spacer()

            Button {
                refreshCreativeSuggestions()
                showsCreativeSuggestion = true
            } label: {
                Image(systemName: activeCreativeSuggestion == nil ? "lightbulb" : "lightbulb.fill")
                    .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                    .foregroundStyle(activeCreativeSuggestion == nil ? Color.primary : Color.black)
                    .frame(width: isCompact ? 34 : 36, height: isCompact ? 34 : 36)
                    .liquidGlassCircle(isSelected: activeCreativeSuggestion != nil)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("创作建议")
            .accessibilityValue(activeCreativeSuggestion == nil ? "暂无建议" : "有新的本地建议")
            .accessibilityHint("打开当前场景的创作建议")

            Button {
                controller.resetScene()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                    .frame(width: isCompact ? 34 : 36, height: isCompact ? 34 : 36)
                    .liquidGlassCircle()
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重置场景")
            .accessibilityHint("清除当前取景中的人物、道具和灯光标记")

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    controller.showsCompositionGuides.toggle()
                }
            } label: {
                Image(systemName: controller.showsCompositionGuides ? "grid.circle.fill" : "grid.circle")
                    .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                    .frame(width: isCompact ? 34 : 36, height: isCompact ? 34 : 36)
                    .liquidGlassCircle(isSelected: controller.showsCompositionGuides)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("构图辅助线")
            .accessibilityHint("显示或隐藏画幅构图参考线")
        }
        .padding(.horizontal, isCompact ? 12 : 16)
        .padding(.vertical, isCompact ? 8 : 10)
        .liquidGlassCapsule(material: .regularMaterial, shadowOpacity: 0.16)
        .padding(.horizontal, isCompact ? 10 : 16)
        .padding(.top, 12)
    }

    private var lensMetadataButton: some View {
        Button {
            showsLensSettings = true
        } label: {
            Text(captureMetadataText)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .liquidGlassCapsule(material: .regularMaterial, shadowOpacity: 0.16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("镜头设置：\(controller.frameAspectRatio.displayName)，\(controller.lensPreset.displayName)，\(controller.shotType.displayName)")
        .accessibilityHint("轻点调整画幅、焦距和景别")
    }

    private func bottomMetadataBar(isCompact: Bool) -> some View {
        lensMetadataButton
            .frame(
                maxWidth: isCompact ? OverlayMetrics.metadataCompactMaxWidth : OverlayMetrics.metadataRegularMaxWidth,
                alignment: .trailing
            )
            .padding(.leading, isCompact ? OverlayMetrics.compactHorizontalPadding : OverlayMetrics.regularHorizontalPadding)
            .padding(.trailing, isCompact ? OverlayMetrics.compactTrailingPadding : OverlayMetrics.regularTrailingPadding)
            .padding(.bottom, OverlayMetrics.metadataBottomSpacing)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var topBarStatusText: String {
        activeCreativeSuggestion.map { "建议：\($0.suggestion)" } ?? controller.statusText
    }

    private var topBarStatusIcon: String {
        if activeCreativeSuggestion != nil {
            return "lightbulb.fill"
        }
        return controller.isCapturing ? "camera.aperture" : "arkit"
    }

    private var captureMetadataText: String {
        "\(controller.frameAspectRatio.displayName) · \(controller.lensPreset.displayName) · \(controller.shotType.displayName)"
    }

    private var activeCreativeSuggestion: CreativeSuggestion? {
        guard creativeSuggestions.indices.contains(creativeSuggestionIndex) else { return nil }
        return creativeSuggestions[creativeSuggestionIndex]
    }

    private func refreshCreativeSuggestionsAfterSceneSettles() async {
        do {
            try await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            refreshCreativeSuggestions()
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    private func refreshCreativeSuggestions() {
        let snapshot = controller.currentSceneSnapshot()
        creativeSuggestions = Array(
            creativeAdvisor.advise(snapshot: snapshot)
                .filter { !ignoredCreativeSuggestionIDs.contains($0.ruleID) }
                .prefix(3)
        )
        creativeSuggestionIndex = 0
    }

    private func applyCurrentCreativeSuggestion() {
        guard let suggestion = activeCreativeSuggestion,
              let action = suggestion.action else { return }
        controller.apply(action)
        creativeSuggestionFeedbackStore.record(ruleID: suggestion.ruleID, outcome: .applied)
        refreshCreativeSuggestions()
    }

    private func swapCreativeSuggestion() {
        guard let suggestion = activeCreativeSuggestion,
              creativeSuggestions.count > 1 else { return }
        creativeSuggestionFeedbackStore.record(ruleID: suggestion.ruleID, outcome: .swapped)
        creativeSuggestionIndex = (creativeSuggestionIndex + 1) % creativeSuggestions.count
    }

    private func ignoreCurrentCreativeSuggestion() {
        guard let suggestion = activeCreativeSuggestion else { return }
        ignoredCreativeSuggestionIDs.insert(suggestion.ruleID)
        creativeSuggestionFeedbackStore.record(ruleID: suggestion.ruleID, outcome: .ignored)
        refreshCreativeSuggestions()
        if creativeSuggestions.isEmpty {
            showsCreativeSuggestion = false
        }
    }

    private func dismissAdjustment() {
        withAnimation(.snappy(duration: 0.2)) {
            activeAdjustment = nil
        }
    }

    private func openPhoneAdjustment(_ adjustment: CaptureAdjustment) {
        switch adjustment {
        case .reset:
            controller.resetSelectedObjectScale()
        default:
            phoneAdjustment = adjustment
        }
    }

    private var movableBoardNames: [String] {
        [LookbookBoard.defaultBoardName] + customCollections.map(\.name)
    }

    private var allBoardNames: [String] {
        movableBoardNames + [LookbookBoard.favoritesBoardName]
    }

    private var customCollections: [LookbookBoard] {
        customBoards.filter {
            $0.name != LookbookBoard.defaultBoardName && $0.name != LookbookBoard.favoritesBoardName
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
                    let layoutData = try JSONEncoder().encode(captured.layoutRecords)
                    let layoutJSON = String(data: layoutData, encoding: .utf8) ?? "[]"
                    let lightSummary = PromptService.lightSummary(for: captured.layoutRecords)
                    pendingCapture = PendingLookbookCapture(
                        image: filteredImage,
                        defaultTitle: "现场参考 \(Date().formatted(date: .numeric, time: .shortened))",
                        prompt: captured.prompt,
                        shotType: captured.shotType.rawValue,
                        lightPreset: lightSummary,
                        colorTemperature: captured.shouldRenderLightingOverlay ? captured.colorTemperature.rawValue : "无",
                        lightIntensity: captured.lightIntensity,
                        lightRadius: captured.lightRadius,
                        frameAspectRatio: captured.frameAspectRatio.rawValue,
                        lensPreset: captured.lensPreset.rawValue,
                        showsCompositionGuides: captured.showsCompositionGuides,
                        filterName: captured.filterPreset.rawValue,
                        layoutJSON: layoutJSON,
                        snapshot: captured.snapshot
                    )
                } catch {
                    alertTitle = "无法生成参考图"
                    alertMessage = "无法生成这张参考图。\(error.localizedDescription)"
                }
            case .failure:
                alertTitle = "取景失败"
                alertMessage = "取景失败，请重新扫描平面。"
            }
        }
    }

    @discardableResult
    private func savePendingCapture(
        _ capture: PendingLookbookCapture,
        title: String,
        boardName: String,
        note: String
    ) -> Error? {
        do {
            let targetBoardName = boardName.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedBoardName = targetBoardName.isEmpty ? LookbookBoard.defaultBoardName : targetBoardName

            ensureBoardExists(named: resolvedBoardName)

            let imagePath = try imageStorage.save(capture.image)
            let promptDraft = capture.promptDraft(note: note)
            let canonicalPrompt = PromptRenderer.render(promptDraft)
            let entry = LookbookEntry(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? capture.defaultTitle : title,
                imagePath: imagePath,
                prompt: canonicalPrompt,
                shotType: capture.shotType,
                lightPreset: capture.lightPreset,
                colorTemperature: capture.colorTemperature,
                lightIntensity: capture.lightIntensity,
                lightRadius: capture.lightRadius,
                frameAspectRatio: capture.frameAspectRatio,
                lensPreset: capture.lensPreset,
                showsCompositionGuides: capture.showsCompositionGuides,
                filterName: capture.filterName,
                layoutJSON: capture.layoutJSON,
                boardName: resolvedBoardName,
                sortIndex: 0,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let snapshotData = try JSONEncoder().encode(capture.snapshot)
            let promptData = try JSONEncoder().encode(promptDraft)
            let asset = InspirationAsset(
                kind: .image,
                relativePath: imagePath,
                title: entry.title,
                pixelWidth: capture.image.size.width,
                pixelHeight: capture.image.size.height,
                entry: entry
            )
            let previsualization = ARPrevisualization(
                layoutData: snapshotData,
                frameAspectRatio: capture.frameAspectRatio,
                lensPreset: capture.lensPreset,
                showsCompositionGuides: capture.showsCompositionGuides,
                inspiration: entry
            )
            let promptDocument = PromptDocument(
                canonicalText: canonicalPrompt,
                structuredData: promptData,
                schemaVersion: PromptDraft.currentSchemaVersion,
                inspiration: entry
            )
            modelContext.insert(entry)
            try collectionService.assign(entry, toCollectionNamed: resolvedBoardName, in: modelContext)
            modelContext.insert(asset)
            modelContext.insert(previsualization)
            modelContext.insert(promptDocument)
            entry.assets.append(asset)
            entry.previsualizations.append(previsualization)
            entry.promptDocuments.append(promptDocument)
            do {
                try modelContext.save()
            } catch {
                imageStorage.delete(relativePath: imagePath)
                throw error
            }
            pendingCapture = nil
            alertTitle = "参考包已保存"
            alertMessage = "已保存到灵感库。"
            return nil
        } catch {
            return error
        }
    }

    private func ensureBoardExists(named name: String) {
        guard name != LookbookBoard.defaultBoardName,
              name != LookbookBoard.favoritesBoardName,
              !customCollections.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            return
        }

        modelContext.insert(LookbookBoard(name: name, sortIndex: customCollections.count + 1))
    }

}

#Preview {
    MainView(selectedMode: .constant(.capture))
        .modelContainer(for: SceneZeroSchemaV1.models, inMemory: true)
}

private struct PendingLookbookCapture: Identifiable {
    let id = UUID()
    let image: UIImage
    let defaultTitle: String
    let prompt: String
    let shotType: String
    let lightPreset: String
    let colorTemperature: String
    let lightIntensity: Double
    let lightRadius: Double
    let frameAspectRatio: String
    let lensPreset: String
    let showsCompositionGuides: Bool
    let filterName: String
    let layoutJSON: String
    let snapshot: SceneSnapshot

    func layoutRecords() -> [SceneObjectRecord] {
        guard let data = layoutJSON.data(using: .utf8),
              let records = try? JSONDecoder().decode([SceneObjectRecord].self, from: data) else {
            return []
        }
        return records
    }

    func structuredPrompt(note: String = "") -> StructuredPrompt {
        StructuredPrompt(draft: promptDraft(note: note))
    }

    func promptDraft(note: String = "") -> PromptDraft {
        LocalPromptCompiler().compile(snapshot: snapshot, intent: CreatorIntent(note: note))
    }
}

private struct CaptureReviewSheet: View {
    let capture: PendingLookbookCapture
    let boardNames: [String]
    let existingBoardNames: [String]
    let onCancel: () -> Void
    let onSave: (String, String, String) -> Error?

    @State private var title: String
    @State private var selectedBoardName: String
    @State private var createsNewBoard = false
    @State private var newBoardName = ""
    @State private var note = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showsDiscardConfirmation = false
    @State private var showsPromptDetails = false

    init(
        capture: PendingLookbookCapture,
        boardNames: [String],
        existingBoardNames: [String],
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, String, String) -> Error?
    ) {
        self.capture = capture
        self.boardNames = boardNames
        self.existingBoardNames = existingBoardNames
        self.onCancel = onCancel
        self.onSave = onSave
        _title = State(initialValue: "")
        _selectedBoardName = State(initialValue: boardNames.first ?? LookbookBoard.defaultBoardName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    reviewSection(title: "画面", detail: "现场构图与镜头信息") {
                        referenceCard
                    }

                    reviewSection(title: "创作意图", detail: "先留下你此刻的判断，再让 Prompt 承接它") {
                        thoughtCard
                    }

                    reviewSection(title: "归档", detail: "先保存到灵感库，后续可继续整理") {
                        saveTargetCard
                    }

                    promptCard

                    Button {
                        saveReferencePackage()
                    } label: {
                        saveButtonLabel
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(SceneZeroTheme.accent, in: Capsule())
                    .disabled(!canSave || isSaving)
                    .opacity(canSave && !isSaving ? 1 : 0.45)

                    if let saveError {
                        Label("无法保存：\(saveError)", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
                .padding()
            }
            .background(SceneZeroTheme.background)
            .navigationTitle("参考图详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        requestDismissal()
                    }
                }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges || isSaving)
        .confirmationDialog(
            "放弃这次参考包？",
            isPresented: $showsDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("放弃修改", role: .destructive, action: onCancel)
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("标题、创作意图和归档位置尚未保存。")
        }
    }

    private var saveButtonLabel: some View {
        Group {
            if isSaving {
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel("正在保存参考包")
            } else {
                Text("保存参考包")
                    .font(.headline)
            }
        }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .contentShape(Capsule())
    }

    private var referenceCard: some View {
        HStack(spacing: 14) {
            Image(uiImage: capture.image)
                .resizable()
                .scaledToFill()
                .frame(width: 92, height: 72)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                TextField(capture.defaultTitle, text: $title)
                    .font(.headline)
                    .textFieldStyle(.plain)

                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("来自现场取景 · 今天")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(SceneZeroTheme.infoAccent)
            }
        }
        .padding(14)
        .groupedCard(cornerRadius: 20)
    }

    private var thoughtCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("我当时想到", systemImage: "pencil")
                .font(.headline)
            TextEditor(text: $note)
                .frame(minHeight: 112)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(SceneZeroTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("记录这个场景让你想到的故事、人物关系或情绪。")
                            .font(.body)
                            .foregroundStyle(.secondary.opacity(0.72))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(14)
        .groupedCard(cornerRadius: 20)
    }

    private var promptCard: some View {
        let structuredPrompt = capture.structuredPrompt(note: note)
        return DisclosureGroup(isExpanded: $showsPromptDetails) {
            VStack(alignment: .leading, spacing: 12) {
                PromptSection(title: "基础提示词", text: structuredPrompt.base)
                PromptSection(title: "氛围补充", text: structuredPrompt.atmosphere)
                PromptSection(title: "镜头与空间", text: structuredPrompt.shotMetadata)
            }
            .padding(.top, 8)
        } label: {
            Label("预览结构化提示词", systemImage: "sparkle")
                .font(.headline)
                .foregroundStyle(SceneZeroTheme.promptAccent)
        }
        .padding(14)
        .groupedCard(cornerRadius: 20)
    }

    private var saveTargetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("保存到", selection: $selectedBoardName) {
                ForEach(boardNames, id: \.self) { boardName in
                    Text(LookbookBoard.displayName(for: boardName)).tag(boardName)
                }
            }
            .disabled(createsNewBoard)

            Toggle("新建灵感集", isOn: $createsNewBoard)

            if createsNewBoard {
                TextField("灵感集名称", text: $newBoardName)
                    .textFieldStyle(.roundedBorder)
            }

        }
        .padding(14)
        .groupedCard(cornerRadius: 18)
    }

    private var metadataText: String {
        let frame = FrameAspectRatio(rawValue: capture.frameAspectRatio)?.displayName ?? capture.frameAspectRatio
        let lens = LensPreset(rawValue: capture.lensPreset)?.displayName ?? capture.lensPreset
        let shot = ShotType(rawValue: capture.shotType)?.displayName ?? capture.shotType
        return "\(frame) · \(lens) · \(shot)"
    }

    private var resolvedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? capture.defaultTitle : title
    }

    private var resolvedBoardName: String {
        if createsNewBoard {
            return newBoardName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return selectedBoardName
    }

    private var canSave: Bool {
        guard createsNewBoard else {
            return true
        }

        let candidate = newBoardName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !candidate.isEmpty && !existingBoardNames.contains {
            $0.caseInsensitiveCompare(candidate) == .orderedSame
        }
    }

    private var hasUnsavedChanges: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || createsNewBoard
            || selectedBoardName != (boardNames.first ?? LookbookBoard.defaultBoardName)
    }

    private func reviewSection<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func requestDismissal() {
        if hasUnsavedChanges {
            showsDiscardConfirmation = true
        } else {
            onCancel()
        }
    }

    private func saveReferencePackage() {
        saveError = nil
        isSaving = true

        if let error = onSave(resolvedTitle, resolvedBoardName, note) {
            saveError = error.localizedDescription
            isSaving = false
        }
    }
}

private struct PromptSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ShutterButton: View {
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
        .accessibilityLabel(isCapturing ? "正在取景" : "取景")
    }
}

enum CaptureAdjustment: String, Identifiable, Equatable {
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

    var displayName: String {
        switch self {
        case .asset: "样式"
        case .reset: "重置大小"
        case .frame: "画幅"
        case .lens: "镜头"
        case .shot: "景别"
        case .direction: "灯位"
        case .color: "色温"
        case .intensity: "强度"
        case .spread: "范围"
        case .filter: "色彩"
        }
    }

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
            [.filter]
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
    let onDelete: () -> Void

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
                        .accessibilityLabel(adjustment.displayName)
                    }
                    .frame(maxWidth: maxWidth, alignment: .trailing)
                }

                if controller.hasSelectedObject {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(width: 44, height: 44)
                            .liquidGlassCircle()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除选中标记")
                    .frame(maxWidth: maxWidth, alignment: .trailing)
                    .transition(.scale(scale: 0.92, anchor: .trailing).combined(with: .opacity))
                }
            }
        }
        .frame(width: maxWidth, alignment: .bottomTrailing)
        .animation(.snappy(duration: 0.22), value: activeAdjustment)
        .animation(.snappy(duration: 0.22), value: controller.hasSelectedObject)
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
                            Text(preset.displayName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 34)
                        .liquidGlassChip(isSelected: isSelected(preset))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.displayName)
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
                        Text(displayTitle(for: option))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .liquidGlassChip(isSelected: selection.wrappedValue == option)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(displayTitle(for: option))
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

    private func displayTitle<Option: RawRepresentable>(for option: Option) -> String where Option.RawValue == String {
        if let option = option as? FrameAspectRatio {
            return option.displayName
        }
        if let option = option as? LensPreset {
            return option.displayName
        }
        if let option = option as? ShotType {
            return option.displayName
        }
        if let option = option as? FilterPreset {
            return option.displayName
        }
        if let option = option as? LightPreset {
            return option.displayName
        }
        if let option = option as? ColorTemperature {
            return option.displayName
        }
        return option.rawValue
    }
}

private struct LensSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var controller: ARSceneController

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("画幅", selection: $controller.frameAspectRatio) {
                        ForEach(FrameAspectRatio.allCases) { aspectRatio in
                            Text(aspectRatio.displayName).tag(aspectRatio)
                        }
                    }

                    Picker("焦距", selection: $controller.lensPreset) {
                        ForEach(LensPreset.allCases) { lens in
                            Text(lens.displayName).tag(lens)
                        }
                    }

                    Picker("景别", selection: $controller.shotType) {
                        ForEach(ShotType.allCases) { shot in
                            Text(shot.displayName).tag(shot)
                        }
                    }
                } footer: {
                    Text("这些设置会同步更新构图辅助线、保存的参考图和结构化提示词。")
                }
            }
            .navigationTitle("镜头设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
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
        VStack(spacing: 7) {
            Text(selectedTool.displayName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .liquidGlassCapsule(
                    material: .ultraThinMaterial,
                    shadowOpacity: 0.10,
                    tint: SceneZeroTheme.accent,
                    tintOpacity: 0.14
                )

            VStack(spacing: 7) {
                ForEach(tools) { tool in
                    Button {
                        onTap()
                        selectedTool = tool
                    } label: {
                        toolIcon(tool)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("选择\(tool.displayName)")
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 6)
            .liquidGlassCapsule(
                material: .ultraThinMaterial,
                shadowOpacity: 0.14,
                tint: SceneZeroTheme.accent,
                tintOpacity: 0.22
            )
        }
        .frame(width: 72, height: displayHeight, alignment: .center)
        .contentShape(Rectangle())
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
                    .fill(isActive ? SceneZeroTheme.accent : Color.clear)
            )
            .contentShape(Circle())
    }
}
