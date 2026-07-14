import Foundation

enum VideoPromptPlatform: String, CaseIterable, Identifiable {
    case generic
    case sora
    case runway
    case kling

    var id: Self { self }

    var displayName: String {
        switch self {
        case .generic: "通用格式"
        case .sora: "Sora"
        case .runway: "Runway"
        case .kling: "可灵"
        }
    }
}

/// Compatibility presentation for existing screens. `PromptDraft` is the encoded
/// source of truth; these four accessors keep older views and exports readable.
struct StructuredPrompt {
    let draft: PromptDraft

    init(draft: PromptDraft) {
        self.draft = draft
    }

    init(base: String, atmosphere: String, shotMetadata: String, keepElements: String) {
        self.init(draft: PromptDraft(
            subject: base,
            composition: shotMetadata,
            visualStyle: atmosphere,
            mustPreserve: keepElements.isEmpty ? [] : [keepElements],
            fieldSources: [
                "subject": .scene,
                "composition": .scene,
                "visualStyle": .mixed,
                "mustPreserve": .mixed
            ]
        ))
    }

    var base: String {
        [draft.subject, draft.environment].filter { !$0.isEmpty }.joined(separator: "，")
    }

    var atmosphere: String {
        [draft.emotionalIntent, draft.narrativeIntent, draft.visualStyle]
            .filter { !$0.isEmpty }
            .joined(separator: "；")
    }

    var shotMetadata: String {
        [draft.composition, draft.camera, draft.lighting]
            .filter { !$0.isEmpty }
            .joined(separator: "；")
    }

    var keepElements: String {
        draft.mustPreserve.joined(separator: "；")
    }

    var fullText: String {
        PromptRenderer.render(draft)
    }
}

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

    static func makeStructuredPrompt(
        shotType: ShotType,
        frameAspectRatio: FrameAspectRatio,
        lensPreset: LensPreset,
        lightRecords: [SceneObjectRecord],
        filterPreset: FilterPreset,
        hasSubject: Bool,
        locationDescription: String,
        userNote: String = ""
    ) -> StructuredPrompt {
        let location = locationDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLocation = location.isEmpty ? "真实场景" : location
        let note = userNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let subjectSummary = hasSubject ? "画面中包含可调整的人物站位参考" : "画面保留为空间与构图参考"
        let lightSummary = localizedLightSummary(for: lightRecords)
        let lightCount = Self.lightRecords(from: lightRecords).count

        let base = [
            "\(shotType.displayName)",
            "\(frameAspectRatio.displayName) 画幅",
            "\(lensPreset.displayName) 镜头语言",
            subjectSummary,
            "\(filterPreset.displayName)影像质感",
            finalLocation
        ]
        .joined(separator: "，") + "。"

        let atmosphere = [
            note.isEmpty ? nil : "创作者记录：\(note)",
            filterPreset == .realistic ? nil : "使用\(filterPreset.displayName)色彩风格"
        ]
        .compactMap { $0 }
        .joined(separator: "；")

        let shotMetadata = [
            "使用 \(frameAspectRatio.displayName) 构图",
            "\(lensPreset.displayName)",
            "\(shotType.displayName)",
            lightSummary,
            objectPlacementSummary(for: lightRecords)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "；") + "。"

        let keepElements = [
            "保留现场取景的空间纵深、主要光线方向、人物/道具相对关系和画幅构图",
            lightCount > 0 ? "保留已标注灯位对氛围的影响" : nil,
            note.isEmpty ? nil : "保留备注中的情绪线索"
        ]
        .compactMap { $0 }
        .joined(separator: "；") + "。"

        return StructuredPrompt(
            base: base,
            atmosphere: atmosphere,
            shotMetadata: shotMetadata,
            keepElements: keepElements
        )
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

    static func subjectRecords(from records: [SceneObjectRecord]) -> [SceneObjectRecord] {
        records.filter { $0.type == .subject }
    }

    static func propRecords(from records: [SceneObjectRecord]) -> [SceneObjectRecord] {
        records.filter { $0.type == .prop }
    }

    static func structuredPrompt(from entry: LookbookEntry) -> StructuredPrompt {
        StructuredPrompt(draft: draft(from: entry))
    }

    static func content(for entry: LookbookEntry) -> PromptContent {
        if let document = entry.promptDocuments.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            guard let structuredData = document.structuredData else {
                return compatibilityContent(
                    document.canonicalText,
                    reason: "结构化数据缺失，正在使用兼容文本。"
                )
            }
            do {
                return .structured(try PromptDraftDecoder.decode(structuredData, documentVersion: document.schemaVersion))
            } catch {
                return compatibilityContent(
                    document.canonicalText,
                    reason: "\(error.localizedDescription) 正在使用兼容文本。"
                )
            }
        }

        return compatibilityContent(entry.prompt, reason: "此条灵感尚未保存结构化提示词。")
    }

    static func draft(from entry: LookbookEntry) -> PromptDraft {
        if case .structured(let draft) = content(for: entry) {
            return draft
        }
        return PromptDraft()
    }

    static func adaptedPrompt(from entry: LookbookEntry, for platform: VideoPromptPlatform) -> String {
        switch content(for: entry) {
        case .structured(let draft):
            PromptRenderer.render(draft, for: platform)
        case .compatibility(let text, _):
            text
        case .unavailable:
            ""
        }
    }

    private static func compatibilityContent(_ text: String, reason: String) -> PromptContent {
        let resolvedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if resolvedText.isEmpty {
            return .unavailable(reason: reason)
        }
        return .compatibility(text: resolvedText, reason: reason)
    }

    static func layoutRecords(from entry: LookbookEntry) -> [SceneObjectRecord] {
        guard let data = entry.layoutJSON.data(using: .utf8),
              let records = try? JSONDecoder().decode([SceneObjectRecord].self, from: data) else {
            return []
        }
        return records
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

    private static func localizedLightSummary(for records: [SceneObjectRecord]) -> String {
        let lights = lightRecords(from: records)
        guard !lights.isEmpty else {
            return "以现场自然光为主"
        }
        if lights.count == 1 {
            let light = lights[0]
            let preset = light.lightPreset?.displayName ?? "自定义灯光"
            let color = light.colorTemperature?.displayName ?? "默认色温"
            return "\(preset)，\(color)"
        }
        return "\(lights.count) 个灯位共同形成层次化光线"
    }

    private static func objectPlacementSummary(for records: [SceneObjectRecord]) -> String {
        let subjectCount = subjectRecords(from: records).count
        let propCount = propRecords(from: records).count
        let lightCount = lightRecords(from: records).count
        var pieces: [String] = []

        if subjectCount > 0 {
            pieces.append("\(subjectCount) 个角色标记用于表达人物站位")
        }
        if propCount > 0 {
            pieces.append("\(propCount) 个道具标记用于表达空间关系")
        }
        if lightCount > 0 {
            pieces.append("\(lightCount) 个灯位标记用于表达光线方向")
        }
        return pieces.joined(separator: "，")
    }
}
