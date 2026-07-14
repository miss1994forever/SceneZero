import AVFoundation
import SwiftUI

struct CompactAudioPlayer: View {
    @State private var playbackController: AudioPlaybackController

    let title: String
    let subtitle: String
    let duration: Double

    init(url: URL, title: String, subtitle: String, duration: Double) {
        _playbackController = State(
            initialValue: AudioPlaybackController(url: url, fallbackDuration: duration)
        )
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(
                playbackController.isPlaying ? "暂停" : "播放",
                systemImage: playbackController.isPlaying ? "pause.fill" : "play.fill",
                action: playbackController.togglePlayback
            )
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 44)
            .background(SceneZeroTheme.accentSoft, in: .circle)
            .accessibilityLabel(playbackController.isPlaying ? "暂停声音" : "播放声音")

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

            VStack(alignment: .trailing, spacing: 6) {
                Text(timeLabel)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)

                ProgressView(value: playbackProgress)
                    .tint(SceneZeroTheme.accent)
                    .frame(width: 92)
                    .accessibilityLabel("播放进度")
                    .accessibilityValue(timeLabel)
            }
        }
        .padding(12)
        .background(SceneZeroTheme.secondaryBackground, in: .rect(cornerRadius: 14))
        .onDisappear {
            playbackController.dispose()
        }
    }

    private var playbackProgress: Double {
        guard playbackController.duration > 0 else { return 0 }
        return min(max(playbackController.currentTime / playbackController.duration, 0), 1)
    }

    private var timeLabel: String {
        "\(formattedTime(playbackController.currentTime)) / \(formattedTime(playbackController.duration))"
    }

    private func formattedTime(_ seconds: Double) -> String {
        Duration.seconds(max(0, seconds)).formatted(.time(pattern: .minuteSecond))
    }
}
