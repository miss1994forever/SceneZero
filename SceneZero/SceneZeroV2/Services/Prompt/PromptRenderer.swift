import Foundation

enum PromptRenderer {
    static func render(_ draft: PromptDraft, for platform: VideoPromptPlatform = .generic) -> String {
        switch platform {
        case .generic:
            genericText(for: draft)
        case .sora:
            soraText(for: draft)
        case .runway:
            runwayText(for: draft)
        case .kling:
            klingText(for: draft)
        }
    }

    private static func genericText(for draft: PromptDraft) -> String {
        fieldLines(for: draft).joined(separator: "\n\n")
    }

    private static func soraText(for draft: PromptDraft) -> String {
        [
            labeled("Subject", draft.subject),
            labeled("Environment", draft.environment),
            labeled("Composition", draft.composition),
            labeled("Cinematography", draft.camera),
            labeled("Lighting", draft.lighting),
            labeled("Visual style", draft.visualStyle),
            labeled("Creator intent", combinedIntent(for: draft)),
            list("Must preserve", draft.mustPreserve),
            list("Avoid", draft.avoid)
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private static func runwayText(for draft: PromptDraft) -> String {
        [
            draft.subject,
            draft.environment,
            draft.composition,
            draft.camera,
            draft.lighting,
            draft.visualStyle,
            combinedIntent(for: draft),
            draft.mustPreserve.isEmpty ? "" : "Preserve: \(draft.mustPreserve.joined(separator: "; ")).",
            draft.avoid.isEmpty ? "" : "Avoid: \(draft.avoid.joined(separator: "; "))."
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    private static func klingText(for draft: PromptDraft) -> String {
        [
            labeled("主体", draft.subject),
            labeled("环境", draft.environment),
            labeled("构图", draft.composition),
            labeled("镜头", draft.camera),
            labeled("灯光", draft.lighting),
            labeled("风格", draft.visualStyle),
            labeled("创作意图", combinedIntent(for: draft)),
            list("必须保留", draft.mustPreserve),
            list("避免", draft.avoid)
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private static func fieldLines(for draft: PromptDraft) -> [String] {
        [
            labeled("主体", draft.subject),
            labeled("动作", draft.action),
            labeled("环境", draft.environment),
            labeled("构图", draft.composition),
            labeled("镜头", draft.camera),
            labeled("灯光", draft.lighting),
            labeled("视觉风格", draft.visualStyle),
            labeled("情绪意图", draft.emotionalIntent),
            labeled("叙事意图", draft.narrativeIntent),
            labeled("运动建议", draft.motionSuggestion),
            list("必须保留", draft.mustPreserve),
            list("避免", draft.avoid),
            list("待确认", draft.uncertainties)
        ]
        .compactMap { $0 }
    }

    private static func labeled(_ title: String, _ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : "\(title)：\(trimmed)"
    }

    private static func list(_ title: String, _ values: [String]) -> String? {
        let resolved = values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !resolved.isEmpty else { return nil }
        return "\(title)：\(resolved.joined(separator: "；"))。"
    }

    private static func combinedIntent(for draft: PromptDraft) -> String {
        [draft.emotionalIntent, draft.narrativeIntent]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "；")
    }
}
