import AVFoundation
import Observation

@MainActor
@Observable
final class AudioRecordingController {
    enum RecordingError: LocalizedError {
        case permissionDenied
        case inputUnavailable
        case audioSessionFailed(String)
        case recorderSetupFailed(String)
        case couldNotStart

        var errorDescription: String? {
            switch self {
            case .permissionDenied: "没有麦克风权限。请在系统设置中允许 SceneZero 使用麦克风。"
            case .inputUnavailable: "当前设备没有可用麦克风。请在真机上录音，或在模拟器中连接可用的音频输入设备。"
            case .audioSessionFailed(let description): "无法配置录音会话：\(description)"
            case .recorderSetupFailed(let description): "无法创建录音文件：\(description)"
            case .couldNotStart: "无法开始录音，请稍后再试。"
            }
        }
    }

    private(set) var isRecording = false
    private(set) var duration: Double = 0
    private(set) var waveformLevels: [Double] = []
    private(set) var temporaryURL: URL?

    private var recorder: AVAudioRecorder?
    private var meterTask: Task<Void, Never>?
    private var recordingStartedAt: Date?
    private var smoothedInputLevel: Double = 0

    func start() async throws {
        guard await microphonePermissionGranted() else {
            throw RecordingError.permissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        guard session.isInputAvailable else {
            throw RecordingError.inputUnavailable
        }

        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            throw RecordingError.audioSessionFailed(error.localizedDescription)
        }

        let url = URL.temporaryDirectory
            .appending(path: "SceneZero-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder: AVAudioRecorder
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
        } catch {
            try? session.setActive(false)
            throw RecordingError.recorderSetupFailed(error.localizedDescription)
        }

        recorder.isMeteringEnabled = true
        guard recorder.prepareToRecord(), recorder.record() else {
            try? session.setActive(false)
            throw RecordingError.couldNotStart
        }

        self.recorder = recorder
        temporaryURL = url
        duration = 0
        waveformLevels = []
        smoothedInputLevel = 0
        recordingStartedAt = .now
        isRecording = true
        startDurationUpdates()
    }

    func stop() {
        // AVAudioRecorder can report 0 again immediately after `stop()`. Capture
        // the elapsed time first, so the preview and the saved asset stay in sync.
        let recorderDuration = recorder?.currentTime ?? 0
        let elapsedDuration = recordingStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0
        let finalDuration = max(max(duration, recorderDuration), elapsedDuration)

        meterTask?.cancel()
        meterTask = nil
        recorder?.stop()
        recorder = nil
        recordingStartedAt = nil
        duration = finalDuration
        waveformLevels = []
        smoothedInputLevel = 0
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func discard() {
        stop()
        if let temporaryURL {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
        temporaryURL = nil
        duration = 0
        waveformLevels = []
        smoothedInputLevel = 0
        recordingStartedAt = nil
    }

    private func startDurationUpdates() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let recorderDuration = recorder?.currentTime ?? 0
                let elapsedDuration = recordingStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0
                duration = max(recorderDuration, elapsedDuration)
                recorder?.updateMeters()
                let averagePower = recorder?.averagePower(forChannel: 0) ?? -55
                smoothedInputLevel = (smoothedInputLevel * 0.65)
                    + (normalizedInputLevel(for: averagePower) * 0.35)
                appendWaveformLevel(smoothedInputLevel)
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func appendWaveformLevel(_ level: Double) {
        waveformLevels.append(level)
        if waveformLevels.count > 46 {
            waveformLevels.removeFirst()
        }
    }

    private func normalizedInputLevel(for averagePower: Float) -> Double {
        let minimumPower: Float = -55
        let clampedPower = min(0, max(minimumPower, averagePower))
        return Double((clampedPower - minimumPower) / -minimumPower)
    }

    private func microphonePermissionGranted() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
