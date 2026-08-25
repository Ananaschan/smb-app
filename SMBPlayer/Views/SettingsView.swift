import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var stats: ImageLoader.CacheStats?
    @State private var isClearing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("图片缓存") {
                    LabeledContent("占用空间", value: bytesText)
                    LabeledContent("文件数量", value: countText)
                    LabeledContent("缓存上限", value: "4 GB")
                    Button(role: .destructive) {
                        Task { await clearCache() }
                    } label: {
                        if isClearing {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("正在清除…")
                            }
                        } else {
                            Label("清除缓存", systemImage: "trash")
                        }
                    }
                    .disabled(isClearing || (stats?.bytes ?? 0) == 0)
                }
                Section("说明") {
                    Text("图片缩略图和原图会缓存到本地，最多占用 4 GB。缓存接近上限时会自动清理最早的文件，你也可以随时手动清除。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                stats = await ImageLoader.shared.cacheStats()
            }
        }
    }

    private var bytesText: String {
        ByteCountFormatter.string(fromByteCount: stats?.bytes ?? 0, countStyle: .file)
    }

    private var countText: String {
        "\(stats?.fileCount ?? 0) 个"
    }

    private func clearCache() async {
        isClearing = true
        await ImageLoader.shared.clearCache()
        stats = await ImageLoader.shared.cacheStats()
        isClearing = false
    }
}
