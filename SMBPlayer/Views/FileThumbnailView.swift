import SwiftUI
import UIKit

struct FileThumbnailView: View {
    let item: RemoteItem
    let server: SMBServer
    let share: String
    let service: SMBFileService

    var body: some View {
        Group {
            if item.isImage {
                SMBRemoteThumbnail(item: item, server: server, service: service)
            } else if item.isDirectory {
                iconTile(systemImage: "folder.fill")
            } else if item.isVideo {
                SMBVideoThumbnail(item: item, server: server, share: share)
            } else {
                iconTile(systemImage: item.isSubtitle ? "captions.bubble.fill" : "doc.fill")
            }
        }
    }

    private func iconTile(systemImage: String) -> some View {
        ZStack {
            Rectangle()
                .fill(Color(.secondarySystemBackground))
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
        }
    }
}

struct SMBRemoteThumbnail: View {
    let item: RemoteItem
    let server: SMBServer
    let service: SMBFileService

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.secondarySystemBackground))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed {
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .clipped()
        .task {
            guard image == nil, !failed else {
                return
            }
            let result = try? await ImageLoader.shared.thumbnail(
                for: item,
                server: server,
                service: service
            )
            if let result {
                image = result
            } else {
                failed = true
            }
        }
    }
}

/// 视频缩略图：首帧从视频截取（VLC 播放一小段），失败回退为胶片图标
struct SMBVideoThumbnail: View {
    let item: RemoteItem
    let server: SMBServer
    let share: String

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.secondarySystemBackground))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed {
                Image(systemName: "film.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .clipped()
        .task {
            guard image == nil, !failed else {
                return
            }
            let result = await VideoThumbnailService.shared.thumbnail(
                for: item,
                server: server,
                share: share
            )
            if let result {
                image = result
            } else {
                failed = true
            }
        }
    }
}
