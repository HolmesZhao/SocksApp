import AVFoundation
import Foundation

final class BackgroundAudioKeeper {
    private var player: AVAudioPlayer?

    func start(log: @escaping (String) -> Void) {
        guard let url = Bundle.main.url(forResource: "blank", withExtension: "wav") else {
            log("[SOCKS] Error: Could not find blank.wav resource")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            log("[SOCKS] Successfully created audio player")

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)

            player?.volume = 0.01
            player?.numberOfLoops = -1
            player?.prepareToPlay()
            let started = player?.play() == true
            log("[SOCKS] Background audio \(started ? "did" : "failed to") start")
        } catch {
            log("[SOCKS] Error creating audio player: \(error.localizedDescription)")
        }
    }

    func stop() {
        player?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
