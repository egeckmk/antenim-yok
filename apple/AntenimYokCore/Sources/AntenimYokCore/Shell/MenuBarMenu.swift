import Foundation

/// One entry of the Mac menu bar menu (the Windows tray menu's counterpart).
public enum MenuBarItem: Equatable, Sendable {
    /// A favorite; `isPlaying` marks the one that is playing.
    case station(id: String, name: String, isPlaying: Bool)
    /// "Çal" / "Durdur".
    case playPause(title: String, isEnabled: Bool)
    case showWindow
    case quit
    case separator

    public var title: String? {
        switch self {
        case .station(_, let name, _): name
        case .playPause(let title, _): title
        case .showWindow: "Pencereyi göster"
        case .quit: "Çıkış"
        case .separator: nil
        }
    }
}

public enum MenuBarMenu {
    /// favorites (playing one marked), separator, play/stop, show window, separator, quit.
    /// `isActive`: connecting, playing or reconnecting (then the button says "Durdur").
    /// `hasStationToPlay`: there is a station Çal can start (the last one played).
    public static func items(
        favorites: [Station],
        playingStationId: String?,
        isActive: Bool,
        hasStationToPlay: Bool
    ) -> [MenuBarItem] {
        var items: [MenuBarItem] = favorites.map {
            .station(id: $0.id, name: $0.name, isPlaying: isActive && $0.id == playingStationId)
        }
        if !favorites.isEmpty { items.append(.separator) }
        items.append(.playPause(title: isActive ? "Durdur" : "Çal", isEnabled: isActive || hasStationToPlay))
        items.append(.showWindow)
        items.append(.separator)
        items.append(.quit)
        return items
    }

    /// Whether closing the last window quits the app.
    public static func quitsWhenLastWindowCloses(keepPlayingInMenuBar: Bool) -> Bool {
        !keepPlayingInMenuBar
    }
}
