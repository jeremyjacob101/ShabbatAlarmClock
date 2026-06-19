import AVFoundation
import Foundation

@MainActor
final class AlarmSoundPreviewPlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = AlarmSoundPreviewPlayer()

    private let audioSession = AVAudioSession.sharedInstance()
    private var currentPlayer: AVAudioPlayer?
    private var pendingSegmentURLs: [URL] = []
    private var currentPlaybackToken = UUID()
    private var currentSegmentRecoveryAttempts = 0
    private var completionHandler: (() -> Void)?

    private override init() { }

    func play(
        _ sound: AlarmSound,
        durationSeconds: Int,
        noiseLevel: AlarmNoiseLevel = .defaultLevel,
        onCompletion: @escaping () -> Void
    ) {
        stop()

        do {
            try configureAudioSession()
        } catch {
            onCompletion()
            return
        }

        let segments = Alarm.notificationSoundSegments(for: durationSeconds)
        let segmentURLs = segments.compactMap { segment in
            sound.bundledFileURL(
                durationSeconds: segment.durationSeconds,
                noiseLevel: noiseLevel
            )
        }

        guard segmentURLs.count == segments.count,
              let firstSegmentURL = segmentURLs.first else {
            onCompletion()
            return
        }

        pendingSegmentURLs = Array(segmentURLs.dropFirst())
        completionHandler = onCompletion
        let playbackToken = UUID()
        currentPlaybackToken = playbackToken
        playSegment(at: firstSegmentURL, playbackToken: playbackToken)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.handlePlayerFinished(player, successfully: flag)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            self?.finishPlayback(notifyCompletion: true)
        }
    }

    func stop() {
        finishPlayback(notifyCompletion: false)
    }

    private func configureAudioSession() throws {
        try audioSession.setCategory(.soloAmbient, mode: .default)
        try audioSession.setActive(true)
    }

    private func playSegment(at url: URL, playbackToken: UUID) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            currentPlayer = player
            currentSegmentRecoveryAttempts = 0

            guard currentPlaybackToken == playbackToken, player.play() else {
                finishPlayback(notifyCompletion: true)
                return
            }
        } catch {
            finishPlayback(notifyCompletion: true)
        }
    }

    private func handlePlayerFinished(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === currentPlayer else { return }

        if !flag,
           currentSegmentRecoveryAttempts < 1,
           player.currentTime + 0.5 < player.duration {
            currentSegmentRecoveryAttempts += 1
            player.prepareToPlay()
            if player.play() {
                return
            }
        }

        playNextSegmentOrFinish()
    }

    private func playNextSegmentOrFinish() {
        currentPlayer?.delegate = nil
        currentPlayer = nil

        guard !pendingSegmentURLs.isEmpty else {
            finishPlayback(notifyCompletion: true)
            return
        }

        let nextSegmentURL = pendingSegmentURLs.removeFirst()
        playSegment(at: nextSegmentURL, playbackToken: currentPlaybackToken)
    }

    private func finishPlayback(notifyCompletion: Bool) {
        let callback = notifyCompletion ? completionHandler : nil
        completionHandler = nil
        currentPlaybackToken = UUID()
        currentSegmentRecoveryAttempts = 0
        pendingSegmentURLs.removeAll()

        currentPlayer?.stop()
        currentPlayer?.delegate = nil
        currentPlayer = nil

        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        callback?()
    }
}
