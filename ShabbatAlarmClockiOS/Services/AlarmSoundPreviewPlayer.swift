import AudioToolbox
import Foundation

@MainActor
final class AlarmSoundPreviewPlayer {
    static let shared = AlarmSoundPreviewPlayer()

    private var currentSoundID: SystemSoundID?
    private var currentPlaybackToken = UUID()
    private var completionHandler: (() -> Void)?

    private init() { }

    deinit {
        if let soundID = currentSoundID {
            AudioServicesDisposeSystemSoundID(soundID)
        }
    }

    func play(_ sound: AlarmSound, onCompletion: @escaping () -> Void) {
        stop()

        guard let url = sound.bundledFileURL() else {
            onCompletion()
            return
        }

        var soundID: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        guard status == kAudioServicesNoError else {
            onCompletion()
            return
        }

        var completePlaybackIfAppDies: UInt32 = 0
        var mutableSoundID = soundID
        AudioServicesSetProperty(
            kAudioServicesPropertyCompletePlaybackIfAppDies,
            UInt32(MemoryLayout<SystemSoundID>.size),
            &mutableSoundID,
            UInt32(MemoryLayout<UInt32>.size),
            &completePlaybackIfAppDies
        )

        currentSoundID = soundID
        completionHandler = onCompletion
        let playbackToken = UUID()
        currentPlaybackToken = playbackToken

        AudioServicesPlayAlertSoundWithCompletion(soundID) { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.currentPlaybackToken == playbackToken else { return }
                self.finishPlayback(notifyCompletion: true)
            }
        }
    }

    func stop() {
        finishPlayback(notifyCompletion: false)
    }

    private func finishPlayback(notifyCompletion: Bool) {
        let callback = notifyCompletion ? completionHandler : nil
        completionHandler = nil
        currentPlaybackToken = UUID()

        if let soundID = currentSoundID {
            AudioServicesDisposeSystemSoundID(soundID)
            currentSoundID = nil
        }

        callback?()
    }
}
