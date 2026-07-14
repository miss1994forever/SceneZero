import SwiftUI

struct PhoneToolPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedTool: SceneTool

    var body: some View {
        NavigationStack {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 76), spacing: 12)],
                spacing: 12
            ) {
                ForEach(SceneTool.allCases) { tool in
                    Button {
                        selectedTool = tool
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: tool.systemImage)
                                .font(.title3.weight(.semibold))
                            Text(tool.displayName)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(selectedTool == tool ? Color.black : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selectedTool == tool ? SceneZeroTheme.accent : SceneZeroTheme.cardBackground)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("选择\(tool.displayName)")
                    .accessibilityAddTraits(selectedTool == tool ? .isSelected : [])
                }
            }
            .padding(20)
            .navigationTitle("选择工具")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", action: dismiss.callAsFunction)
                }
            }
        }
    }
}
