import Photos
import UIKit

enum ImageSaverError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "需要相册添加权限才能保存图片"
    }
}

enum ImageSaver {
    @MainActor
    static func saveOriginal(_ item: RemoteItem, service: SMBFileService) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ImageSaverError.permissionDenied
        }

        let fileExtension = item.fileExtension.isEmpty ? "data" : item.fileExtension
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        do {
            try await service.download(item.path, to: tempURL)
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                request.addResource(with: .photo, fileURL: tempURL, options: options)
            }
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
        try? FileManager.default.removeItem(at: tempURL)
    }
}
