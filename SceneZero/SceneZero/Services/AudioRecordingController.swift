import AVFoundation
import Observation

@MainActor
@Observable
final class AudioRecordingController {
    enum RecordingError: LocalizedError {
        case permissionDenied
        case couldNotStart

        var errorDescription: String? {
            switch self {
            case .permissionDenied: "没有麦克风权限。请在系统设置中允许 SceneZero 使用麦克风。"
            case .couldNotStart: "无法开始录音，请稍后再试。"
            }
        }
    }

    private(set) var isRecording = false
    private(set) var duration: Double = 0
    private(set) var temporaryURL: URL?

    private var recorder: AVAudioRecorder?
    private var meterTask: Task<Void, Never>?

    func start() async throws {
        guard await microphonePermissionGranted() else {
            throw RecordingError.permissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)

        let url = URL.temporaryDirectory
            .appending(path: "SceneZero-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        guard recorder.record() else {
            throw RecordingError.couldNotStart
        }

        self.recorder = recorder
        temporaryURL = url
        duration = 0
        isRecording = true
        startDurationUpdates()
    }

    func stop() {
        recorder?.stop()
        duration = recorder?.currentTime ?? duration
        recorder = nil
        meterTask?.cancel()
        meterTask = nil
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
    }

    private func startDurationUpdates() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                duration = recorder?.currentTime ?? duration
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func microphonePermissionGranted() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
