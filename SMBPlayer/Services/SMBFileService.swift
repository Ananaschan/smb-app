import Foundation
import AMSMB2

struct SMBShare: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let comment: String
}

enum SMBServiceError: LocalizedError {
    case invalidURL
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "服务器地址无效"
        case .notConnected:
            return "尚未连接到共享"
        }
    }
}

@MainActor
final class SMBFileService: ObservableObject {
    @Published var entries: [RemoteItem] = []
    @Published var errorMessage: String?

    private let server: SMBServer
    private let share: String
    private let password: String
    private var manager: SMB2Manager?

    init(server: SMBServer, share: String, password: String) {
        self.server = server
        self.share = share
        self.password = password
    }

    func listShares() async throws -> [SMBShare] {
        AppLogger.shared.log("listShares \(server.displayName) @ \(server.host)")
        guard let manager = makeManager() else {
            AppLogger.shared.log("listShares failed: invalidURL")
            throw SMBServiceError.invalidURL
        }
        manager.timeout = 30
        do {
            let shares = try await manager.listShares()
            let result = shares
                .filter { !$0.name.hasSuffix("$") }
                .map { SMBShare(name: $0.name, comment: $0.comment) }
            AppLogger.shared.log("listShares found \(result.count) shares")
            return result
        } catch {
            AppLogger.shared.log("listShares failed: \(error.localizedDescription)")
            throw error
        }
    }

    func connectIfNeeded() async throws {
        AppLogger.shared.log("connect share \(share) @ \(server.host)")
        if manager == nil {
            manager = makeManager()
        }
        guard let manager else {
            AppLogger.shared.log("connect failed: invalidURL")
            throw SMBServiceError.invalidURL
        }
        do {
            try await manager.connectShare(name: share)
            AppLogger.shared.log("connect share succeeded")
        } catch {
            try? await manager.disconnectShare()
            self.manager = nil
            AppLogger.shared.log("connect failed: \(error.localizedDescription)")
            throw error
        }
    }

    func listDirectory(at path: String) async throws -> [RemoteItem] {
        AppLogger.shared.log("listDirectory path=\(path) share=\(share)")
        try await connectIfNeeded()
        guard let manager else {
            AppLogger.shared.log("listDirectory failed: notConnected")
            throw SMBServiceError.notConnected
        }
        do {
            let rows = try await manager.contentsOfDirectory(atPath: path)
            let items = rows.compactMap { RemoteItem(remoteRow: $0, basePath: path) }
            AppLogger.shared.log("listDirectory found \(items.count) items")
            return items
        } catch {
            AppLogger.shared.log("listDirectory failed: \(error.localizedDescription)")
            throw error
        }
    }

    func read(_ path: String) async throws -> Data {
        try await connectIfNeeded()
        guard let manager else {
            throw SMBServiceError.notConnected
        }
        return try await manager.contents(atPath: path, range: Range<UInt64>?.none)
    }

    func download(_ path: String, to url: URL) async throws {
        AppLogger.shared.log("download \(path)")
        try await connectIfNeeded()
        guard let manager else {
            AppLogger.shared.log("download failed: notConnected")
            throw SMBServiceError.notConnected
        }
        do {
            try await manager.downloadItem(atPath: path, to: url, progress: nil)
            AppLogger.shared.log("download completed \(path)")
        } catch {
            AppLogger.shared.log("download failed: \(error.localizedDescription)")
            throw error
        }
    }

    func createFolder(named name: String, in path: String) async throws {
        try await connectIfNeeded()
        guard let manager else {
            throw SMBServiceError.notConnected
        }
        try await manager.createDirectory(atPath: RemoteItem.path(byJoining: path, name))
    }

    func createEmptyFile(named name: String, in path: String) async throws {
        try await connectIfNeeded()
        guard let manager else {
            throw SMBServiceError.notConnected
        }
        try await manager.write(
            data: Data(),
            toPath: RemoteItem.path(byJoining: path, name),
            progress: nil
        )
    }

    func rename(_ item: RemoteItem, newName: String, in path: String) async throws {
        try await connectIfNeeded()
        guard let manager else {
            throw SMBServiceError.notConnected
        }
        let destination = RemoteItem.path(byJoining: path, newName)
        try await manager.moveItem(atPath: item.path, toPath: destination)
    }

    func delete(_ item: RemoteItem) async throws {
        try await connectIfNeeded()
        guard let manager else {
            throw SMBServiceError.notConnected
        }
        if item.isDirectory {
            try await manager.removeDirectory(atPath: item.path, recursive: true)
        } else {
            try await manager.removeFile(atPath: item.path)
        }
    }

    private func makeManager() -> SMB2Manager? {
        SMB2Manager(
            url: server.baseURL,
            domain: server.domain,
            credential: URLCredential(
                user: server.resolvedUsername,
                password: password,
                persistence: .forSession
            )
        )
    }
}
