import AntenimYokCore
import MediaPlayer
import Observation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The system "Now Playing": Control Center and media keys on Mac, lock screen and AirPods on iPhone.
/// Play/pause = play/stop, next/previous = next/previous favorite (like SMTC on Windows).
@MainActor
final class NowPlayingController {
    private enum Command: Sendable {
        case play, stop, toggle, next, previous
    }

    private unowned let model: AppModel
    private var artworkStationId: String?
    private var artwork: MPMediaItemArtwork?
    private var artworkTask: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
        Self.registerCommands { [weak self] command in
            Task { @MainActor in self?.handle(command) }
        }
        track()
    }

    private func handle(_ command: Command) {
        switch command {
        case .play: if !model.player.isActive { model.togglePlayback() }
        case .stop: if model.player.isActive { model.player.stop() }
        case .toggle: model.togglePlayback()
        case .next: model.playAdjacentFavorite(1)
        case .previous: model.playAdjacentFavorite(-1)
        }
    }

    /// Re-runs `update` whenever the player, the song title or the favorites change.
    private func track() {
        withObservationTracking {
            update()
        } onChange: { [weak self] in
            Task { @MainActor in self?.track() }
        }
    }

    private func update() {
        let center = MPNowPlayingInfoCenter.default()
        let commands = MPRemoteCommandCenter.shared()
        commands.nextTrackCommand.isEnabled = !model.favorites.isEmpty
        commands.previousTrackCommand.isEnabled = !model.favorites.isEmpty

        guard let station = model.nowPlayingStation else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }

        let player = model.player
        let text = NowPlayingDescription.make(station: station, state: player.state, songTitle: model.songs.currentTitle)
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: text.title,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            // Without a rate the system treats the app as paused, so the lock screen / Control Center hide the card.
            MPNowPlayingInfoPropertyPlaybackRate: player.isActive ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let subtitle = text.subtitle {
            info[MPMediaItemPropertyArtist] = subtitle
        }
        loadArtwork(for: station)
        if artworkStationId == station.id, let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        center.nowPlayingInfo = info
        center.playbackState = player.isActive ? .playing : .paused
    }

    private func loadArtwork(for station: Station) {
        guard artworkStationId != station.id else { return }
        artworkStationId = station.id
        artwork = nil
        artworkTask?.cancel()
        // No logo, or it cannot be loaded: initials on a neutral tile (like the in-app placeholder).
        let initials = station.initials
        artwork = Self.makeInitialsArtwork(initials)
        guard let logo = station.logo, let url = URL(string: logo) else { return }
        artworkTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let artwork = Self.makeArtwork(data),
                  let self, !Task.isCancelled, artworkStationId == station.id
            else { return }
            self.artwork = artwork
            update()
        }
    }

    // Nonisolated: the system calls these handlers off the main thread, and closures formed
    // in a @MainActor context would trap there.

    private nonisolated static func registerCommands(_ send: @escaping @Sendable (Command) -> Void) {
        let center = MPRemoteCommandCenter.shared()
        let commands: [(MPRemoteCommand, Command)] = [
            (center.playCommand, .play),
            (center.pauseCommand, .stop),
            (center.stopCommand, .stop),
            (center.togglePlayPauseCommand, .toggle),
            (center.nextTrackCommand, .next),
            (center.previousTrackCommand, .previous),
        ]
        for (command, action) in commands {
            command.isEnabled = true
            command.addTarget { _ in
                send(action)
                return .success
            }
        }
        // A live stream has no timeline: make sure no seek/skip controls are inferred.
        for command in [center.skipForwardCommand, center.skipBackwardCommand, center.seekForwardCommand,
                        center.seekBackwardCommand, center.changePlaybackPositionCommand,
                        center.changePlaybackRateCommand] {
            command.isEnabled = false
        }
    }

    private nonisolated static func makeInitialsArtwork(_ initials: String) -> MPMediaItemArtwork {
        let size = CGSize(width: 512, height: 512)
        return MPMediaItemArtwork(boundsSize: size) { requested in
            let side = max(requested.width, 1)
            let rect = CGRect(x: 0, y: 0, width: side, height: side)
            #if os(macOS)
            return NSImage(size: rect.size, flipped: false) { rect in
                NSColor.systemGray.setFill()
                rect.fill()
                drawInitials(initials, in: rect, color: NSColor.windowBackgroundColor)
                return true
            }
            #else
            return UIGraphicsImageRenderer(size: rect.size).image { _ in
                UIColor.systemGray.setFill()
                UIRectFill(rect)
                drawInitials(initials, in: rect, color: UIColor.systemBackground)
            }
            #endif
        }
    }

    #if os(macOS)
    private nonisolated static func drawInitials(_ text: String, in rect: CGRect, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: rect.height * 0.4, weight: .semibold), .foregroundColor: color,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        string.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
    }
    #else
    private nonisolated static func drawInitials(_ text: String, in rect: CGRect, color: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: rect.height * 0.4, weight: .semibold), .foregroundColor: color,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        string.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
    }
    #endif

    private nonisolated static func makeArtwork(_ data: Data) -> MPMediaItemArtwork? {
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        #else
        guard let image = UIImage(data: data) else { return nil }
        #endif
        let box = ImageBox(image: image)
        return MPMediaItemArtwork(boundsSize: image.size) { _ in box.image }
    }
}

/// The image is never mutated after loading.
private struct ImageBox: @unchecked Sendable {
    #if os(macOS)
    let image: NSImage
    #else
    let image: UIImage
    #endif
}
