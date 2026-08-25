import SwiftUI

/// 目录浏览的导航路由：共享根 + 子文件夹层级（程序化入栈，避开 value-link 查找）
enum BrowseRoute: Hashable {
    case share(SMBServer, SMBShare)
    case folder(SMBServer, SMBShare, String)
}

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var selectedServer: SMBServer?
    @State private var compactPath: [BrowseRoute] = []

    var body: some View {
        if sizeClass == .compact {
            NavigationStack(path: $compactPath) {
                ServerListView(path: $compactPath)
                    .navigationDestination(for: BrowseRoute.self) { route in
                        browseView(for: route, path: $compactPath)
                    }
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

    @ViewBuilder
    private func browseView(for route: BrowseRoute, path: Binding<[BrowseRoute]>) -> some View {
        switch route {
        case .share(let server, let share):
            BrowseView(
                server: server,
                share: share.name,
                path: "",
                onOpenFolder: { folder in
                    path.wrappedValue.append(.folder(server, share, folder))
                }
            )
        case .folder(let server, let share, let folder):
            BrowseView(
                server: server,
                share: share.name,
                path: folder,
                onOpenFolder: { sub in
                    path.wrappedValue.append(.folder(server, share, sub))
                }
            )
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
