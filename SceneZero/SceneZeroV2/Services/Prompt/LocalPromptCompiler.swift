import Foundation

/// Deterministic, offline prompt generation. It only writes facts from the snapshot
/// and explicit creator intent, so an unavailable network can never block a capture.
struct LocalPromptCompiler {
    func compile(snapshot: SceneSnapshot, intent: CreatorIntent = .init()) -> PromptDraft {
        let subjects = snapshot.entities.filter { $0.type == .subject }
        let props = snapshot.entities.filter { $0.type == .prop }
        let entities = subjects + props
        let trimmedLocation = intentValue(snapshot.locationDescription)
        let subject = subjectText(for: subjects)
        let composition = compositionText(for: entities)
        let lighting = lightingText(for: snapshot.lights)
        let userNarrative = intentValue(intent.narrativeIntent)
        let userEmotion = intentValue(intent.emotionalIntent)
        let userRelationship = intentValue(intent.relationshipIntent)
        let preserve = preserveFacts(snapshot: snapshot, intent: intent)
        let uncertainty = uncertaintyFacts(
            hasSubjects: !subjects.isEmpty,
            hasLocation: !trimmedLocation.isEmpty,
            hasIntent: !userNarrative.isEmpty || !userEmotion.isEmpty || !userRelationship.isEmpty
        )

        return PromptDraft(
            subject: subject,
            action: "",
            environment: trimmedLocation,
            composition: composition,
            camera: "(snapshot.frameAspectRatio.displayName) 画幅，(snapshot.lensPreset.displayName)，(snapshot.shotType.displayName)。",
            lighting: lighting,
            visualStyle: snapshot.filterPreset == .realistic ? "写实色彩风格。" : "(snapshot.filterPreset.displayName)色彩风格。",
            emotionalIntent: userEmotion,
            narrativeIntent: combineNonEmpty([userNarrative, userRelationship], separator: "；"),
            motionSuggestion: "",
            mustPreserve: preserve,
            avoid: intent.avoid,
            uncertainties: uncertainty,
            fieldSources: [
                "subject": subjects.isEmpty ? .unknown : .scene,
                "action": .unknown,
                "environment": trimmedLocation.isEmpty ? .unknown : .scene,
                "composition": entities.isEmpty ? .unknown : .scene,
                "camera": .scene,
                "lighting": snapshot.lights.isEmpty ? .unknown : .scene,
                "visualStyle": .scene,
                "emotionalIntent": userEmotion.isEmpty ? .unknown : .creator,
                "narrativeIntent": userNarrative.isEmpty && userRelationship.isEmpty ? .unknown : .creator,
                "motionSuggestion": .unknown,
                "mustPreserve": intent.mustPreserve.isEmpty ? .scene : .mixed,
                "avoid": intent.avoid.isEmpty ? .unknown : .creator,
                "uncertainties": .unknown
            ]
        )
    }

    private func subjectText(for subjects: [SceneEntitySnapshot]) -> String {
        guard !subjects.isEmpty else { return "" }
        let groupedSubjects = Dictionary(grouping: subjects) { subjectName(for: $0) }
        let summary = groupedSubjects
            .keys
            .sorted()
            .map { name in "\(name) ×\(groupedSubjects[name, default: []].count)" }
            .joined(separator: "，")
        return "\(summary)。"
    }

    private func compositionText(for entities: [SceneEntitySnapshot]) -> String {
        guard !entities.isEmpty else { return "" }
        return entities
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { entity in
                let facing = entity.facing.promptText.map { "，\($0)" } ?? ""
                return "\(subjectName(for: entity))位于\(entity.horizontalZone.promptText)\(entity.depthZone.promptText)\(facing)"
            }
            .joined(separator: "；") + "。"
    }

    private func lightingText(for lights: [LightingSnapshot]) -> String {
        guard !lights.isEmpty else { return "" }
        return lights.map { light in
            let preset = light.preset?.displayName ?? "自定义灯位"
            let temperature = light.colorTemperature?.displayName ?? "未标注色温"
            let intensity = light.intensity.map { "，强度\(Int(($0 * 100).rounded()))%" } ?? ""
            return "\(preset)位于\(light.horizontalZone.promptText)\(light.depthZone.promptText)，\(temperature)\(intensity)"
        }
        .joined(separator: "；") + "。"
    }

    private func preserveFacts(snapshot: SceneSnapshot, intent: CreatorIntent) -> [String] {
        var facts = [
            "保留\(snapshot.frameAspectRatio.displayName)画幅、\(snapshot.lensPreset.displayName)与\(snapshot.shotType.displayName)",
            "保留已标记的人物、道具与灯位的相对位置"
        ]
        if !snapshot.lights.isEmpty {
            facts.append("保留已标记灯光的方向、色温与强度")
        }
        facts.append(contentsOf: intent.mustPreserve.filter { !intentValue($0).isEmpty })
        return facts
    }

    private func uncertaintyFacts(hasSubjects: Bool, hasLocation: Bool, hasIntent: Bool) -> [String] {
        var facts = ["人物动作与镜头运动尚未标注，不自行补充"]
        if !hasSubjects {
            facts.append("画面主体尚未用 AR 标记确认")
        }
        if !hasLocation {
            facts.append("现场环境语义尚未记录")
        }
        if !hasIntent {
            facts.append("创作者的情绪与叙事意图尚未记录")
        }
        return facts
    }

    private func subjectName(for entity: SceneEntitySnapshot) -> String {
        entity.assetPreset?.displayName ?? entity.type.displayName
    }

    private func intentValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func combineNonEmpty(_ values: [String], separator: String) -> String {
        values.filter { !$0.isEmpty }.joined(separator: separator)
    }
}
