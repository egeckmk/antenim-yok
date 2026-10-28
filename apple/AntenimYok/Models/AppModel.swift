import AntenimYokCore
import Foundation
import Observation

/// Everything the screens share: favorites, settings, the player and Discover.
@MainActor
@Observable
final class AppModel {
    let player: RadioPlayer
    let songs: SongTitleMonitor
    let discover: DiscoverModel
    let network = NetworkMonitor()

    private(set) var favorites: [Station]
    private(set) var settings: AppSettings

    var section: AppSection {
        didSet { settingsStore.update { $0.lastPage = section.rawValue } }
    }

    /// Search text of the Favorites and Discover screens.
    var searchText = ""

    /// The station shown in the Now Playing bar while stopped (the last one played).
    private(set) var lastStation: Station?

    @ObservationIgnored private let favoritesStore: FavoritesStore
    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private var nowPlaying: NowPlayingController?

    init() {
        let favoritesStore = FavoritesStore()
        let loaded = favoritesStore.load()
        let settingsStore = SettingsStore()
        let settings = settingsStore.current

        self.favoritesStore = favoritesStore
        self.settingsStore = settingsStore
        self.favorites = loaded
        self.settings = settings
        self.section = AppSection(rawValue: settings.lastPage ?? "") ?? .favorites
        self.lastStation = loaded.first { $0.id == settings.lastStationId }

        let transport = URLSessionTransport()
        let player = RadioPlayer(
            player: AVStreamPlayer(),
            resolver: StreamResolver(transport: transport),
            volume: settings.volume,
            isMuted: settings.isMuted)
        self.player = player
        self.songs = SongTitleMonitor(player: player, reader: IcyMetadataReader(transport: transport))
        self.songs.isEnabled = settings.showSongTitles
        self.discover = DiscoverModel(client: RadioBrowserClient(transport: transport))

        network.start { [weak player] in player?.notifyNetworkAvailable() }
        nowPlaying = NowPlayingController(model: self)
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let flag = args.firstIndex(of: "-autoplayFavorite"), args.indices.contains(flag + 1),
           let index = Int(args[flag + 1]) {
            playFavorite(at: index)
        }
        if ProcessInfo.processInfo.arguments.contains("-autoplayFirstDiscover") {
            Task {
                await discover.ensureLoaded()
                if let first = discover.results.first { play(first.station) }
            }
        }
        #endif
    }

    // MARK: - Now playing

    var nowPlayingStation: Station? { player.currentStation ?? lastStation }

    func isPlaying(_ station: Station) -> Bool {
        player.isActive && player.currentStation?.id == station.id
    }

    /// Tap on a station: play it, or stop it if it is already playing.
    func toggle(_ station: Station) {
        if isPlaying(station) {
            player.stop()
        } else {
            play(station)
        }
    }

    /// Play/stop button of the Now Playing bar.
    func togglePlayback() {
        if player.isActive {
            player.stop()
        } else if let station = nowPlayingStation {
            play(station)
        }
    }

    func play(_ station: Station) {
        lastStation = station
        settingsStore.update { $0.lastStationId = station.id }
        Task { await player.play(station) }
    }

    // MARK: - Keyboard shortcuts

    /// ⌘↑ / ⌘↓ change the volume by 5 %, like Ctrl+↑/↓ on Windows.
    private static let volumeStep = 0.05

    func changeVolume(by steps: Int) {
        volume += Double(steps) * Self.volumeStep
    }

    /// ⌘1…9: the n-th favorite (0-based index).
    func playFavorite(at index: Int) {
        guard favorites.indices.contains(index) else { return }
        play(favorites[index])
    }

    /// Next/previous track (media keys, Control Center): the neighbouring favorite, wrapping around.
    /// Not playing a favorite: the first one.
    func playAdjacentFavorite(_ offset: Int) {
        if let station = FavoriteNavigation.adjacent(in: favorites, currentId: nowPlayingStation?.id, offset: offset) {
            play(station)
        }
    }

    /// Set by ⌘F; the visible screen focuses its search field.
    var wantsSearchFocus = false

    func focusSearch() {
        if section == .settings { section = .favorites }
        wantsSearchFocus = true
    }

    // MARK: - Favorites

    func isFavorite(_ station: Station) -> Bool {
        favorites.contains { $0.id == station.id }
    }

    func toggleFavorite(_ station: Station) {
        if isFavorite(station) {
            favoritesStore.remove(station.id)
        } else {
            favoritesStore.add(station)
        }
        favorites = favoritesStore.favorites
    }

    var visibleFavorites: [Station] {
        favorites.filter { StationSearch.matches($0, query: searchText) }
    }

    // MARK: - Settings

    var volume: Double {
        get { player.volume }
        set {
            player.volume = newValue
            settingsStore.update { $0.volume = player.volume }
        }
    }

    var isMuted: Bool {
        get { player.isMuted }
        set {
            player.isMuted = newValue
            settingsStore.update { $0.isMuted = newValue }
        }
    }

    var theme: AppTheme {
        get { settings.theme }
        set {
            settings.theme = newValue
            settingsStore.update { $0.theme = newValue }
        }
    }

    var showSongTitles: Bool {
        get { settings.showSongTitles }
        set {
            settings.showSongTitles = newValue
            songs.isEnabled = newValue
            settingsStore.update { $0.showSongTitles = newValue }
        }
    }

    func flushSettings() {
        settingsStore.flush()
    }
}
