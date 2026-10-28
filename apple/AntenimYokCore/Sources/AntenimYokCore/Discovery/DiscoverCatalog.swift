import Foundation

/// The downloaded station list of Discover: merges duplicates, filters by genre and search text locally.
public struct DiscoverCatalog: Sendable {
    public let stations: [DiscoveredStation]

    /// Radio Browser lists some stations several times; keeps the first (most voted, if the list is sorted by votes)
    /// entry per folded name.
    public init(_ found: [DiscoveredStation]) {
        var seen = Set<String>()
        stations = found.filter { seen.insert(StationSearch.fold($0.station.name)).inserted }
    }

    public func filtered(genre: Genre = .all, query: String? = nil) -> [DiscoveredStation] {
        stations.filter { genre.matches($0) && StationSearch.matches($0.station, query: query) }
    }
}
