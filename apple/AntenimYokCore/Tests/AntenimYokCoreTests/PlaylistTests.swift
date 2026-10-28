import Foundation
import Testing
@testable import AntenimYokCore

@Suite struct PlaylistTests {
    let base = URL(string: "https://radio.example/lists/live.pls")!

    @Test(arguments: [
        ("https://x/live.pls", PlaylistFormat.pls),
        ("https://x/LIVE.M3U?token=1", PlaylistFormat.m3u),
    ])
    func detectsByExtension(url: String, expected: PlaylistFormat) {
        #expect(PlaylistParser.detectFormat(of: URL(string: url)!) == expected)
    }

    @Test(arguments: ["https://x/playlist.m3u8", "https://x/stream"])
    func nonPlaylistsAreNil(url: String) {
        #expect(PlaylistParser.detectFormat(of: URL(string: url)!) == nil)
    }

    @Test func plsReturnsFileEntriesInOrder() {
        let pls = "[playlist]\r\nNumberOfEntries=2\r\nFile1=http://a.example:8000/stream\r\nTitle1=Main\r\nFile2=https://b.example/stream\r\nVersion=2\r\n"
        #expect(PlaylistParser.parse(pls, format: .pls, baseURL: base) == [
            URL(string: "http://a.example:8000/stream")!, URL(string: "https://b.example/stream")!,
        ])
    }

    @Test func m3uSkipsCommentsAndResolvesRelative() {
        let m3u = "#EXTM3U\n#EXTINF:-1,Radio\nhttps://a.example/live\n\nbackup/live\n"
        #expect(PlaylistParser.parse(m3u, format: .m3u, baseURL: base) == [
            URL(string: "https://a.example/live")!, URL(string: "https://radio.example/lists/backup/live")!,
        ])
    }

    @Test func ignoresNonHttpEntries() {
        #expect(PlaylistParser.parse("file:///C:/x.mp3\nftp://x/y\n", format: .m3u, baseURL: base).isEmpty)
    }
}
