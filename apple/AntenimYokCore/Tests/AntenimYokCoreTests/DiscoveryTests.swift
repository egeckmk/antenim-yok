import Foundation
import Testing
@testable import AntenimYokCore

@Suite struct DiscoveryTests {
    static let json = """
    [
      { "stationuuid": "u1", "name": " Radyo A ", "url": "http://a/x.pls", "url_resolved": "http://a/live",
        "favicon": "https://a/logo.png", "tags": "pop,turkish pop,Pop", "codec": "MP3", "bitrate": 128, "hls": 0, "votes": 10 },
      { "stationuuid": "u2", "name": "Radyo B", "url": "https://b/playlist.m3u8", "url_resolved": "",
        "favicon": "", "tags": "", "codec": "UNKNOWN", "bitrate": 0, "hls": 1, "votes": 3 },
      { "stationuuid": "u3", "name": "Broken", "url": "not a url", "url_resolved": "" },
      { "stationuuid": "", "name": "No id", "url": "http://c/live" }
    ]
    """

    @Test func mapsStationsAndSkipsInvalid() async throws {
        let transport = FakeTransport(json: Self.json)
        let result = try await RadioBrowserClient(transport: transport).stations(countryCode: "TR")

        #expect(result.count == 2)
        let a = result[0]
        #expect(a.station.id == "rb-u1")
        #expect(a.station.name == "Radyo A")
        #expect(a.station.radioBrowserUuid == "u1")
        #expect(a.station.logo == "https://a/logo.png")
        #expect(a.station.streams[0].url == "http://a/live")
        #expect(a.station.streams[0].type == .icecast)
        #expect(a.station.streams[0].bitrate == 128)
        #expect(a.station.streams[0].codec == "MP3")
        #expect(a.tags == ["pop", "turkish pop"])
        #expect(a.votes == 10)

        let b = result[1]
        #expect(b.station.logo == nil)
        #expect(b.station.streams[0].type == .hls)
        #expect(b.station.streams[0].url == "https://b/playlist.m3u8")
        #expect(b.station.streams[0].codec == nil)
        #expect(b.station.streams[0].bitrate == nil)
    }

    @Test func requestUsesCountryEndpointAndQuery() async throws {
        let transport = FakeTransport(json: "[]")
        _ = try await RadioBrowserClient(transport: transport).stations(countryCode: "TR")
        let url = try #require(transport.recorded.first?.url)
        #expect(url.path.hasSuffix("/stations/bycountrycodeexact/TR"))
        let q = url.query ?? ""
        #expect(q.contains("hidebroken=true"))
        #expect(q.contains("order=votes"))
        #expect(q.contains("reverse=true"))
    }

    @Test func searchUsesNameAndCountry() async throws {
        let transport = FakeTransport(json: "[]")
        _ = try await RadioBrowserClient(transport: transport).search(name: "power türk", countryCode: "TR")
        let url = try #require(transport.recorded.first?.url)
        #expect(url.path.hasSuffix("/stations/search"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "name" }?.value == "power türk")
        #expect(items.first { $0.name == "countrycode" }?.value == "TR")
    }

    @Test func nonSuccessStatusThrows() async {
        let transport = FakeTransport(json: "[]", status: 503)
        await #expect(throws: HTTPError(statusCode: 503)) {
            try await RadioBrowserClient(transport: transport).stations(countryCode: "TR")
        }
    }

    @Test func malformedJsonThrows() async {
        let transport = FakeTransport(json: "{ nope")
        await #expect(throws: (any Error).self) {
            try await RadioBrowserClient(transport: transport).stations(countryCode: "TR")
        }
    }

    @Test(arguments: [
        ("Pop", "turkish pop", true),
        ("Türkü / Halk", "Türkü", true),
        ("Türkü / Halk", "turku", true),
        ("Nostalji", "80s", true),
        ("Haber / Konuşma", "news", true),
        ("Rock", "pop", false),
        ("Tümü", "anything", true),
    ])
    func genreMatchesTags(genreName: String, tag: String, expected: Bool) throws {
        let genre = try #require(Genre.defaults.first { $0.name == genreName })
        let station = DiscoveredStation(station: Station(id: "x", name: "X"), tags: [tag])
        #expect(genre.matches(station) == expected)
    }

    @Test func genreAllMatchesStationWithoutTags() {
        let station = DiscoveredStation(station: Station(id: "x", name: "X"))
        #expect(Genre.all.matches(station))
        #expect(!Genre.defaults[1].matches(station))
        #expect(Genre.defaults.count == 12)
    }

    @Test func catalogMergesSameNamedKeepingFirst() {
        func d(_ id: String, _ name: String, tags: [String] = []) -> DiscoveredStation {
            DiscoveredStation(station: Station(id: id, name: name), tags: tags)
        }
        let catalog = DiscoverCatalog([d("1", "Power Türk"), d("2", "POWER TURK"), d("3", "Kafa Radyo")])
        #expect(catalog.stations.map(\.id) == ["1", "3"])
    }

    @Test func catalogFiltersByGenreAndQuery() {
        func d(_ id: String, _ name: String, _ tags: [String]) -> DiscoveredStation {
            DiscoveredStation(station: Station(id: id, name: name), tags: tags)
        }
        let catalog = DiscoverCatalog([d("1", "Power Türk", ["pop"]), d("2", "Power Rock", ["rock"]), d("3", "Kafa", ["pop"])])
        let pop = Genre.defaults.first { $0.name == "Pop" }!
        #expect(catalog.filtered(genre: pop).map(\.id) == ["1", "3"])
        #expect(catalog.filtered(query: "power").map(\.id) == ["1", "2"])
        #expect(catalog.filtered(genre: pop, query: "power").map(\.id) == ["1"])
        #expect(catalog.filtered().count == 3)
    }

    @Test func summaryShowsTagsAndCodec() {
        let s = Station(id: "x", name: "X", streams: [StationStream(url: "https://x", codec: "MP3", bitrate: 128)])
        #expect(DiscoveredStation(station: s, tags: ["pop", "turkish", "a", "b"]).summary == "pop · turkish · a · MP3 128 kbps")
    }
}
