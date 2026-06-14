import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var controller = ARSceneController()
    @State private var showsLookbook = false
    @State private var alertMessage: String?
    @State private var isControlPanelVisible = true

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

                controlsOverlay(isLandscape: isLandscape)
            }
            .onAppear {
                isControlPanelVisible = !isLandscape
            }
            .onChange(of: isLandscape) { _, newValue in
                withAnimation(.snappy(duration: 0.24)) {
                    isControlPanelVisible = !newValue
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
    }

    private func controlsOverlay(isLandscape: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                topBar
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

            cameraControls(isLandscape: isLandscape)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, captureButtonBottomPadding(isLandscape: isLandscape))
        }
        .animation(.snappy(duration: 0.24), value: isControlPanelVisible)
    }

    private func controlPanelHeight(isLandscape: Bool) -> CGFloat {
        isLandscape ? 164 : 238
    }

    private func captureButtonBottomPadding(isLandscape: Bool) -> CGFloat {
        isControlPanelVisible ? controlPanelHeight(isLandscape: isLandscape) + 22 : 28
    }

    private func cameraControls(isLandscape: Bool) -> some View {
        HStack(spacing: isLandscape ? 18 : 22) {
            ToolModePicker(
            selectedTool: $controller.selectedTool,
            onTap: showControls
            )

            ShutterButton(
                isCapturing: controller.isCapturing,
                action: captureAndSave
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Label(controller.statusText, systemImage: controller.isCapturing ? "camera.aperture" : "arkit")
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                showsLookbook = true
            } label: {
                Image(systemName: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Lookbook")

            Button {
                controller.resetScene()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Reset scene")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, 16)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.86), lineWidth: 4)
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(.white)
                    .frame(width: isCapturing ? 48 : 58, height: isCapturing ? 48 : 58)

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

private struct ToolModePicker: View {
    @Binding var selectedTool: SceneTool
    let onTap: () -> Void

    @State private var dragTranslation: CGFloat = 0
    @State private var dragStartIndex: Int?
    @State private var previewIndex: Int?

    private let tools = SceneTool.allCases
    private let itemSize: CGFloat = 40
    private let itemSpacing: CGFloat = 46
    private let dragDamping: CGFloat = 0.62

    var body: some View {
        ZStack {
            Capsule()
                .fill(.black.opacity(0.24))
                .frame(width: 52, height: 52)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }

            HStack(spacing: itemSpacing - itemSize) {
                ForEach(tools) { tool in
                    toolIcon(tool)
                }
            }
            .offset(x: pickerOffset)
        }
        .frame(width: 162, height: 62)
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
