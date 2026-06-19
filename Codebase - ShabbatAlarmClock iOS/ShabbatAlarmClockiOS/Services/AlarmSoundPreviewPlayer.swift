import AVFoundation
import Foundation

@MainActor
final class AlarmSoundPreviewPlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = AlarmSoundPreviewPlayer()

    private var currentPlayer: AVAudioPlayer?
    private var pendingSegmentURLs: [URL] = []
    private var currentPlaybackToken = UUID()
    private var completionHandler: (() -> Void)?

    private override init() { }

    func play(
        _ sound: AlarmSound,
        durationSeconds: Int,
        noiseLevel: AlarmNoiseLevel = .defaultLevel,
        onCompletion: @escaping () -> Void
    ) {
        stop()

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
            self?.playNextSegmentOrFinish()
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

    private func playSegment(at url: URL, playbackToken: UUID) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            currentPlayer = player

            guard currentPlaybackToken == playbackToken, player.play() else {
                finishPlayback(notifyCompletion: true)
                return
            }
        } catch {
            finishPlayback(notifyCompletion: true)
        }
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
        pendingSegmentURLs.removeAll()

        currentPlayer?.stop()
        currentPlayer?.delegate = nil
        currentPlayer = nil

        callback?()
    }
}
