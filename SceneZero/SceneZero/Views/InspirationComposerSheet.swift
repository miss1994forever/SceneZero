import SwiftUI

enum InspirationComposerKind: String, Identifiable {
    case text
    case music

    var id: Self { self }
}

struct InspirationComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var artist = ""
    @State private var link = ""

    let kind: InspirationComposerKind
    let onSave: (String, String, String, URL?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(kind == .text ? "灵感" : "音乐") {
                    TextField(titlePlaceholder, text: $title)

                    if kind == .music {
                        TextField("音乐人或声音来源", text: $artist)
                        TextField("Apple Music 或其他链接（可选）", text: $link)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }

                    TextField(contentPlaceholder, text: $content, axis: .vertical)
                        .lineLimit(5...12)
                }
            }
            .navigationTitle(kind == .text ? "文字灵感" : "添加音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var titlePlaceholder: String {
        kind == .text ? "一句话标题（可选）" : "歌曲或音乐名称"
    }

    private var contentPlaceholder: String {
        kind == .text
            ? "记录一个事件、画面、故事碎片或难以命名的情绪……"
            : "这段音乐让你想到什么？它和这个故事有什么关系？"
    }

    private var canSave: Bool {
        switch kind {
        case .text:
            !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .music:
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func save() {
        let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines))
        onSave(
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            content.trimmingCharacters(in: .whitespacesAndNewlines),
            artist.trimmingCharacters(in: .whitespacesAndNewlines),
            url
        )
        dismiss()
    }
}
