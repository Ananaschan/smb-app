import SwiftUI

struct ShareListView: View {
    let server: SMBServer

    @State private var shares: [SMBShare] = []
    @State private var isLoading = true
    @State private var alertMessage = ""
    @State private var showError = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("正在读取共享…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(shares) { share in
                    NavigationLink(value: share) {
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
                    }
                }
            }
        }
        .navigationTitle(server.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SMBShare.self) { share in
            BrowseView(server: server, share: share.name)
        }
        .alert("连接失败", isPresented: $showError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .task {
            await load()
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let service = SMBFileService(
            server: server,
            share: "",
            password: KeychainStore.password(for: server) ?? ""
        )
        do {
            shares = try await service.listShares()
        } catch {
            AppLogger.shared.log("ShareListView load failed: \(error.localizedDescription)")
            alertMessage = error.localizedDescription
            showError = true
        }
    }
}
