import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var selectedServer: SMBServer?
    @State private var selectedShare: SMBShare?

    var body: some View {
        if sizeClass == .compact {
            NavigationStack {
                ServerListView()
            }
        } else {
            NavigationSplitView {
                SplitServerList(selection: $selectedServer)
            } content: {
                if let server = selectedServer {
                    SplitShareList(server: server, selection: $selectedShare)
                } else {
                    EmptyDetailText(text: "选择服务器")
                }
            } detail: {
                if let server = selectedServer, let share = selectedShare {
                    BrowseView(server: server, share: share.name)
                        .id("\(server.id)|\(share.name)")
                } else {
                    EmptySelectionView()
                }
            }
            .onChange(of: selectedServer) { _ in
                selectedShare = nil
            }
        }
    }
}

struct EmptySelectionView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 44))
            Text("选择一个服务器和共享")
                .font(.headline)
        }
        .foregroundStyle(.secondary)
    }
}

struct EmptyDetailText: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
