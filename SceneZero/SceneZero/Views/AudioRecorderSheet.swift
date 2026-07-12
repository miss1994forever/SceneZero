import SwiftUI

struct AudioRecorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = AudioRecordingController()
    @State private var title = ""
    @State private var note = ""
    @State private var errorMessage: String?

    let onSave: (URL, Double, String, String) throws -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "waveform.circle")
                            .font(.system(.largeTitle, design: .rounded))
                            .foregroundStyle(recorder.isRecording ? .red : SceneZeroTheme.accent)
                            .symbolEffect(.pulse, isActive: recorder.isRecording)
                            .accessibilityHidden(true)

                        Text(recorder.duration, format: .number.precision(.fractionLength(1)))
                            .font(.title.monospacedDigit())
                            .contentTransition(.numericText())

                        Button(
                            recorder.isRecording ? "停止录音" : "开始录音",
                            systemImage: recorder.isRecording ? "stop.fill" : "record.circle",
                            action: toggleRecording
                        )
                        .buttonStyle(.borderedProminent)
                        .tint(recorder.isRecording ? .red : SceneZeroTheme.accent)
                        .frame(minHeight: 44)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                } footer: {
                    Text("适合记录语音想法或现场环境声音。录音只保存在此设备。")
                }

                if recorder.temporaryURL != nil {
                    Section("这段声音") {
                        TextField("标题，例如：公交站的雨声", text: $title)
                        TextField("为什么想留下它（可选）", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
            }
            .navigationTitle("记录声音")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(recorder.isRecording)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(recorder.isRecording || recorder.temporaryURL == nil)
                }
            }
            .alert("无法保存声音", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) { } message: {
                Text(errorMessage ?? "")
            }
        }
        .onDisappear {
            recorder.discard()
        }
    }

    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stop()
        } else {
            Task {
                do {
                    try await recorder.start()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func cancel() {
        recorder.discard()
        dismiss()
    }

    private func save() {
        guard let url = recorder.temporaryURL else { return }
        do {
            try onSave(url, recorder.duration, title, note)
            try? FileManager.default.removeItem(at: url)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
