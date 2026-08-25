import SwiftUI

/// 主视图：以缩略图文件夹网格显示服务器的共享，点击进入文件浏览
struct ShareGridView: View {
    let server: SMBServer

    @State private var shares: [SMBShare] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var path: [BrowseRoute] = []

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 16)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            gridContent
                .navigationDestination(for: BrowseRoute.self) { route in
                    browseDestination(for: route)
                }
        }
    }

    @ViewBuilder
    private var gridContent: some View {
        Group {
            if isLoading {
                ProgressView("正在读取共享…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if loadFailed {
                errorView
            } else if shares.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(shares) { share in
                            shareTile(share)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(server.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: server.id) {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
            Text("读取共享失败")
                .font(.headline)
            Button("重试") {
                Task { await load() }
            }
        }
        .foregroundStyle(.secondary)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 40))
            Text("没有可用的共享")
                .font(.headline)
        }
        .foregroundStyle(.secondary)
    }

    private func shareTile(_ share: SMBShare) -> some View {
        Button {
            openShare(share)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                    Image(systemName: "folder.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                Text(share.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private func openShare(_ share: SMBShare) {
        var next = path.wrappedValue
        next.append(.share(server, share))
        path.wrappedValue = next
    }

    @ViewBuilder
    private func browseDestination(for route: BrowseRoute) -> some View {
        switch route {
        case .share(let routeServer, let share):
            BrowseView(
                server: routeServer,
                share: share.name,
                path: "",
                onOpenFolder: { folder in
                    openFolder(routeServer, share, folder)
                }
            )
        case .folder(let routeServer, let share, let folder):
            BrowseView(
                server: routeServer,
                share: share.name,
                path: folder,
                onOpenFolder: { sub in
                    openFolder(routeServer, share, sub)
                }
            )
        }
    }

    private func openFolder(_ routeServer: SMBServer, _ share: SMBShare, _ folder: String) {
        var next = path.wrappedValue
        next.append(.folder(routeServer, share, folder))
        path.wrappedValue = next
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        shares = []
        let service = SMBFileService(
            server: server,
            share: "",
            password: KeychainStore.password(for: server) ?? ""
        )
        do {
            shares = try await service.listShares()
            loadFailed = false
        } catch {
            AppLogger.shared.log("ShareGridView load failed @ \(server.host): \(error.localizedDescription)")
            loadFailed = true
        }
    }
}
