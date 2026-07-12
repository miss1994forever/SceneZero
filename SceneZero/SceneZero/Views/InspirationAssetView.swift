import SwiftUI

struct InspirationAssetView: View {
    let asset: InspirationAsset

    private let imageStorage = ImageStorageService()
    private let mediaStorage = InspirationMediaStorageService()

    var body: some View {
        Group {
            switch asset.kind {
            case .image:
                imageView
            case .text:
                textView
            case .audio:
                audioView
            case .video:
                videoView
            case .music:
                musicView
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var imageView: some View {
        if let path = asset.relativePath,
           let image = imageStorage.load(relativePath: path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: 14))
                .accessibilityLabel(asset.title.isEmpty ? "灵感照片" : asset.title)
        } else {
            ContentUnavailableView("图片不可用", systemImage: "photo")
        }
    }

    private var textView: some View {
        Text(asset.textContent)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(SceneZeroTheme.secondaryBackground, in: .rect(cornerRadius: 14))
    }

    @ViewBuilder
    private var audioView: some View {
        if let path = asset.relativePath,
           let url = mediaStorage.fileURL(relativePath: path) {
            CompactAudioPlayer(
                url: url,
                title: asset.title,
                subtitle: asset.textContent,
                duration: asset.duration
            )
        } else {
            ContentUnavailableView("声音文件不可用", systemImage: "waveform.slash")
        }
    }

    @ViewBuilder
    private var videoView: some View {
        if let path = asset.relativePath,
           let url = mediaStorage.fileURL(relativePath: path) {
            LocalVideoPlayer(url: url)
        } else {
            ContentUnavailableView("视频文件不可用", systemImage: "video.slash")
        }
    }

    private var musicView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(asset.title.isEmpty ? "音乐" : asset.title, systemImage: "music.note")
                .font(.headline)

            if !asset.subtitle.isEmpty {
                Text(asset.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !asset.textContent.isEmpty {
                Text(asset.textContent)
                    .font(.body)
            }

            if let url = asset.externalURL {
                Link(destination: url) {
                    Label("打开音乐链接", systemImage: "arrow.up.right.square")
                        .frame(minHeight: 44)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(SceneZeroTheme.promptAccent.opacity(0.12), in: .rect(cornerRadius: 14))
    }
}
