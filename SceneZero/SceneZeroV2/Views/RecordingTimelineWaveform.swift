import SwiftUI

struct RecordingTimelineWaveform: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let levels: [Double]

    var body: some View {
        GeometryReader { proxy in
            let visibleLevels = Array(levels.suffix(46))
            let unitWidth = proxy.size.width / 46
            let barWidth = min(4, max(2, unitWidth * 0.46))
            let spacing = max(2, unitWidth - barWidth)

            HStack(alignment: .center, spacing: spacing) {
                ForEach(visibleLevels.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.tertiary)
                        .frame(width: barWidth, height: barHeight(for: visibleLevels[index], in: proxy.size.height))
                        .frame(height: proxy.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在录音，音频波形随输入更新")
    }

    private func barHeight(for level: Double, in availableHeight: Double) -> Double {
        let effectiveLevel = reduceMotion ? 0 : min(max(level, 0), 1)
        return 5 + (effectiveLevel * (availableHeight - 5))
    }
}
