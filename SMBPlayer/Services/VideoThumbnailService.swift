import CryptoKit
import Foundation
import MobileVLCKit
import UIKit

/// 视频缩略图：用隐藏的 VLC 播放器播放一小段截帧，写入磁盘缓存；
/// 播放器退出时保存当前帧，作为"上次观看的最后一帧"缩略图。
@MainActor
final class VideoThumbnailService {
    static let shared = VideoThumbnailService()

    private let memory = NSCache<NSString, UIImage>()
    /// 串行队列尾：保证同一时间只有一个 VLC 播放器在截帧
    private var lastTask: Task<UIImage?, Never>?

    func thumbnail(for item: RemoteItem, server: SMBServer, share: String) async -> UIImage? {
        let key = Self.cacheKey(for: item, server: server, share: share) as NSString
        if let cached = memory.object(forKey: key) {
            return cached
        }
        if let onDisk = Self.loadFromDisk(item: item, server: server, share: share) {
            memory.setObject(onDisk, forKey: key)
            return onDisk
        }
        let task = Task { [weak self] () -> UIImage? in
            if let last = self?.lastTask {
                _ = await last.value
            }
            guard let self else { return nil }
            let image = await self.generateAndCache(item: item, server: server, share: share)
            if let image {
                self.memory.setObject(image, forKey: key)
            }
            return image
        }
        lastTask = Task { _ = await task.value }
        return await task.value
    }

    /// 播放器退出时保存当前帧，覆盖该视频的缩略图
    static func captureLastFrame(
        player: VLCMediaPlayer,
        item: RemoteItem,
        server: SMBServer,
        share: String
    ) {
        guard let url = cacheFileURL(for: item, server: server, share: share) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        player.saveVideoSnapshot(at: url.path, withWidth: 640, andHeight: 360)
    }

    // MARK: - 生成与缓存

    private func generateAndCache(
        item: RemoteItem,
        server: SMBServer,
        share: String
    ) async -> UIImage? {
        guard let image = await generateThumbnail(item: item, server: server, share: share),
              let url = Self.cacheFileURL(for: item, server: server, share: share) else {
            return nil
        }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let data = image.pngData() {
            try? data.write(to: url, options: .atomic)
        }
        return image
    }

    private func generateThumbnail(
        item: RemoteItem,
        server: SMBServer,
        share: String
    ) async -> UIImage? {
        guard let url = VLCPlayerViewModel.smbURL(
            path: item.path,
            server: server,
            share: share,
            password: KeychainStore.password(for: server) ?? ""
        ) else {
            return nil
        }
        let player = VLCMediaPlayer()
        player.drawable = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        let media = VLCMedia(url: url)
        media.addOption(":network-caching=1000")
        player.media = media
        player.audio?.volume = 0
        player.play()
        defer { player.stop() }

        // 等待网络缓存与首帧
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        player.position = 0.03
        try? await Task.sleep(nanoseconds: 800_000_000)

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("vt-\(UUID().uuidString).png")
        player.saveVideoSnapshot(at: temp.path, withWidth: 320, andHeight: 180)
        // VLC 异步写盘，轮询等待
        for _ in 0..<60 {
            if FileManager.default.fileExists(atPath: temp.path) { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        let image = UIImage(contentsOfFile: temp.path)
        try? FileManager.default.removeItem(at: temp)
        return image
    }

    // MARK: - 缓存定位

    private static func loadFromDisk(item: RemoteItem, server: SMBServer, share: String) -> UIImage? {
        guard let url = cacheFileURL(for: item, server: server, share: share) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private static func cacheFileURL(for item: RemoteItem, server: SMBServer, share: String) -> URL? {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("videos", isDirectory: true)
        return directory.appendingPathComponent("\(cacheKey(for: item, server: server, share: share)).png")
    }

    private static func cacheKey(for item: RemoteItem, server: SMBServer, share: String) -> String {
        let raw = "\(server.host)|\(share)|\(item.path)|\(item.size)|\(item.modifiedAt?.timeIntervalSince1970 ?? 0)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
