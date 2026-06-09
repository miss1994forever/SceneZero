import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var controller: ARSceneController
    let onCapture: () -> Void
    let onOpenLookbook: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Picker("Tool", selection: $controller.selectedTool) {
                ForEach(SceneTool.allCases) { tool in
                    Label(tool.rawValue, systemImage: tool.systemImage)
                        .tag(tool)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 10) {
                HStack {
                    Text("Light")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Picker("Light preset", selection: $controller.lightPreset) {
                        ForEach(LightPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 190)
                }

                HStack {
                    Text("Color")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Picker("Color temperature", selection: $controller.colorTemperature) {
                        ForEach(ColorTemperature.allCases) { temperature in
                            Text(temperature.rawValue).tag(temperature)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 170)
                }

                HStack {
                    Text("Look")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Picker("Filter", selection: $controller.filterPreset) {
                        ForEach(FilterPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 190)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 12) {
                Button {
                    onOpenLookbook()
                } label: {
                    Label("Lookbook", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onCapture()
                } label: {
                    Label(controller.isCapturing ? "Capturing" : "Capture", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(controller.isCapturing)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
}

#Preview {
    ControlPanelView(controller: ARSceneController(), onCapture: {}, onOpenLookbook: {})
        .padding()
        .background(Color.gray.opacity(0.2))
}
