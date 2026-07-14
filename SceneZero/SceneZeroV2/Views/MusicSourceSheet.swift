import SwiftUI

struct MusicSourceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onImportFile: () -> Void
    let onRecordReference: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    sourceButton(
                        title: "从文件导入",
                        detail: "MP3、M4A、WAV 等本地音频会复制到此设备",
                        systemImage: "folder.badge.plus"
                    ) {
                        dismiss()
                        onImportFile()
                    }

                    sourceButton(
                        title: "记录歌曲或链接",
                        detail: "保存歌曲名、来源和它带来的创作联想",
                        systemImage: "music.note.list"
                    ) {
                        dismiss()
                        onRecordReference()
                    }
                } header: {
                    Text("选择音乐来源")
                } footer: {
                    Text("受保护的 Apple Music 内容不能作为普通文件导入；可使用“记录歌曲或链接”保存引用。")
                }
            }
            .navigationTitle("添加音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func sourceButton(
        title: String,
        detail: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(SceneZeroTheme.accent)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .accessibilityHint(detail)
    }
}
