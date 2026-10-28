import AntenimYokCore
import SwiftUI

/// Always-visible mini player: logo, name, status/song, play-stop (and volume on the Mac).
struct NowPlayingBar: View {
    @Environment(AppModel.self) private var model
    @State private var showsDetail = false

    var body: some View {
        if let station = model.nowPlayingStation {
            HStack(spacing: 12) {
                Button {
                    #if os(iOS)
                    showsDetail = true
                    #endif
                } label: {
                    HStack(spacing: 12) {
                        StationLogo(station: station)
                            .frame(width: 44, height: 44)
                        NowPlayingText(station: station)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Ayrıntıları aç")

                Spacer(minLength: 0)

                #if os(macOS)
                VolumeControl()
                #endif
                PlayStopButton()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
            #if os(iOS)
            .sheet(isPresented: $showsDetail) {
                NowPlayingSheet(station: station)
            }
            #endif
        }
    }
}

/// Name plus a status line: song title, "Çalıyor · AAC+ 64", "Bağlanıyor…" or the error.
struct NowPlayingText: View {
    @Environment(AppModel.self) private var model
    let station: Station
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(station.name)
                .font(.headline)
                .lineLimit(1)
            Text(status)
                .font(.caption)
                .foregroundStyle(model.player.state == .error ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                .lineLimit(1)
        }
    }

    private var status: String {
        switch model.player.state {
        case .stopped: "Durdu"
        case .connecting: "Bağlanıyor…"
        case .reconnecting: "Yeniden bağlanılıyor…"
        case .error: "Yayına ulaşılamadı"
        case .playing:
            if let title = model.songs.currentTitle { title } else { "Çalıyor" + qualitySuffix }
        }
    }

    private var qualitySuffix: String {
        guard let stream = model.player.currentStream, let codec = stream.codec else { return "" }
        return " · " + (stream.bitrate.map { "\(codec) \($0)" } ?? codec)
    }
}

struct PlayStopButton: View {
    @Environment(AppModel.self) private var model
    var size: CGFloat = 44

    var body: some View {
        let state = model.player.state
        Button {
            model.togglePlayback()
        } label: {
            Group {
                if state == .connecting || state == .reconnecting {
                    ProgressView()
                } else {
                    Image(systemName: state == .playing ? "stop.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(model.player.isActive ? "Durdur" : "Çal")
        .help(model.player.isActive ? "Durdur" : "Çal")
    }
}

#if os(macOS)
private struct VolumeControl: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 8) {
            Button {
                model.isMuted.toggle()
            } label: {
                Image(systemName: model.isMuted || model.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 24)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(model.isMuted ? "Sesi aç" : "Sessize al")
            .help(model.isMuted ? "Sesi aç" : "Sessize al")

            Slider(value: $model.volume, in: 0...1)
                .frame(width: 120)
                .accessibilityLabel("Ses")
        }
    }
}
#endif

#if os(iOS)
/// Expanded player (tap on the bar): big logo, name, song and the play/stop button.
struct NowPlayingSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let station: Station

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                StationLogo(station: station)
                    .frame(maxWidth: 280)
                NowPlayingText(station: station, alignment: .center)
                    .multilineTextAlignment(.center)
                PlayStopButton(size: 72)
                    .font(.largeTitle)
                Button(model.isFavorite(station) ? "Favorilerden çıkar" : "Favorilere ekle",
                       systemImage: model.isFavorite(station) ? "star.fill" : "star") {
                    model.toggleFavorite(station)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
#endif
