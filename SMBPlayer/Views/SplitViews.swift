import SwiftUI

struct SplitServerList: View {
    @EnvironmentObject private var store: SMBServerStore
    @Binding var selection: SMBServer?
    @State private var showAdd = false

    var body: some View {
        List(selection: $selection) {
            ForEach(store.servers) { server in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.displayName)
                        Text(server.host)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "externaldrive.fill")
                }
                .tag(server)
            }
            .onDelete { offsets in
                for index in offsets {
                    KeychainStore.setPassword(nil, for: store.servers[index])
                }
                store.delete(at: offsets)
            }
        }
        .overlay {
            if store.servers.isEmpty {
                Text("还没有服务器")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("SMB 文件")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShareLink(item: AppLogger.shared.logFileURL) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("导出日志")
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            ServerFormView()
        }
    }
}

struct SplitShareList: View {
    let server: SMBServer
    @Binding var selection: SMBShare?

    @State private var shares: [SMBShare] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                List(selection: $selection) {
                    ForEach(shares) { share in
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(share.name)
                                if !share.comment.isEmpty {
                                    Text(share.comment)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "internaldrive.fill")
                        }
                        .tag(share)
                    }
                }
            }
        }
        .navigationTitle("共享")
        .task(id: server.id) {
            await load()
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
        if let loaded = try? await service.listShares() {
            shares = loaded
        } else {
            AppLogger.shared.log("SplitShareList load failed @ \(server.host)")
        }
    }
}
