import Foundation

/// A local, explainable suggestion derived from an immutable scene snapshot.
/// It never represents an assertion about content the app has not observed.
struct CreativeSuggestion: Identifiable, Equatable {
    enum Category: String, Codable {
        case composition
        case lighting
        case emotion
        case story
    }

    enum Source: String, Codable {
        case localRule
    }

    enum Confidence: String, Codable {
        case certain
        case inferred
        case exploratory

        var displayName: String {
            switch self {
            case .certain: "确定事实"
            case .inferred: "画面推断"
            case .exploratory: "探索方向"
            }
        }
    }

    /// Actions are deliberately limited to values already exposed by the camera UI.
    /// Entity placement and user-authored scene relationships are never changed automatically.
    enum Action: Equatable {
        case setLens(LensPreset)
        case setShotType(ShotType)
        case setLightIntensity(Double)

        var displayName: String {
            switch self {
            case let .setLens(lens): "切换到 \(lens.displayName)"
            case let .setShotType(shotType): "切换到\(shotType.displayName)"
            case let .setLightIntensity(intensity): "将灯光强度调到 \(Int(intensity * 100))%"
            }
        }
    }

    let ruleID: String
    let category: Category
    let observation: String
    let suggestion: String
    let rationale: String
    let source: Source
    let confidence: Confidence
    let action: Action?
    let priority: Int

    var id: String { ruleID }
}
