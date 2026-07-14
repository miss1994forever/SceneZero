import SwiftUI

struct CreativeSuggestionSheet: View {
    let suggestions: [CreativeSuggestion]
    let currentIndex: Int
    let onApply: () -> Void
    let onSwap: () -> Void
    let onIgnore: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var suggestion: CreativeSuggestion? {
        suggestions.indices.contains(currentIndex) ? suggestions[currentIndex] : nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if let suggestion {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header(for: suggestion)
                            suggestionContent(for: suggestion)
                            actionButtons(for: suggestion)
                        }
                        .padding(20)
                    }
                } else {
                    ContentUnavailableView(
                        "暂时没有建议",
                        systemImage: "lightbulb.slash",
                        description: Text("放置角色、道具或灯位后，再点按灯泡重新查看。")
                    )
                }
            }
            .background(SceneZeroTheme.background)
            .navigationTitle("创作建议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func header(for suggestion: CreativeSuggestion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName(for: suggestion.category))
                .font(.title3.weight(.semibold))
                .foregroundStyle(SceneZeroTheme.accent)
                .frame(width: 44, height: 44)
                .background(SceneZeroTheme.accentSoft, in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(categoryName(for: suggestion.category))
                    .font(.headline)
                Text("\(suggestion.confidence.displayName) · 本地规则")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if suggestions.count > 1 {
                Text("\(currentIndex + 1)/\(suggestions.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func suggestionContent(for suggestion: CreativeSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            detailRow(title: "我看到", text: suggestion.observation)
            detailRow(title: "可以试试", text: suggestion.suggestion)
            detailRow(title: "为什么", text: suggestion.rationale)
        }
        .padding(18)
        .groupedCard(cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("观察：\(suggestion.observation)。建议：\(suggestion.suggestion)。原因：\(suggestion.rationale)")
    }

    private func detailRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SceneZeroTheme.accent)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func actionButtons(for suggestion: CreativeSuggestion) -> some View {
        VStack(spacing: 10) {
            if let action = suggestion.action {
                Button {
                    onApply()
                } label: {
                    Label("应用：\(action.displayName)", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(SceneZeroTheme.accent)
                .accessibilityHint("只修改当前取景的镜头或灯光参数")
            }

            HStack(spacing: 10) {
                if suggestions.count > 1 {
                    Button("换一个", systemImage: "arrow.triangle.2.circlepath") {
                        onSwap()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }

                Button("忽略", systemImage: "xmark") {
                    onIgnore()
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func categoryName(for category: CreativeSuggestion.Category) -> String {
        switch category {
        case .composition: "构图"
        case .lighting: "灯光"
        case .emotion: "情绪"
        case .story: "叙事"
        }
    }

    private func iconName(for category: CreativeSuggestion.Category) -> String {
        switch category {
        case .composition: "viewfinder"
        case .lighting: "lightbulb"
        case .emotion: "theatermasks"
        case .story: "text.book.closed"
        }
    }
}
