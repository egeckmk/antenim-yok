import Foundation

/// The two text lines the system "Now Playing" shows (lock screen, Control Center, AirPods).
public struct NowPlayingDescription: Equatable, Sendable {
    /// Song title while one is known, otherwise the station name.
    public var title: String
    /// Station name next to a song title; otherwise a status ("Bağlanıyor…") or nil when plainly playing/stopped.
    public var subtitle: String?

    public init(title: String, subtitle: String?) {
        self.title = title
        self.subtitle = subtitle
    }

    /// `songTitle` counts only while `state == .playing` (a stale title is ignored).
    public static func make(station: Station, state: PlaybackState, songTitle: String?) -> NowPlayingDescription {
        if state == .playing, let song = songTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !song.isEmpty {
            return NowPlayingDescription(title: song, subtitle: station.name)
        }
        let status: String? = switch state {
        case .connecting: "Bağlanıyor…"
        case .reconnecting: "Yeniden bağlanılıyor…"
        case .error: "Yayına ulaşılamadı"
        case .playing, .stopped: nil
        }
        return NowPlayingDescription(title: station.name, subtitle: status)
    }
}
