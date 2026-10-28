import AntenimYokCore
import Foundation
import Observation

/// Discover: every working Turkish station on Radio Browser, filtered by genre and search text.
/// The list is downloaded once per session (~800 stations, one request) and filtered locally.
@MainActor
@Observable
final class DiscoverModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    private(set) var phase: Phase = .idle
    private(set) var results: [DiscoveredStation] = []
    private(set) var totalCount = 0

    var genre: Genre = .all {
        didSet { refilter() }
    }

    var query: String = "" {
        didSet { refilter() }
    }

    @ObservationIgnored private let client: RadioBrowserClient
    @ObservationIgnored private var catalog: DiscoverCatalog?

    init(client: RadioBrowserClient = RadioBrowserClient()) {
        self.client = client
    }

    var countText: String {
        results.count == totalCount ? "Türkiye'den \(totalCount) radyo" : "\(results.count) / \(totalCount) radyo"
    }

    /// Called when the screen is shown; downloads the list the first time.
    func ensureLoaded() async {
        guard phase == .idle || phase == .failed else { return }
        await load()
    }

    func load() async {
        phase = .loading
        do {
            let found = try await client.stations(countryCode: AntenimYokCore.countryCode)
            let catalog = DiscoverCatalog(found)
            self.catalog = catalog
            totalCount = catalog.stations.count
            phase = .loaded
            refilter()
        } catch {
            phase = .failed
        }
    }

    private func refilter() {
        results = catalog?.filtered(genre: genre, query: query) ?? []
    }
}
