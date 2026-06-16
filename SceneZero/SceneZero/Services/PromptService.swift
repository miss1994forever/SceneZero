import Foundation

struct PromptService {
    static func makePrompt(
        shotType: ShotType,
        frameAspectRatio: FrameAspectRatio,
        lensPreset: LensPreset,
        lightRecords: [SceneObjectRecord],
        filterPreset: FilterPreset,
        hasSubject: Bool,
        locationDescription: String
    ) -> String {
        let subject = hasSubject ? "subject placed as the spatial anchor" : "empty scene with spatial placeholders"
        let location = locationDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLocation = location.isEmpty ? "realistic interior location" : location

        var components = [
            shotType.promptText,
            frameAspectRatio.promptText,
            lensPreset.promptText,
            subject,
            filterPreset.promptText,
            finalLocation
        ]
        components.insert(lightPromptText(for: lightRecords), at: 4)
        return components.joined(separator: ", ") + "."
    }

    static func lightSummary(for records: [SceneObjectRecord]) -> String {
        let lights = lightRecords(from: records)
        guard !lights.isEmpty else { return "None" }

        if lights.count == 1 {
            let light = lights[0]
            return "1 light · \(light.lightPreset?.rawValue ?? "Custom") · \(light.colorTemperature?.rawValue ?? "Default")"
        }

        let names = lights
            .prefix(3)
            .map { $0.lightPreset?.rawValue ?? "Custom" }
            .joined(separator: ", ")
        let suffix = lights.count > 3 ? "..." : ""
        return "\(lights.count) lights · \(names)\(suffix)"
    }

    static func lightRecords(from records: [SceneObjectRecord]) -> [SceneObjectRecord] {
        records.filter { $0.type == .light }
    }

    private static func lightPromptText(for records: [SceneObjectRecord]) -> String {
        let lights = lightRecords(from: records)
        guard !lights.isEmpty else {
            return "natural ambient lighting"
        }

        if lights.count == 1 {
            let light = lights[0]
            return [
                light.lightPreset?.promptText ?? "custom placed practical light",
                light.colorTemperature?.promptText,
                intensityText(for: light.lightIntensity),
                spreadText(for: light.lightRadius)
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
        }

        let presets = lights
            .prefix(4)
            .compactMap(\.lightPreset?.promptText)
            .joined(separator: ", ")
        return "multi-light cinematic setup with \(presets), varied intensity and spread"
    }

    private static func intensityText(for intensity: Double?) -> String? {
        guard let intensity else { return nil }
        switch intensity {
        case ..<0.35:
            return "soft low intensity"
        case ..<0.7:
            return "medium intensity"
        default:
            return "strong intensity"
        }
    }

    private static func spreadText(for radius: Double?) -> String? {
        guard let radius else { return nil }
        switch radius {
        case ..<0.35:
            return "narrow light spread"
        case ..<0.7:
            return "moderate light spread"
        default:
            return "wide light spread"
        }
    }
}
