import Foundation

enum PromptFieldSource: String, Codable, CaseIterable {
    case scene = "现场"
    case creator = "用户"
    case model = "AI"
    case mixed = "现场与用户"
    case unknown = "待确认"
}

struct PromptDraft: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var subject: String
    var action: String
    var environment: String
    var composition: String
    var camera: String
    var lighting: String
    var visualStyle: String
    var emotionalIntent: String
    var narrativeIntent: String
    var motionSuggestion: String
    var mustPreserve: [String]
    var avoid: [String]
    var uncertainties: [String]
    var fieldSources: [String: PromptFieldSource]

    init(
        subject: String = "",
        action: String = "",
        environment: String = "",
        composition: String = "",
        camera: String = "",
        lighting: String = "",
        visualStyle: String = "",
        emotionalIntent: String = "",
        narrativeIntent: String = "",
        motionSuggestion: String = "",
        mustPreserve: [String] = [],
        avoid: [String] = [],
        uncertainties: [String] = [],
        fieldSources: [String: PromptFieldSource] = [:]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.subject = subject
        self.action = action
        self.environment = environment
        self.composition = composition
        self.camera = camera
        self.lighting = lighting
        self.visualStyle = visualStyle
        self.emotionalIntent = emotionalIntent
        self.narrativeIntent = narrativeIntent
        self.motionSuggestion = motionSuggestion
        self.mustPreserve = mustPreserve
        self.avoid = avoid
        self.uncertainties = uncertainties
        self.fieldSources = fieldSources
    }

    func source(for field: String) -> PromptFieldSource {
        fieldSources[field] ?? .unknown
    }
}
