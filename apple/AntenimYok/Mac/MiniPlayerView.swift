#if os(macOS)
import AntenimYokCore
import AppKit
import SwiftUI

/// Small always-on-top player: logo + name, previous / play-stop / next favorite, volume, back to the main window.
struct MiniPlayerView: View {
    static let size = CGSize(width: 380, height: 104)

    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        HStack(spacing: 12) {
            if let station = model.nowPlayingStation {
                StationLogo(station: station)
                    .frame(width: 56, height: 56)
            } else {
                Image(systemName: "radio")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Group {
                        if let station = model.nowPlayingStation {
                            NowPlayingText(station: station)
                        } else {
                            Text("Radyo seçilmedi").font(.headline)
                        }
                    }
                    Spacer(minLength: 0)
                    controls
                }
                HStack(spacing: 8) {
                    Button {
                        model.isMuted.toggle()
                    } label: {
                        Image(systemName: model.isMuted || model.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .frame(width: 20)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(model.isMuted ? "Sesi aç" : "Sessize al")
                    .help(model.isMuted ? "Sesi aç" : "Sessize al")
                    Slider(value: $model.volume, in: 0...1)
                        .accessibilityLabel("Ses")
                    Button {
                        openWindow(id: MacWindow.main)
                        dismissWindow(id: MacWindow.mini)
                        NSApplication.shared.activate()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Ana pencereye dön")
                    .help("Ana pencereye dön")
                }
            }
        }
        .padding(12)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(MiniWindowConfigurator(model: model))
        .preferredColorScheme(model.theme.colorScheme)
    }

    private var controls: some View {
        HStack(spacing: 0) {
            Button {
                model.playAdjacentFavorite(-1)
            } label: {
                Image(systemName: "backward.fill").frame(width: 32, height: 32)
            }
            .disabled(model.favorites.isEmpty)
            .accessibilityLabel("Önceki favori")
            .help("Önceki favori")
            PlayStopButton(size: 32)
            Button {
                model.playAdjacentFavorite(1)
            } label: {
                Image(systemName: "forward.fill").frame(width: 32, height: 32)
            }
            .disabled(model.favorites.isEmpty)
            .accessibilityLabel("Sonraki favori")
            .help("Sonraki favori")
        }
        .buttonStyle(.borderless)
    }
}

/// Makes the hosting window a mini player: floating, not resizable, movable by its background,
/// placed where it was left (and kept on a screen).
private struct MiniWindowConfigurator: NSViewRepresentable {
    let model: AppModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            context.coordinator.configure(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    @MainActor
    final class Coordinator {
        private let model: AppModel
        private var observer: (any NSObjectProtocol)?

        init(model: AppModel) {
            self.model = model
        }

        func configure(_ window: NSWindow) {
            window.level = .floating
            window.styleMask.remove([.resizable, .miniaturizable])
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.collectionBehavior.insert(.canJoinAllSpaces)

            let frames = NSScreen.screens.map {
                PlacementRect(x: $0.visibleFrame.minX, y: $0.visibleFrame.minY, width: $0.visibleFrame.width, height: $0.visibleFrame.height)
            }
            let size = window.frame.size
            if let origin = MiniPlayerPlacement.origin(
                saved: model.miniPlayerPosition, size: (size.width, size.height), visibleFrames: frames) {
                window.setFrameOrigin(NSPoint(x: origin.x, y: origin.y))
            }

            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification, object: window, queue: .main
            ) { [weak self, weak window] _ in
                MainActor.assumeIsolated {
                    guard let window else { return }
                    self?.model.saveMiniPlayerPosition(WindowPosition(x: window.frame.minX, y: window.frame.minY))
                }
            }
        }
    }
}
#endif
