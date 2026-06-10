import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var controller = ARSceneController()
    @State private var showsLookbook = false
    @State private var alertMessage: String?

    private let filterService = FilterService()
    private let imageStorage = ImageStorageService()
    private let lightingOverlayService = LightingOverlayService()

    var body: some View {
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

            VStack(spacing: 0) {
                topBar
                Spacer()
                ControlPanelView(
                    controller: controller,
                    onCapture: captureAndSave,
                    onOpenLookbook: { showsLookbook = true }
                )
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

    private var topBar: some View {
        HStack(spacing: 12) {
            Label(controller.statusText, systemImage: controller.isCapturing ? "camera.aperture" : "arkit")
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer()

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

    private func captureAndSave() {
        controller.capture { result in
            switch result {
            case .success(let captured):
                let litImage = lightingOverlayService.applyOverlay(
                    to: captured.image,
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
