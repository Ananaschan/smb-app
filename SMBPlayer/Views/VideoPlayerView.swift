import AudioToolbox
import MobileVLCKit
import SwiftUI
import UIKit

struct VideoPlayerView: View {
    let item: RemoteItem
    let server: SMBServer
    let share: String
    let service: SMBFileService

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = VLCPlayerViewModel()
    @State private var subtitleItems: [RemoteItem] = []
    @State private var controlsVisible = true

    private var password: String {
        KeychainStore.password(for: server) ?? ""
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VLCPlayerCanvas(player: model.player)
                .ignoresSafeArea()

            if controlsVisible {
                controlsOverlay
            }
        }
        .statusBarHidden(controlsVisible)
        .onTapGesture {
            withAnimation {
                controlsVisible.toggle()
            }
        }
        .task {
            model.play(
                item: item,
                server: server,
                share: share,
                password: password
            )
            UIApplication.shared.isIdleTimerDisabled = true
            await loadSubtitles()
        }
        .onDisappear {
            model.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                Spacer()
                Menu {
                    if subtitleItems.isEmpty {
                        Text("未找到外挂字幕")
                    } else {
                        ForEach(subtitleItems) { subtitle in
                            Button(subtitle.name) {
                                select(subtitle)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "captions.bubble")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding()

            Spacer()

            VStack(spacing: 10) {
                if !model.bufferingText.isEmpty {
                    Text(model.bufferingText)
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                Slider(
                    value: $model.position,
                    in: 0...1
                ) { editing in
                    if !editing {
                        model.seek(to: model.position)
                    }
                }
                .tint(.white)

                HStack {
                    Text(model.currentTimeText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        model.togglePlayPause()
                    } label: {
                        Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text(model.durationText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    @MainActor
    private func select(_ subtitle: RemoteItem) {
        guard let url = VLCPlayerViewModel.smbURL(
            path: subtitle.path,
            server: server,
            share: share,
            password: password
        ) else {
            return
        }
        model.selectSubtitle(url: url)
    }

    @MainActor
    private func loadSubtitles() async {
        let parentPath = RemoteItem.parentPath(of: item.path)
        guard let items = try? await service.listDirectory(at: parentPath) else {
            return
        }
        subtitleItems = items.filter(\.isSubtitle)
        let stem = (item.name as NSString).deletingPathExtension.lowercased()
        guard let auto = subtitleItems.first(where: {
            ($0.name as NSString).deletingPathExtension.lowercased() == stem
        }) else {
            return
        }
        select(auto)
    }
}

struct VLCPlayerCanvas: UIViewRepresentable {
    let player: VLCMediaPlayer

    func makeUIView(context: Context) -> PlayerCanvasView {
        let view = PlayerCanvasView(frame: .zero)
        player.drawable = view
        return view
    }

    func updateUIView(_ uiView: PlayerCanvasView, context: Context) {}

    final class PlayerCanvasView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
