import AVFoundation
import Observation

@MainActor
@Observable
final class AudioPlaybackController {
    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double

    @ObservationIgnored private let player: AVPlayer
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?

    init(url: URL, fallbackDuration: Double) {
        player = AVPlayer(url: url)
        duration = max(0, fallbackDuration)
        installObservers()

        Task { @MainActor [weak self] in
            await self?.loadAssetDuration()
        }
    }

    func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            play()
        }
    }

    func stop() {
        player.pause()
        player.seek(to: .zero)
        currentTime = 0
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func dispose() {
        stop()
        removeObservers()
    }

    private func play() {
        guard activatePlaybackSession() else { return }

        if duration > 0, currentTime >= duration - 0.05 {
            player.seek(to: .zero)
            currentTime = 0
        }
        player.play()
    }

    private func activatePlaybackSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }

    private func installObservers() {
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor [weak self] in
                self?.updateCurrentTime(seconds)
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finishPlayback()
            }
        }

        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let isPlaying = player.timeControlStatus == .playing
            Task { @MainActor [weak self] in
                self?.isPlaying = isPlaying
            }
        }
    }

    private func removeObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
    }

    private func loadAssetDuration() async {
        guard let asset = player.currentItem?.asset,
              let loadedDuration = try? await asset.load(.duration) else {
            return
        }
        let seconds = loadedDuration.seconds
        guard seconds.isFinite, seconds > 0 else { return }
        duration = seconds
    }

    private func updateCurrentTime(_ seconds: Double) {
        guard seconds.isFinite, seconds >= 0 else { return }
        currentTime = duration > 0 ? min(seconds, duration) : seconds
    }

    private func finishPlayback() {
        let finalTime = player.currentTime().seconds
        if finalTime.isFinite, finalTime > 0 {
            duration = finalTime
            currentTime = finalTime
        }
        isPlaying = false
    }
}
