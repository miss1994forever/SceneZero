import Foundation
import simd

/// Deterministic, offline creative guidance. Rules use only `SceneSnapshot` and
/// explicitly supplied intent, so their output is repeatable and explainable.
struct LocalCreativeAdvisor {
    func advise(snapshot: SceneSnapshot, intent: CreatorIntent = .init()) -> [CreativeSuggestion] {
        let subjects = snapshot.entities.filter { $0.type == .subject }
        let props = snapshot.entities.filter { $0.type == .prop }
        let lights = snapshot.lights
        var suggestions: [CreativeSuggestion] = []

        guard snapshot.camera.isTrackingPoseAvailable else {
            return [makeSuggestion(
                ruleID: "tracking_unavailable",
                category: .composition,
                observation: "AR 定位尚未稳定，当前空间关系不够可靠。",
                suggestion: "先缓慢扫描平面，待定位稳定后再判断构图。",
                rationale: "建议只应建立在可靠的相机与空间坐标上。",
                confidence: .certain,
                priority: 100
            )]
        }

        if subjects.isEmpty {
            suggestions.append(makeSuggestion(
                ruleID: "environment_without_subject",
                category: .story,
                observation: "当前场景没有角色标记，画面将主要由空间和道具承担叙事。",
                suggestion: "先决定环境本身是不是主体；若不是，再放入一个角色作为观看锚点。",
                rationale: "明确主体能让后续构图和镜头选择更有依据。",
                confidence: .certain,
                priority: 96
            ))
        }

        if subjects.count >= 2, Set(subjects.map(\.horizontalZone)).count == 1 {
            suggestions.append(makeSuggestion(
                ruleID: "subjects_same_side",
                category: .composition,
                observation: "多个角色都集中在画面同一侧。",
                suggestion: "若想强化关系张力，可把其中一个角色留在原位，另一个移向对侧或后景。",
                rationale: "左右与前后层次会让角色之间的距离更容易被读到。",
                confidence: .certain,
                priority: 86
            ))
        }

        if let subject = subjects.first,
           props.contains(where: { $0.horizontalZone == subject.horizontalZone && $0.depthZone == subject.depthZone }) {
            suggestions.append(makeSuggestion(
                ruleID: "subject_prop_relation_unclear",
                category: .composition,
                observation: "角色与至少一个道具落在同一画面分区，彼此关系不容易分辨。",
                suggestion: "可把道具移到角色的左后或右后方，给两者留出可读的间隔。",
                rationale: "分离位置能让道具成为关系线索，而不是与主体重叠。",
                confidence: .inferred,
                priority: 74
            ))
        }

        let nearestSubjectDepth = subjects.map(depth).min()
        let farthestEntityDepth = snapshot.entities.map(depth).max() ?? 0

        if snapshot.lensPreset == .portrait85, farthestEntityDepth < 3.2 {
            suggestions.append(makeSuggestion(
                ruleID: "portrait_lens_in_small_space",
                category: .composition,
                observation: "85mm 镜头配合当前较近的场景，会明显压缩空间纵深。",
                suggestion: "若希望保留环境信息，可先尝试 35mm。",
                rationale: "较广的焦距能在不移动现有标记的情况下容纳更多环境关系。",
                confidence: .certain,
                action: .setLens(.standard35),
                priority: 92
            ))
        }

        if snapshot.lensPreset == .wide24, let nearestSubjectDepth, nearestSubjectDepth < 1.2 {
            suggestions.append(makeSuggestion(
                ruleID: "wide_lens_subject_too_close",
                category: .composition,
                observation: "24mm 镜头下有角色离镜头很近，边缘透视可能变得夸张。",
                suggestion: "若不想要夸张透视，可改用 35mm；若保留 24mm，可把角色略微后移。",
                rationale: "35mm 会保留空间感，同时让近处角色的比例更自然。",
                confidence: .certain,
                action: .setLens(.standard35),
                priority: 90
            ))
        }

        if lights.count == 1, lights.first?.preset == .frontSoft {
            suggestions.append(makeSuggestion(
                ruleID: "single_frontal_light",
                category: .lighting,
                observation: "当前只有一盏正面柔光，主体表面的明暗层次会较平。",
                suggestion: "可降低一点正面光强，或手动把灯位改到左前 45°。",
                rationale: "减弱正面光能让现场环境光参与塑形；改变灯位需要你确认方向。",
                confidence: .certain,
                action: .setLightIntensity(0.45),
                priority: 82
            ))
        }

        if lights.count == 1, lights.first?.preset == .rimRight {
            suggestions.append(makeSuggestion(
                ruleID: "backlight_without_fill",
                category: .lighting,
                observation: "当前只有右后方轮廓光，主体正面细节可能不足。",
                suggestion: "若需要看清表情，可手动补一盏低强度前侧光；若想保留剪影，可维持现状。",
                rationale: "轮廓光擅长分离主体与背景，但不保证主体正面可读。",
                confidence: .certain,
                priority: 78
            ))
        }

        if lights.count >= 2,
           Set(lights.compactMap(\.preset)).count >= 2,
           lights.contains(where: { $0.preset == .frontSoft }) {
            suggestions.append(makeSuggestion(
                ruleID: "mixed_light_directions",
                category: .lighting,
                observation: "场景中有多种灯光方向，正面光可能会冲淡其他灯位的效果。",
                suggestion: "可先降低正面光强，再判断轮廓或侧光是否更清楚。",
                rationale: "先减少一个主导变量，能更容易看出光线对画面的实际影响。",
                confidence: .inferred,
                action: .setLightIntensity(0.45),
                priority: 72
            ))
        }

        if intent.containsAny(of: ["疏离", "距离", "陌生"]), subjects.count >= 2,
           minimumDistance(between: subjects) < 1.2 {
            suggestions.append(makeSuggestion(
                ruleID: "isolation_intent_with_close_subjects",
                category: .emotion,
                observation: "你的意图包含疏离感，但角色之间的空间距离较近。",
                suggestion: "可以拉开两人的左右或前后距离，并把其中一人留在后景。",
                rationale: "空间距离是表达关系疏离的直接、可控线索。",
                confidence: .inferred,
                priority: 88
            ))
        }

        if intent.containsAny(of: ["压迫", "压抑", "窒息"]), snapshot.lensPreset == .wide24,
           farthestEntityDepth > 4 {
            suggestions.append(makeSuggestion(
                ruleID: "pressure_intent_with_open_depth",
                category: .emotion,
                observation: "你的意图包含压迫感，但 24mm 与较深空间会让画面显得开阔。",
                suggestion: "可先尝试 50mm，让空间关系更紧一些。",
                rationale: "较长焦距会压缩前后距离，但是否保留开阔感仍由你决定。",
                confidence: .inferred,
                action: .setLens(.normal50),
                priority: 84
            ))
        }

        return suggestions.sorted {
            $0.priority == $1.priority ? $0.ruleID < $1.ruleID : $0.priority > $1.priority
        }
    }

    private func makeSuggestion(
        ruleID: String,
        category: CreativeSuggestion.Category,
        observation: String,
        suggestion: String,
        rationale: String,
        confidence: CreativeSuggestion.Confidence,
        action: CreativeSuggestion.Action? = nil,
        priority: Int
    ) -> CreativeSuggestion {
        CreativeSuggestion(
            ruleID: ruleID,
            category: category,
            observation: observation,
            suggestion: suggestion,
            rationale: rationale,
            source: .localRule,
            confidence: confidence,
            action: action,
            priority: priority
        )
    }

    private func depth(of entity: SceneEntitySnapshot) -> Float {
        guard entity.cameraPosition.count > 2 else { return .greatestFiniteMagnitude }
        return max(0, -entity.cameraPosition[2])
    }

    private func minimumDistance(between entities: [SceneEntitySnapshot]) -> Float {
        guard entities.count >= 2 else { return .greatestFiniteMagnitude }
        var closest = Float.greatestFiniteMagnitude
        for firstIndex in entities.indices {
            for secondIndex in entities.indices.dropFirst(firstIndex + 1) {
                let first = worldPosition(of: entities[firstIndex])
                let second = worldPosition(of: entities[secondIndex])
                closest = min(closest, simd_distance(first, second))
            }
        }
        return closest
    }

    private func worldPosition(of entity: SceneEntitySnapshot) -> SIMD3<Float> {
        let values = entity.worldPosition
        guard values.count >= 3 else { return .zero }
        return SIMD3(values[0], values[1], values[2])
    }
}

private extension CreatorIntent {
    func containsAny(of keywords: [String]) -> Bool {
        let value = [narrativeIntent, emotionalIntent, relationshipIntent, mustPreserve.joined(separator: " "), avoid.joined(separator: " ")]
            .joined(separator: " ")
        return keywords.contains { value.localizedCaseInsensitiveContains($0) }
    }
}
