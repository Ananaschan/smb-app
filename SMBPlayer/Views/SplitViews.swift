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

