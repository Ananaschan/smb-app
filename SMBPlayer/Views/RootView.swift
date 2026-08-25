import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var selectedServer: SMBServer?

    var body: some View {
        if sizeClass == .compact {
            NavigationStack {
                ServerListView()
            }
        } else {
            NavigationSplitView {
                SplitServerList(selection: $selectedServer)
            } detail: {
                if let server = selectedServer {
                    ShareGridView(server: server)
                        .id(server.id)
                } else {
                    EmptySelectionView()
                }
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
