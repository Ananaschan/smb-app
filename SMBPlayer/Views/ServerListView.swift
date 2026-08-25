import SwiftUI

struct ServerListView: View {
    @EnvironmentObject private var store: SMBServerStore
    @State private var showAdd = false
    @State private var discoveredDraft: SMBServer?
    @StateObject private var discovery = SMBDiscovery()

    var body: some View {
        List {
            ForEach(store.servers) { server in
                NavigationLink(value: server) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.displayName)
                            if !server.host.isEmpty {
                                Text(server.host)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "externaldrive.fill")
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    KeychainStore.setPassword(nil, for: store.servers[index])
                }
                store.delete(at: offsets)
            }

            if !discovery.results.isEmpty {
                Section("局域网发现") {
                    ForEach(discovery.results) { item in
                        Button {
                            discoveredDraft = SMBServer(
                                displayName: item.name,
                                host: item.host,
                                port: item.port,
                                useGuest: true
                            )
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                    Text(item.host)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "wifi")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("SMB 文件")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: SMBServer.self) { server in
            ShareListView(server: server)
        }
        .sheet(isPresented: $showAdd) {
            ServerFormView()
        }
        .sheet(item: $discoveredDraft) { server in
            ServerFormView(initialServer: server)
        }
        .onAppear {
            discovery.start()
        }
        .onDisappear {
            discovery.stop()
        }
        .overlay {
            if store.servers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "externaldrive.badge.plus")
                        .font(.system(size: 40))
                    Text("还没有服务器")
                        .font(.headline)
                    Text("点右上角 + 添加 Windows 共享")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
        }
    }
}
