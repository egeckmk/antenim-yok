import Foundation
import Testing
@testable import AntenimYokCore

@Suite struct FavoritesStoreTests {
    let dir = makeTempDirectory()
    var url: URL { dir.appendingPathComponent("favorites.json") }
    func store() -> FavoritesStore { FavoritesStore(url: url) }

    @Test func firstRunHasNoFavorites() {
        #expect(store().load().isEmpty)
    }

    @Test func addedStationsSurviveRestartInOrderWithTheirData() {
        let s = store()
        s.load()
        var first = makeStation("rb-2"); first.logo = "https://x/logo.png"
        s.add(first)
        s.add(makeStation("rb-1"))

        let result = store().load()
        #expect(result.map(\.id) == ["rb-2", "rb-1"])
        #expect(result[0].logo == "https://x/logo.png")
        #expect(result[0].streams[0].url == "https://x/live")
    }

    @Test func removedStaysRemoved() {
        let s = store()
        s.load()
        s.add(makeStation("rb-1")); s.add(makeStation("rb-2"))
        s.remove("rb-1")
        #expect(store().load().map(\.id) == ["rb-2"])
    }

    @Test func addIsIdempotentAndIsFavoriteReflectsIt() {
        let s = store()
        s.load()
        s.add(makeStation("rb-1")); s.add(makeStation("rb-1"))
        #expect(s.favorites.count == 1)
        #expect(s.isFavorite("rb-1"))
        s.remove("rb-1")
        #expect(!s.isFavorite("rb-1"))
    }

    @Test func removingUnknownIdDoesNotCreateFile() {
        let s = store()
        s.load()
        s.remove("nope")
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func oldFileWithExtraFieldsStillLoads() throws {
        try Data(#"{ "stations": [ { "id": "a", "name": "A", "streams": [ { "url": "https://x/a", "unverified": true } ] } ], "knownCatalogIds": [ "a" ] }"#.utf8).write(to: url)
        #expect(store().load().map(\.id) == ["a"])
    }

    @Test func duplicateIdsInFileAreCollapsed() throws {
        try Data(#"{"stations":[{"id":"a","name":"A"},{"id":"a","name":"A2"},{"id":"b","name":"B"}]}"#.utf8).write(to: url)
        #expect(store().load().map(\.name) == ["A", "B"])
    }

    @Test func corruptFileStartsEmpty() throws {
        try Data("{ not json".utf8).write(to: url)
        #expect(store().load().isEmpty)
    }

    @Test func writesInWindowsCompatibleShape() throws {
        let s = store()
        s.load()
        s.add(makeStation("rb-1"))
        let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let stations = obj?["stations"] as? [[String: Any]]
        #expect(stations?.first?["id"] as? String == "rb-1")
        #expect((stations?.first?["streams"] as? [[String: Any]])?.first?["url"] as? String == "https://x/live")
    }
}
