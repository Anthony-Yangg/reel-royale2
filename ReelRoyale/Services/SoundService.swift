import AVFoundation
import AudioToolbox

/// SFX library. Bundled app audio is preferred; system sounds keep feedback live when assets are absent.
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
    private let fallbackSystemSounds: [SoundEffect: SystemSoundID] = [
        .tap: 1104,
        .confirm: 1111,
        .coinShower: 1109,
        .cannonBoom: 1005,
        .crownShatter: 1054,
        .seaShantyHorn: 1023,
        .brassChime: 1013,
        .bellRing: 1016,
        .lowThud: 1156,
        .ropeCreak: 1107
    ]

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
            if let fallback = fallbackSystemSounds[effect] {
                AudioServicesPlaySystemSound(fallback)
            }
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[effect] = player
            player.play()
        } catch {
            if let fallback = fallbackSystemSounds[effect] {
                AudioServicesPlaySystemSound(fallback)
            }
        }
    }

    func stopAll() {
        players.values.forEach { $0.stop() }
    }
}
