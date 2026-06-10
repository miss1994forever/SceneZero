import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var controller: ARSceneController
    let onCapture: () -> Void
    let onOpenLookbook: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 14) {
            header
            addObjectPalette
            objectSettings
            if isExpanded {
                captureSettings
            }
            actionBar
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .animation(.snappy(duration: 0.22), value: isExpanded)
        .animation(.snappy(duration: 0.22), value: controller.selectedTool)
    }

    private var header: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 8) {
                Capsule()
                    .fill(.secondary.opacity(0.45))
                    .frame(width: 36, height: 5)

                Spacer()

                Label(isExpanded ? "Hide controls" : "More controls", systemImage: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse controls" : "Expand controls")
    }

    private var addObjectPalette: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Object")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(SceneTool.allCases) { tool in
                    Button {
                        controller.selectedTool = tool
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tool.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(height: 20)
                            Text(tool.rawValue)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: isExpanded ? 62 : 50)
                    }
                    .buttonStyle(ObjectToolButtonStyle(isSelected: controller.selectedTool == tool))
                    .accessibilityLabel("Add \(tool.rawValue)")
                }
            }
        }
    }

    private var objectSettings: some View {
        VStack(spacing: 10) {
            HStack {
                Label(controller.selectedTool.rawValue, systemImage: controller.selectedTool.systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(controller.objectScale * 100))%")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundStyle(.secondary)
                Slider(value: $controller.objectScale, in: 0.25...1.6, step: 0.05)
                    .accessibilityLabel("Object size")
                Image(systemName: "plus.magnifyingglass")
                    .foregroundStyle(.secondary)
            }

            if controller.selectedTool == .light && !isExpanded {
                compactLightSummary
            }

            if controller.selectedTool == .light && isExpanded {
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

    private var compactLightSummary: some View {
        HStack(spacing: 10) {
            Label(controller.lightPreset.rawValue, systemImage: "light.beacon.max")
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer()
            Text("\(Int(controller.lightIntensity * 100))%")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
            Button {
                isExpanded = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .accessibilityLabel("Open light controls")
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                onOpenLookbook()
            } label: {
                Label(isExpanded ? "Lookbook" : "", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Lookbook")

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

private struct ObjectToolButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(configuration.isPressed ? 0.24 : 0.14))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
            .animation(.snappy(duration: 0.16), value: isSelected)
    }
}

#Preview {
    ControlPanelView(controller: ARSceneController(), onCapture: {}, onOpenLookbook: {})
        .padding()
        .background(Color.gray.opacity(0.2))
}
