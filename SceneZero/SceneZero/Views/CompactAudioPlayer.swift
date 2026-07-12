import AVFoundation
import SwiftUI

struct CompactAudioPlayer: View {
    @State private var player: AVPlayer
    @State private var isPlaying = false

    let title: String
    let subtitle: String
    let duration: Double

    init(url: URL, title: String, subtitle: String, duration: Double) {
        _player = State(initialValue: AVPlayer(url: url))
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(
                isPlaying ? "暂停" : "播放",
                systemImage: isPlaying ? "pause.fill" : "play.fill",
                action: togglePlayback
            )
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 44)
            .background(SceneZeroTheme.accentSoft, in: .circle)
            .accessibilityLabel(isPlaying ? "暂停声音" : "播放声音")

            VStack(alignment: .leading, spacing: 4) {
                Text(title.isEmpty ? "声音记录" : title)
                    .font(.headline)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(SceneZeroTheme.secondaryBackground, in: .rect(cornerRadius: 14))
        .onDisappear {
            player.pause()
            isPlaying = false
        }
    }

    private func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            if player.currentItem?.currentTime() == player.currentItem?.duration {
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
    }
}
