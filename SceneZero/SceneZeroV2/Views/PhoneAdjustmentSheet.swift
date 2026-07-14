import SwiftUI

struct PhoneAdjustmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var controller: ARSceneController
    let adjustment: CaptureAdjustment

    var body: some View {
        NavigationStack {
            Form {
                adjustmentContent
            }
            .navigationTitle(adjustment.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: dismiss.callAsFunction)
                }
            }
        }
    }

    @ViewBuilder
    private var adjustmentContent: some View {
        switch adjustment {
        case .asset:
            Section("选择样式") {
                ForEach(AssetPreset.presets(for: controller.selectedTool)) { preset in
                    Button {
                        controller.setAssetPreset(preset, for: controller.selectedTool)
                        dismiss()
                    } label: {
                        HStack {
                            Label(preset.displayName, systemImage: preset.systemImage)
                            Spacer()
                            if controller.assetPreset(for: controller.selectedTool) == preset {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(SceneZeroTheme.accent)
                            }
                        }
                    }
                    .accessibilityLabel("\(preset.displayName)样式")
                }
            }
        case .filter:
            Section("色彩") {
                Picker("色彩", selection: $controller.filterPreset) {
                    ForEach(FilterPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
            }
        case .direction:
            Section("灯位") {
                Picker("灯位", selection: $controller.lightPreset) {
                    ForEach(LightPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
            }
        case .color:
            Section("色温") {
                Picker("色温", selection: $controller.colorTemperature) {
                    ForEach(ColorTemperature.allCases) { temperature in
                        Text(temperature.displayName).tag(temperature)
                    }
                }
            }
        case .intensity:
            Section("强度") {
                Slider(value: $controller.lightIntensity, in: 0.1...1.0, step: 0.05)
                Text("\(Int(controller.lightIntensity * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .spread:
            Section("范围") {
                Slider(value: $controller.lightRadius, in: 0.2...1.0, step: 0.05)
                Text("\(Int(controller.lightRadius * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .reset, .frame, .lens, .shot:
            ContentUnavailableView("此项无需额外设置", systemImage: adjustment.systemImage)
        }
    }
}
