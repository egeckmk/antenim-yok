import Testing
@testable import AntenimYokCore

@Suite struct FavoriteNavigationTests {
    let favs = ["a", "b", "c"].map { Station(id: $0, name: $0.uppercased()) }

    @Test func emptyListIsNil() {
        #expect(FavoriteNavigation.adjacent(in: [], currentId: "a", offset: 1) == nil)
        #expect(FavoriteNavigation.adjacent(in: [], currentId: nil, offset: -1) == nil)
    }

    @Test(arguments: [("a", 1, "b"), ("b", 1, "c"), ("c", 1, "a"), ("a", -1, "c"), ("b", -1, "a"),
                      ("a", 4, "b"), ("a", -4, "c"), ("b", 0, "b"), ("a", 3, "a"), ("a", -300, "a")])
    func wrapsAround(current: String, offset: Int, expected: String) {
        #expect(FavoriteNavigation.adjacent(in: favs, currentId: current, offset: offset)?.id == expected)
    }

    @Test func unknownOrNilCurrentReturnsFirst() {
        #expect(FavoriteNavigation.adjacent(in: favs, currentId: nil, offset: 1)?.id == "a")
        #expect(FavoriteNavigation.adjacent(in: favs, currentId: "zzz", offset: -1)?.id == "a")
    }

    @Test func singleFavoriteReturnsItself() {
        let one = [favs[1]]
        #expect(FavoriteNavigation.adjacent(in: one, currentId: "b", offset: 1)?.id == "b")
        #expect(FavoriteNavigation.adjacent(in: one, currentId: "b", offset: -1)?.id == "b")
    }
}

@Suite struct NowPlayingDescriptionTests {
    let station = Station(id: "x", name: "Kafa Radyo")

    @Test func songTitleWinsWhilePlaying() {
        let d = NowPlayingDescription.make(station: station, state: .playing, songTitle: "  Tarkan - Şımarık \n")
        #expect(d == NowPlayingDescription(title: "Tarkan - Şımarık", subtitle: "Kafa Radyo"))
    }

    @Test(arguments: [nil, "", "   ", "\n"])
    func blankSongFallsBackToStation(song: String?) {
        let d = NowPlayingDescription.make(station: station, state: .playing, songTitle: song)
        #expect(d == NowPlayingDescription(title: "Kafa Radyo", subtitle: nil))
    }

    @Test(arguments: [
        (PlaybackState.connecting, "Bağlanıyor…"),
        (.reconnecting, "Yeniden bağlanılıyor…"),
        (.error, "Yayına ulaşılamadı"),
    ])
    func statusShownAndStaleSongIgnored(state: PlaybackState, status: String) {
        let d = NowPlayingDescription.make(station: station, state: state, songTitle: "Old Song")
        #expect(d == NowPlayingDescription(title: "Kafa Radyo", subtitle: status))
    }

    @Test func stoppedShowsPlainStation() {
        let d = NowPlayingDescription.make(station: station, state: .stopped, songTitle: "Old Song")
        #expect(d == NowPlayingDescription(title: "Kafa Radyo", subtitle: nil))
    }
}
