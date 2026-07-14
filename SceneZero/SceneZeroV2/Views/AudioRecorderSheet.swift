import SwiftUI

struct AudioRecorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var recorder = AudioRecordingController()
    @State private var title = ""
    @State private var note = ""
    @State private var errorTitle = "无法完成录音"
    @State private var errorMessage: String?

    let onSave: (URL, Double, String, String) throws -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        if !recorder.isRecording {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(.largeTitle, design: .rounded))
                                .foregroundStyle(SceneZeroTheme.accent)
                                .accessibilityHidden(true)
                        }

                        Text(recorder.duration, format: .number.precision(.fractionLength(1)))
                            .font(.title.monospacedDigit())
                            .contentTransition(.numericText())

                        Button(action: toggleRecording) {
                            HStack(spacing: 8) {
                                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                Text(recorder.isRecording ? "停止录音" : "开始录音")
                            }
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(recorder.isRecording ? .red : SceneZeroTheme.accent)
                        .frame(minHeight: 44)
                        .accessibilityInputLabels(["开始", "停止", "录音"])

                        if recorder.isRecording {
                            RecordingTimelineWaveform(levels: recorder.waveformLevels)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                } footer: {
                    Text("适合记录语音想法或现场环境声音。录音只保存在此设备。")
                }

                if recorder.temporaryURL != nil {
                    Section("这段声音") {
                        if !recorder.isRecording,
                           let url = recorder.temporaryURL {
                            CompactAudioPlayer(
                                url: url,
                                title: title.isEmpty ? "未命名录音" : title,
                                subtitle: "录制完成后可预听，确认后再保存",
                                duration: recorder.duration
                            )

                            Button("重录", systemImage: "arrow.counterclockwise") {
                                title = ""
                                note = ""
                                recorder.discard()
                            }
                            .foregroundStyle(.red)
                        }

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
            .alert(errorTitle, isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) { } message: {
                Text(errorMessage ?? "")
            }
        }
        .onDisappear {
            recorder.discard()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, recorder.isRecording {
                recorder.stop()
            }
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
                    errorTitle = "无法开始录音"
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
            errorTitle = "无法保存声音"
            errorMessage = error.localizedDescription
        }
    }
}
