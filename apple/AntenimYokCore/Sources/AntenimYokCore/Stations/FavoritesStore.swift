import Foundation
import Synchronization

/// The user's favorites (order matters: previous/next), kept locally in `favorites.json`.
/// Starts empty. Each favorite is a full snapshot (streams, logo), so it plays without any lookup.
public final class FavoritesStore: Sendable {
    public static var defaultURL: URL { AtomicFile.defaultURL(fileName: "favorites.json") }

    private let url: URL
    private let list = Mutex<[Station]>([])

    public init(url: URL = FavoritesStore.defaultURL) {
        self.url = url
    }

    public var favorites: [Station] { list.withLock { $0 } }

    /// Loads favorites from disk (empty on first run or when the file is unreadable).
    @discardableResult
    public func load() -> [Station] {
        var loaded: [Station] = []
        if let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(FavoritesFile.self, from: data) {
            var seen = Set<String>()
            loaded = file.stations.filter { seen.insert($0.id).inserted }
        }
        list.withLock { $0 = loaded }
        return loaded
    }

    public func isFavorite(_ stationId: String) -> Bool {
        list.withLock { $0.contains { $0.id == stationId } }
    }

    public func add(_ station: Station) {
        let snapshot: [Station]? = list.withLock { stations in
            guard !stations.contains(where: { $0.id == station.id }) else { return nil }
            stations.append(station)
            return stations
        }
        if let snapshot { save(snapshot) }
    }

    public func remove(_ stationId: String) {
        let snapshot: [Station]? = list.withLock { stations in
            let before = stations.count
            stations.removeAll { $0.id == stationId }
            return stations.count == before ? nil : stations
        }
        if let snapshot { save(snapshot) }
    }

    private func save(_ stations: [Station]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(FavoritesFile(stations: stations)) else { return }
        try? AtomicFile.write(data, to: url)
    }

    private struct FavoritesFile: Codable {
        var stations: [Station]
    }
}
