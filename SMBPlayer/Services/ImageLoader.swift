import CryptoKit
import Foundation
import ImageIO
import UIKit

actor ImageLoader {
    static let shared = ImageLoader()

    /// 磁盘缓存上限：4 GB
    static let maxCacheBytes: Int64 = 4 * 1024 * 1024 * 1024
    /// 缓存超限后清理到上限的 70%，避免频繁触发清理
    private static let evictTargetBytes: Int64 = Int64(Double(maxCacheBytes) * 0.7)

    private static let maxCachedFileSize: Int64 = 500 * 1024 * 1024

    private let memory = NSCache<NSString, UIImage>()
    private static let memoryLimitBytes: Int = 128 * 1024 * 1024

    struct CacheStats: Sendable {
        var fileCount: Int
        var bytes: Int64
    }

    private var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("images", isDirectory: true)
    }

    init() {
        memory.totalCostLimit = Self.memoryLimitBytes
    }

    func thumbnail(
        for item: RemoteItem,
        server: SMBServer,
        service: SMBFileService
    ) async throws -> UIImage? {
        try await image(for: item, server: server, service: service, maxPixelSize: 512)
    }

    func fullImage(
        for item: RemoteItem,
        server: SMBServer,
        service: SMBFileService
    ) async throws -> UIImage? {
        try await image(for: item, server: server, service: service, maxPixelSize: 4096)
    }

    /// 当前磁盘缓存占用（文件数与字节数）
    func cacheStats() -> CacheStats {
        let files = cachedFiles()
        let bytes = files.reduce(Int64(0)) { $0 + ($1.size ?? 0) }
        return CacheStats(fileCount: files.count, bytes: bytes)
    }

    /// 手动清除全部磁盘缓存
    func clearCache() {
        for file in cachedFiles() {
            try? FileManager.default.removeItem(at: file.url)
        }
    }

    private func image(
        for item: RemoteItem,
        server: SMBServer,
        service: SMBFileService,
        maxPixelSize: Int
    ) async throws -> UIImage? {
        guard let fileURL = try await localFile(for: item, server: server, service: service) else {
            return nil
        }
        let memoryKey = "\(fileURL.lastPathComponent)-\(maxPixelSize)" as NSString
        if let cached = memory.object(forKey: memoryKey) {
            return cached
        }
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        let cost = Int(image.size.width * image.size.height * 4)
        memory.setObject(image, forKey: memoryKey, cost: cost)
        return image
    }

    private func localFile(
        for item: RemoteItem,
        server: SMBServer,
        service: SMBFileService
    ) async throws -> URL? {
        guard item.size <= Self.maxCachedFileSize else {
            return nil
        }
        let directory = cachesDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(key(for: item, server: server))
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try await service.download(item.path, to: fileURL)
            enforceCacheLimit()
        }
        return fileURL
    }

    /// 缓存超过 4 GB 时，按修改时间从旧到新删除，直到占用降到 70% 以下。
    private func enforceCacheLimit() {
        let files = cachedFiles()
        var total = files.reduce(Int64(0)) { $0 + ($1.size ?? 0) }
        guard total > Self.maxCacheBytes else { return }
        for file in files {
            guard total > Self.evictTargetBytes else { break }
            try? FileManager.default.removeItem(at: file.url)
            total -= file.size ?? 0
        }
    }

    private struct CacheFile {
        let url: URL
        let size: Int64?
        let modified: Date?
    }

    private func cachedFiles() -> [CacheFile] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: cachesDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            return CacheFile(
                url: url,
                size: values?.fileSize.map(Int64.init),
                modified: values?.contentModificationDate
            )
        }
        .sorted { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) }
    }

    private func key(for item: RemoteItem, server: SMBServer) -> String {
        let raw = "\(server.host)|\(item.path)|\(item.size)|\(item.modifiedAt?.timeIntervalSince1970 ?? 0)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
