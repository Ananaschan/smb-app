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
        guard let manager = makeManager() else {
            throw SMBServiceError.invalidURL
        }
        manager.timeout = 30
        let shares = try await manager.listShares()
        return shares
            .filter { !$0.name.hasSuffix("$") }
            .map { SMBShare(name: $0.name, comment: $0.comment) }
    }

    func connectIfNeeded() async throws {
        if manager == nil {
            manager = makeManager()
        }
        guard let manager else {
            throw SMBServiceError.invalidURL
        }
        do {
            try await manager.connectShare(name: share)
        } catch {
            try? await manager.disconnectShare()
            throw error
        }
    }

    func listDirectory(at path: String) async throws -> [RemoteItem] {
        try await connectIfNeeded()
        guard let manager else {
            throw SMBServiceError.notConnected
        }
        let rows = try await manager.contentsOfDirectory(atPath: path)
        return rows.compactMap { RemoteItem(remoteRow: $0, basePath: path) }
    }

    func read(_ path: String) async throws -> Data {
        try await connectIfNeeded()
        guard let manager else {
            throw SMBServiceError.notConnected
        }
        return try await manager.contents(atPath: path, range: Range<UInt64>?.none)
    }

    func download(_ path: String, to url: URL) async throws {
        try await connectIfNeeded()
        guard let manager else {
            throw SMBServiceError.notConnected
        }
        try await manager.downloadItem(atPath: path, to: url, progress: nil)
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
