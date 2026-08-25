import SwiftUI
import UIKit

struct MediaSelection: Identifiable {
    let item: RemoteItem
    var id: String { item.id }
}

struct BrowseView: View {
    let server: SMBServer
    let share: String

    @StateObject private var service: SMBFileService
    @State private var pathStack: [String] = []
    @State private var sort: RemoteFileSort = .name
    @State private var isAscending = true
    @State private var gridMode = true
    @State private var isLoading = false

    @State private var selectedMedia: MediaSelection?

    @State private var newEntryType: NewEntryType?
    @State private var showNewEntry = false
    @State private var newName = ""
    @State private var renameTarget: RemoteItem?
    @State private var showRename = false
    @State private var deleteTarget: RemoteItem?
    @State private var alertMessage = ""
    @State private var showError = false

    @MainActor
    init(server: SMBServer, share: String) {
        self.server = server
        self.share = share
        let password = KeychainStore.password(for: server) ?? ""
        _service = StateObject(
            wrappedValue: SMBFileService(server: server, share: share, password: password)
        )
    }

    var body: some View {
        NavigationStack(path: $pathStack) {
            directoryView(path: "")
                .navigationDestination(for: String.self) { path in
                    directoryView(path: path)
                }
        }
    }

    @ViewBuilder
    private func directoryView(path: String) -> some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if service.entries.isEmpty {
                emptyState
            } else if gridMode {
                thumbnailGrid
            } else {
                fileList
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Section("视图") {
                        Button {
                            gridMode.toggle()
                        } label: {
                            Label(
                                gridMode ? "列表视图" : "缩略图视图",
                                systemImage: gridMode ? "list.bullet" : "square.grid.2x2"
                            )
                        }
                    }
                    Section("排序") {
                        Button {
                            setSort(.name)
                        } label: {
                            Label(
                                "名称",
                                systemImage: sort == .name ? "checkmark" : "textformat"
                            )
                        }
                        Button {
                            setSort(.date)
                        } label: {
                            Label(
                                "日期",
                                systemImage: sort == .date ? "checkmark" : "calendar"
                            )
                        }
                        Button {
                            isAscending.toggle()
                        } label: {
                            Label(
                                isAscending ? "升序" : "降序",
                                systemImage: isAscending ? "arrow.up" : "arrow.down"
                            )
                        }
                    }
                    Divider()
                    Button {
                        beginNew(.folder)
                    } label: {
                        Label("新建文件夹", systemImage: "folder.badge.plus")
                    }
                    Button {
                        beginNew(.file)
                    } label: {
                        Label("新建文件", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task(id: path) {
            await load(path: path)
        }
        .refreshable {
            await load(path: path)
        }
        .navigationTitle(path.isEmpty ? share : (path as NSString).lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            newEntryType == NewEntryType.folder ? "新建文件夹" : "新建文件",
            isPresented: $showNewEntry
        ) {
            TextField("名称", text: $newName)
            Button("创建") {
                Task { await performCreate() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(newEntryType == NewEntryType.folder ? "输入文件夹名称" : "输入文件名")
        }
        .alert("重命名", isPresented: $showRename) {
            TextField("新名称", text: $newName)
            Button("确定") {
                Task { await performRename() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(renameTarget?.name ?? "")
        }
        .alert("操作失败", isPresented: $showError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            deleteTarget.map { "删除“\($0.name)”？" } ?? "删除？",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                Task { await performDelete() }
            }
            Button("取消", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            Text("此操作无法撤销")
        }
        .fullScreenCover(item: $selectedMedia) { media in
            if media.item.isVideo {
                VideoPlayerView(
                    item: media.item,
                    server: server,
                    share: share,
                    service: service
                )
            } else {
                ImageViewerView(
                    item: media.item,
                    server: server,
                    service: service
                )
            }
        }
    }

    private var thumbnailGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(sortedEntries) { item in
                    GridCell(
                        item: item,
                        server: server,
                        service: service,
                        action: { open(item) }
                    )
                    .contextMenu {
                        contextMenu(for: item)
                    }
                }
            }
            .padding()
        }
    }

    private var fileList: some View {
        List {
            ForEach(sortedEntries) { item in
                row(for: item)
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("空文件夹")
                .font(.headline)
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 14)
        ]
    }

    private var sortedEntries: [RemoteItem] {
        service.entries.sorted {
            RemoteFileSort.compares(
                $0,
                $1,
                sort: sort,
                ascending: isAscending
            )
        }
    }

    private func row(for item: RemoteItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.title3)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)
                Text(meta(for: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            open(item)
        }
        .contextMenu {
            contextMenu(for: item)
        }
    }

    @ViewBuilder
    private func contextMenu(for item: RemoteItem) -> some View {
        Button {
            beginRename(item)
        } label: {
            Label("重命名", systemImage: "pencil")
        }
        Button(role: .destructive) {
            deleteTarget = item
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private func meta(for item: RemoteItem) -> String {
        var parts: [String] = []
        if let date = item.modifiedAt {
            parts.append(date.formatted(date: .numeric, time: .shortened))
        }
        if !item.isDirectory, item.size > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
        }
        return parts.joined(separator: " · ")
    }

    private func open(_ item: RemoteItem) {
        if item.isDirectory {
            pathStack.append(item.path)
        } else if item.isImage || item.isVideo {
            selectedMedia = MediaSelection(item: item)
        }
    }

    private func setSort(_ newSort: RemoteFileSort) {
        if sort == newSort {
            isAscending.toggle()
        } else {
            sort = newSort
            isAscending = true
        }
    }

    private func beginNew(_ type: NewEntryType) {
        newEntryType = type
        newName = ""
        showNewEntry = true
    }

    private func beginRename(_ item: RemoteItem) {
        renameTarget = item
        newName = item.name
        showRename = true
    }

    @MainActor
    private func load(path: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            service.entries = try await service.listDirectory(at: path)
        } catch {
            AppLogger.shared.log("BrowseView load failed path=\(path) error=\(error.localizedDescription)")
            presentError(error)
        }
    }

    @MainActor
    private func performCreate() async {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = pathStack.last ?? ""
        defer {
            newEntryType = nil
            showNewEntry = false
        }
        guard !name.isEmpty else {
            return
        }
        do {
            if newEntryType == NewEntryType.folder {
                try await service.createFolder(named: name, in: path)
            } else {
                try await service.createEmptyFile(named: name, in: path)
            }
            await load(path: path)
        } catch {
            presentError(error)
        }
    }

    @MainActor
    private func performRename() async {
        guard let target = renameTarget else {
            return
        }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = RemoteItem.parentPath(of: target.path)
        renameTarget = nil
        showRename = false
        guard !name.isEmpty else {
            return
        }
        do {
            try await service.rename(target, newName: name, in: parent)
            await load(path: parent)
        } catch {
            presentError(error)
        }
    }

    @MainActor
    private func performDelete() async {
        guard let target = deleteTarget else {
            return
        }
        let parent = RemoteItem.parentPath(of: target.path)
        deleteTarget = nil
        do {
            try await service.delete(target)
            await load(path: parent)
        } catch {
            presentError(error)
        }
    }

    @MainActor
    private func presentError(_ error: Error) {
        alertMessage = error.localizedDescription
        showError = true
    }
}

private enum NewEntryType: Equatable {
    case folder
    case file
}

private struct GridCell: View {
    let item: RemoteItem
    let server: SMBServer
    let service: SMBFileService
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                FileThumbnailView(item: item, server: server, service: service)
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(item.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
