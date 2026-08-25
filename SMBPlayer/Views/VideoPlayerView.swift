import AudioToolbox
import MediaPlayer
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
    @State private var hideTimerTask: Task<Void, Never>?

    private enum DragMode {
        case seek
        case volume
        case brightness
    }

    @State private var dragMode: DragMode?
    @State private var dragStartPosition: Double = 0
    @State private var dragStartVolume: Float = 0
    @State private var dragStartBrightness: CGFloat = 0
    @State private var gestureHint: (icon: String, text: String)?

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

            if let hint = gestureHint {
                VStack(spacing: 4) {
                    Image(systemName: hint.icon)
                        .font(.body.weight(.semibold))
                    Text(hint.text)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .transition(.opacity)
            }
        }
        .statusBarHidden(controlsVisible)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleControls()
        }
        .gesture(playerDragGesture)
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
        .onChange(of: controlsVisible) { visible in
            if visible {
                scheduleAutoHide()
            } else {
                hideTimerTask?.cancel()
            }
        }
        .onChange(of: model.isPlaying) { playing in
            if playing {
                scheduleAutoHide()
            } else {
                hideTimerTask?.cancel()
            }
        }
        .onDisappear {
            hideTimerTask?.cancel()
            model.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var playerDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if dragMode == nil {
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > abs(dy) {
                        dragMode = .seek
                        dragStartPosition = model.position
                    } else {
                        dragStartVolume = VolumeController.volume
                        dragStartBrightness = UIScreen.main.brightness
                        dragMode = value.startLocation.x > UIScreen.main.bounds.midX
                            ? .volume
                            : .brightness
                    }
                }
                applyDrag(value)
            }
            .onEnded { _ in
                dragMode = nil
                withAnimation(.easeOut(duration: 0.2)) {
                    gestureHint = nil
                }
            }
    }

    private func applyDrag(_ value: DragGesture.Value) {
        let screen = UIScreen.main.bounds
        switch dragMode {
        case .seek:
            let delta = Double(value.translation.width / screen.width)
            let newPosition = min(1, max(0, dragStartPosition + delta))
            model.seek(to: newPosition)
            gestureHint = (
                "arrow.left.and.right",
                "\(model.currentTimeText) / \(model.durationText)"
            )
        case .volume:
            let delta = -Float(value.translation.height / screen.height)
            let newVolume = min(1, max(0, dragStartVolume + delta))
            VolumeController.volume = newVolume
            gestureHint = ("speaker.wave.2.fill", "\(Int(newVolume * 100))%")
        case .brightness:
            let delta = -CGFloat(value.translation.height / screen.height)
            let newBrightness = min(1, max(0, dragStartBrightness + delta))
            UIScreen.main.brightness = newBrightness
            gestureHint = ("sun.max.fill", "\(Int(newBrightness * 100))%")
        case nil:
            break
        }
    }

    private func toggleControls() {
        withAnimation(.easeOut(duration: 0.2)) {
            controlsVisible.toggle()
        }
    }

    /// 播放中自动隐藏控制条（暂停时保持显示）
    private func scheduleAutoHide() {
        hideTimerTask?.cancel()
        guard model.isPlaying else { return }
        hideTimerTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                controlsVisible = false
            }
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
                        .padding(10)
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
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding()

            Spacer()

            VStack(spacing: 8) {
                if !model.bufferingText.isEmpty {
                    Text(model.bufferingText)
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                HStack(spacing: 12) {
                    Button {
                        model.togglePlayPause()
                    } label: {
                        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
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
                    Text("\(model.currentTimeText) / \(model.durationText)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 14)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.6), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
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

/// 通过 MPVolumeView 内部的 UISlider 调节系统音量
private enum VolumeController {
    private static let volumeView = MPVolumeView(frame: .zero)

    private static var slider: UISlider? {
        volumeView.subviews.compactMap { $0 as? UISlider }.first
    }

    static var volume: Float {
        get { AVAudioSession.sharedInstance().outputVolume }
        set {
            slider?.value = newValue
        }
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
