import Foundation

struct PromptService {
    static func makePrompt(
        shotType: ShotType,
        lightPreset: LightPreset,
        colorTemperature: ColorTemperature,
        filterPreset: FilterPreset,
        hasSubject: Bool,
        locationDescription: String
    ) -> String {
        let subject = hasSubject ? "subject placed as the spatial anchor" : "empty scene with spatial placeholders"
        let location = locationDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLocation = location.isEmpty ? "realistic interior location" : location

        return [
            shotType.promptText,
            subject,
            lightPreset.promptText,
            colorTemperature.promptText,
            filterPreset.promptText,
            finalLocation
        ].joined(separator: ", ") + "."
    }
}
