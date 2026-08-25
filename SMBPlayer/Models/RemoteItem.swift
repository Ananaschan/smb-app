import Foundation

enum RemoteFileSort: String, CaseIterable, Identifiable {
    case name
    case date

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:
            return "按名称"
        case .date:
            return "按日期"
        }
    }

    static func compares(
        _ lhs: RemoteItem,
        _ rhs: RemoteItem,
        sort: RemoteFileSort,
        ascending: Bool,
        directoriesFirst: Bool = true
    ) -> Bool {
        if directoriesFirst, lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        switch sort {
        case .name:
            let result = lhs.name.localizedStandardCompare(rhs.name)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        case .date:
            let lhsDate = lhs.modifiedAt ?? .distantPast
            let rhsDate = rhs.modifiedAt ?? .distantPast
            return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
        }
    }
}

struct RemoteItem: Identifiable, Hashable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modifiedAt: Date?

    var id: String { path }

    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }

    var isImage: Bool {
        Self.imageExtensions.contains(fileExtension)
    }

    var isVideo: Bool {
        Self.videoExtensions.contains(fileExtension)
    }

    var isSubtitle: Bool {
        Self.subtitleExtensions.contains(fileExtension)
    }

    var systemImage: String {
        if isDirectory {
            return "folder.fill"
        }
        if isImage {
            return "photo.fill"
        }
        if isVideo {
            return "film.fill"
        }
        if isSubtitle {
            return "captions.bubble.fill"
        }
        return "doc.fill"
    }

    static func path(byJoining base: String, _ name: String) -> String {
        if base.isEmpty {
            return name
        }
        return base.hasSuffix("/") ? base + name : base + "/" + name
    }

    static func parentPath(of path: String) -> String {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count > 1 else {
            return ""
        }
        return parts.dropLast().joined(separator: "/")
    }

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "bmp", "raw", "dng"
    ]

    private static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "mkv", "avi", "wmv", "flv", "webm", "ts", "mts", "m2ts", "rm", "rmvb", "3gp"
    ]

    private static let subtitleExtensions: Set<String> = [
        "srt", "ass", "ssa", "vtt", "sub", "idx"
    ]
}

extension RemoteItem {
    init?(remoteRow row: [URLResourceKey: Any], basePath: String) {
        guard let name = row[.nameKey] as? String, name != ".", name != ".." else {
            return nil
        }
        let type = row[.fileResourceTypeKey] as? URLFileResourceType
        let path = (row[.pathKey] as? String) ?? RemoteItem.path(byJoining: basePath, name)
        let size = (row[.fileSizeKey] as? Int64) ?? 0
        let date = row[.contentModificationDateKey] as? Date
        self.init(
            name: name,
            path: path,
            isDirectory: type == .directory,
            size: size,
            modifiedAt: date
        )
    }
}
