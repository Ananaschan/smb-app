import CryptoKit
import Foundation
import ImageIO
import UIKit

actor ImageLoader {
    static let shared = ImageLoader()

    private let memory = NSCache<NSString, UIImage>()
    private static let maxCachedFileSize: Int64 = 500 * 1024 * 1024

    private var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("images", isDirectory: true)
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
        memory.setObject(image, forKey: memoryKey)
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
        }
        return fileURL
    }

    private func key(for item: RemoteItem, server: SMBServer) -> String {
        let raw = "\(server.host)|\(item.path)|\(item.size)|\(item.modifiedAt?.timeIntervalSince1970 ?? 0)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
