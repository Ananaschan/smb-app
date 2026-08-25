import SwiftUI
import UIKit

struct ImageViewerView: View {
    let items: [RemoteItem]
    let server: SMBServer
    let service: SMBFileService

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var dragOffset: CGFloat = 0
    @State private var isSaving = false
    @State private var saveError: String?

    init(items: [RemoteItem], initialIndex: Int, server: SMBServer, service: SMBFileService) {
        self.items = items
        self.server = server
        self.service = service
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ImagePageView(item: item, server: server, service: service)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .overlay(alignment: .topLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(20)
            }
            .overlay(alignment: .top) {
                if items.count > 1 {
                    Text("\(currentIndex + 1) / \(items.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 12)
                }
            }
            .overlay(alignment: .bottomLeading) {
                Button {
                    save()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }
                        Label("保存原图", systemImage: "square.and.arrow.down")
                    }
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.white)
                }
                .padding(20)
                .disabled(isSaving || items.isEmpty)
            }
            .offset(y: dragOffset)
            .opacity(1 - min(abs(dragOffset) / 400, 0.5))
        }
        .gesture(dismissGesture)
        .alert("保存失败", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                dragOffset = value.translation.height
            }
            .onEnded { value in
                if value.translation.height > 140 || value.predictedEndTranslation.height > 400 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
            }
    }

    @MainActor
    private func save() {
        guard items.indices.contains(currentIndex) else { return }
        isSaving = true
        Task {
            do {
                try await ImageSaver.saveOriginal(items[currentIndex], service: service)
                // 保存成功：静默完成，不弹确认框
            } catch {
                saveError = error.localizedDescription
            }
            isSaving = false
        }
    }
}

private struct ImagePageView: View {
    let item: RemoteItem
    let server: SMBServer
    let service: SMBFileService

    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            if let image {
                ZoomableImageView(image: image)
            } else if loadFailed {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                    Text("无法读取图片")
                        .font(.headline)
                }
                .foregroundStyle(.white)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard image == nil, !loadFailed else { return }
            let result = try? await ImageLoader.shared.fullImage(
                for: item,
                server: server,
                service: service
            )
            if let result {
                image = result
            } else {
                loadFailed = true
            }
        }
    }
}

struct ZoomableImageView: View {
    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height
                )
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = min(6, max(1, lastScale * value))
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale <= 1 {
                                withAnimation {
                                    scale = 1
                                    lastScale = 1
                                }
                            }
                        }
                )
        }
    }
}
