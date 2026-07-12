import SwiftUI

struct InspirationCard: View {
    let entry: LookbookEntry

    private let imageStorage = ImageStorageService()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardContent

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: entry.inspirationKind.systemImage)
                        .foregroundStyle(SceneZeroTheme.accent)
                        .accessibilityHidden(true)

                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    if entry.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                            .accessibilityLabel("已收藏")
                    }
                }

                if !entry.note.isEmpty && entry.inspirationKind != .text {
                    Text(entry.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Text(entry.createdAt, format: .dateTime.month().day())
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .groupedCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var cardContent: some View {
        switch entry.inspirationKind {
        case .image:
            imageContent
        case .text:
            textContent
        case .audio:
            mediaSymbolContent(
                systemImage: "waveform",
                title: durationText,
                colors: [SceneZeroTheme.accentSoft, SceneZeroTheme.secondaryBackground]
            )
        case .video:
            if entry.imagePath.isEmpty {
                mediaSymbolContent(
                    systemImage: "video.fill",
                    title: durationText,
                    colors: [SceneZeroTheme.infoAccentSoft, SceneZeroTheme.secondaryBackground]
                )
            } else {
                imageContent.overlay(alignment: .bottomTrailing) {
                    Label(durationText, systemImage: "play.fill")
                        .font(.footnote.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: .capsule)
                        .padding(8)
                }
            }
        case .music:
            mediaSymbolContent(
                systemImage: "music.note",
                title: entry.primaryAsset?.subtitle ?? "音乐",
                colors: [SceneZeroTheme.promptAccent.opacity(0.18), SceneZeroTheme.secondaryBackground]
            )
        }
    }

    private var imageContent: some View {
        Group {
            if let image = imageStorage.load(relativePath: entry.imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(clampedAspectRatio(for: image), contentMode: .fit)
            } else {
                ContentUnavailableView("图片不可用", systemImage: "photo")
                    .frame(minHeight: 120)
            }
        }
        .clipShape(.rect(cornerRadius: 12))
    }

    private var textContent: some View {
        Text(entry.primaryAsset?.textContent ?? entry.note)
            .font(.body)
            .foregroundStyle(.primary)
            .lineLimit(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(SceneZeroTheme.secondaryBackground, in: .rect(cornerRadius: 12))
    }

    private func mediaSymbolContent(
        systemImage: String,
        title: String,
        colors: [Color]
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.subheadline.monospacedDigit())
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 12)
        )
    }

    private var displayTitle: String {
        if !entry.title.isEmpty { return entry.title }
        return entry.inspirationKind.displayName
    }

    private var durationText: String {
        let duration = entry.primaryAsset?.duration ?? 0
        return Duration.seconds(duration).formatted(.time(pattern: .minuteSecond))
    }

    private var accessibilitySummary: String {
        "\(entry.inspirationKind.displayName)灵感，\(displayTitle)"
    }

    private func clampedAspectRatio(for image: UIImage) -> Double {
        guard image.size.height > 0 else { return 1 }
        return min(1.6, max(0.75, image.size.width / image.size.height))
    }
}
