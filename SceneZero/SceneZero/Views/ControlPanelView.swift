import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var controller: ARSceneController
    let onHide: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            header

            ScrollView(.vertical) {
                VStack(spacing: 14) {
                    objectSettings
                    captureSettings
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.visible)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .clipped()
        .animation(.snappy(duration: 0.22), value: controller.selectedTool)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 42, height: 5)

            Spacer()

            Button {
                onHide()
            } label: {
                Capsule()
                    .fill(Color.secondary.opacity(0.16))
                    .frame(width: 34, height: 28)
                    .overlay {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide controls")
        }
    }

    private var objectSettings: some View {
        VStack(spacing: 10) {
            HStack {
                Label(controller.selectedTool.rawValue, systemImage: controller.selectedTool.systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(statusValueText)
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if supportsObjectSize {
                HStack(spacing: 12) {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundStyle(.secondary)
                    Slider(value: $controller.objectScale, in: 0.25...1.6, step: 0.05)
                        .accessibilityLabel("Object size")
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundStyle(.secondary)
                }

                if supportsAssetPreset {
                    settingRow("Asset") {
                        Picker("Asset", selection: assetPresetBinding) {
                            ForEach(AssetPreset.presets(for: controller.selectedTool)) { preset in
                                Label(preset.rawValue, systemImage: preset.systemImage)
                                    .tag(preset)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 190)
                    }
                }
            } else if controller.selectedTool == .frame {
                frameSettings
            } else {
                EmptyView()
            }

            if controller.selectedTool == .light {
                Divider()
                settingRow("Direction") {
                    Picker("Light direction", selection: $controller.lightPreset) {
                        ForEach(LightPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 210)
                }

                settingRow("Color") {
                    Picker("Color temperature", selection: $controller.colorTemperature) {
                        ForEach(ColorTemperature.allCases) { temperature in
                            Text(temperature.rawValue).tag(temperature)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 170)
                }

                sliderRow(
                    title: "Intensity",
                    value: $controller.lightIntensity,
                    range: 0.1...1.0,
                    systemImage: "sun.max"
                )

                sliderRow(
                    title: "Spread",
                    value: $controller.lightRadius,
                    range: 0.2...1.0,
                    systemImage: "circle.dotted"
                )
            }
        }
        .pickerStyle(.menu)
    }

    private var supportsObjectSize: Bool {
        controller.selectedTool == .subject || controller.selectedTool == .prop || controller.selectedTool == .light
    }

    private var supportsAssetPreset: Bool {
        controller.selectedTool == .subject || controller.selectedTool == .prop
    }

    private var assetPresetBinding: Binding<AssetPreset> {
        Binding {
            controller.assetPreset(for: controller.selectedTool)
        } set: { preset in
            controller.setAssetPreset(preset, for: controller.selectedTool)
        }
    }

    private var statusValueText: String {
        if controller.selectedTool == .frame {
            "\(controller.frameAspectRatio.rawValue) · \(controller.lensPreset.rawValue)"
        } else if supportsAssetPreset {
            controller.assetPreset(for: controller.selectedTool).rawValue
        } else {
            "\(Int(controller.objectScale * 100))%"
        }
    }

    private var frameSettings: some View {
        VStack(spacing: 10) {
            settingRow("Frame") {
                Picker("Frame", selection: $controller.frameAspectRatio) {
                    ForEach(FrameAspectRatio.allCases) { aspectRatio in
                        Text(aspectRatio.rawValue).tag(aspectRatio)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 150)
            }

            settingRow("Lens") {
                Picker("Lens", selection: $controller.lensPreset) {
                    ForEach(LensPreset.allCases) { lens in
                        Text(lens.rawValue).tag(lens)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 150)
            }

            Toggle(isOn: $controller.showsCompositionGuides) {
                Label("Guides", systemImage: "grid")
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(.switch)
        }
    }

    private var captureSettings: some View {
        VStack(spacing: 10) {
            Divider()
            settingRow("Shot") {
                Picker("Shot", selection: $controller.shotType) {
                    ForEach(ShotType.allCases) { shot in
                        Text(shot.rawValue).tag(shot)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
            }

            settingRow("Look") {
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
    }

    private func settingRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            content()
        }
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        systemImage: String
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range, step: 0.05)
                .accessibilityLabel(title)
        }
    }
}

#Preview {
    ControlPanelView(controller: ARSceneController(), onHide: {})
        .padding()
        .background(Color.gray.opacity(0.2))
}
