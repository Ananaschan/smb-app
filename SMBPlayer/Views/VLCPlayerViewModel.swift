import AVFoundation
import Combine
import Foundation
import MobileVLCKit

final class VLCPlayerViewModel: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var position: Double = 0
    @Published var bufferingText = ""

    let player = VLCMediaPlayer()

    override init() {
        super.init()
        player.delegate = self
    }

    var currentTimeText: String {
        Self.format(seconds: Int(player.time.intValue / 1000))
    }

    var durationText: String {
        let millis = player.media?.length.intValue ?? 0
        return Self.format(seconds: Int(millis / 1000))
    }

    var durationSeconds: Double {
        Double(player.media?.length.intValue ?? 0) / 1000.0
    }

    func play(
        item: RemoteItem,
        server: SMBServer,
        share: String,
        password: String,
        subtitleURL: URL? = nil
    ) {
        configureAudioSession()
        guard let url = Self.smbURL(
            path: item.path,
            server: server,
            share: share,
            password: password
        ) else {
            return
        }
        let media = VLCMedia(url: url)
        media.addOption(":network-caching=2000")
        media.addOption(":file-caching=3000")
        player.media = media
        if let subtitleURL {
            player.addPlaybackSlave(subtitleURL, type: .subtitle, enforce: true)
        }
        player.play()
        updateState()
    }

    func togglePlayPause() {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
        updateState()
    }

    func seek(to fraction: Double) {
        player.position = Float(fraction)
    }

    func selectSubtitle(url: URL) {
        player.addPlaybackSlave(url, type: .subtitle, enforce: true)
    }

    func stop() {
        player.stop()
        player.media = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    static func smbURL(
        path: String,
        server: SMBServer,
        share: String,
        password: String
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "smb"
        components.host = server.host
        if server.port != 445 {
            components.port = server.port
        }
        var user = server.resolvedUsername
        if !server.domain.isEmpty {
            user = "\(server.domain)\\\(user)"
        }
        components.user = user
        if !password.isEmpty {
            components.password = password
        }
        let relative = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/\(share)/\(relative)"
        return components.url
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func updateState() {
        isPlaying = player.isPlaying
        position = Double(player.position)
    }

    static func format(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%ld:%02ld:%02ld", hours, minutes, secs)
        }
        return String(format: "%02ld:%02ld", minutes, secs)
    }
}

extension VLCPlayerViewModel: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        if player.state == .buffering {
            bufferingText = "缓冲中…"
        } else {
            bufferingText = ""
        }
        updateState()
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        updateState()
    }
}
