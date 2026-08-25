import SwiftUI
import UIKit

struct ImageViewerView: View {
    let item: RemoteItem
    let server: SMBServer
    let service: SMBFileService

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var loadFailed = false
    @State private var isSaving = false
    @State private var saveResult: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
            .disabled(isSaving || image == nil)
        }
        .alert("提示", isPresented: Binding(
            get: { saveResult != nil },
            set: { if !$0 { saveResult = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveResult ?? "")
        }
        .task {
            if image == nil {
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

    @MainActor
    private func save() {
        isSaving = true
        Task {
            do {
                try await ImageSaver.saveOriginal(item, service: service)
                saveResult = "已保存到相册"
            } catch {
                saveResult = error.localizedDescription
            }
            isSaving = false
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
