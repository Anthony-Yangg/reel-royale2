import AVFoundation

/// SFX library. Wave 1 ships the API; real audio assets are wired in Wave 4/6.
enum SoundEffect: String, CaseIterable {
    case tap             = "tap"
    case confirm         = "confirm"
    case coinShower      = "coin_shower"
    case cannonBoom      = "cannon_boom"
    case crownShatter    = "crown_shatter"
    case seaShantyHorn   = "sea_shanty_horn"
    case brassChime      = "brass_chime"
    case bellRing        = "bell_ring"
    case lowThud         = "low_thud"
    case ropeCreak       = "rope_creak"
}

protocol SoundServiceProtocol: AnyObject {
    var isEnabled: Bool { get set }
    func play(_ effect: SoundEffect)
    func stopAll()
}

final class SoundService: SoundServiceProtocol {
    var isEnabled: Bool = true

    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        configureSession()
    }

    private func configureSession() {
        // Ambient = mixes with other audio (user might be on a fishing podcast)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func play(_ effect: SoundEffect) {
        guard isEnabled else { return }
        if let player = players[effect] {
            player.currentTime = 0
            player.play()
            return
        }
        guard let url = bundle.url(forResource: effect.rawValue, withExtension: "m4a")
                ?? bundle.url(forResource: effect.rawValue, withExtension: "wav") else {
            // Asset not bundled yet (Wave 1 stub). Silently no-op.
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[effect] = player
            player.play()
        } catch {
            // No assets yet; ignore.
        }
    }

    func stopAll() {
        players.values.forEach { $0.stop() }
    }
}
