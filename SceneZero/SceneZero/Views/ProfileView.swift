import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query private var entries: [LookbookEntry]
    @Query private var boards: [LookbookBoard]

    @AppStorage("usesRealityKitModelLighting") private var usesRealityKitModelLighting = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text("S")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                SceneZeroTheme.accent,
                                                SceneZeroTheme.accent.opacity(0.72)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("SceneZero Creator")
                                .font(.headline)
                            Text("本地创作空间")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("灵感") {
                    statRow("灵感记录", value: entries.count, systemImage: "photo.on.rectangle", tint: SceneZeroTheme.accent)
                    statRow(
                        "灵感集",
                        value: boards.count + 2,
                        systemImage: "rectangle.stack",
                        tint: SceneZeroTheme.accent
                    )
                    statRow(
                        "收藏",
                        value: entries.filter(\.isFavorite).count,
                        systemImage: "heart",
                        tint: SceneZeroTheme.accent
                    )
                }

                Section {
                    Toggle(isOn: $usesRealityKitModelLighting) {
                        Label("3D 模型灯光", systemImage: "lightbulb.max")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .tint(SceneZeroTheme.accent)
                } header: {
                    Text("AR 与性能")
                } footer: {
                    Text("灯光叠层会保持稳定的实时预览。3D 模型灯光会向 RealityKit 模型添加光源，在部分设备上可能影响稳定性。")
                }
                .foregroundStyle(.primary)

                Section {
                    Text("当前课程版本仅使用本地资料。账号、云同步和公开分享属于后续功能。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("我的")
            .scrollContentBackground(.hidden)
            .background(SceneZeroTheme.background)
            .tint(SceneZeroTheme.accent)
        }
    }

    private func statRow(_ title: String, value: Int, systemImage: String, tint: Color) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.primary, tint)
            Spacer()
            Text(value, format: .number)
                .font(.headline.monospacedDigit())
                .foregroundStyle(tint)
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [LookbookEntry.self, InspirationAsset.self, LookbookBoard.self, SceneProject.self], inMemory: true)
}
