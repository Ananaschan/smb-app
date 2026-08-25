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
            Group {
                if isLoading {
                    ProgressView("正在读取共享…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if loadFailed {
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
                } else if shares.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "externaldrive.badge.questionmark")
                            .font(.system(size: 40))
                        Text("没有可用的共享")
                            .font(.headline)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(shares) { share in
                                Button {
                                    path.wrappedValue.append(.share(server, share))
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
            .navigationDestination(for: BrowseRoute.self) { route in
                switch route {
                case .share(let routeServer, let share):
                    BrowseView(
                        server: routeServer,
                        share: share.name,
                        path: "",
                        onOpenFolder: { folder in
                            path.wrappedValue.append(.folder(routeServer, share, folder))
                        }
                    )
                case .folder(let routeServer, let share, let folder):
                    BrowseView(
                        server: routeServer,
                        share: share.name,
                        path: folder,
                        onOpenFolder: { sub in
                            path.wrappedValue.append(.folder(routeServer, share, sub))
                        }
                    )
                }
            }
        }
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
