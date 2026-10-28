import Foundation
import Testing
@testable import AntenimYokCore

@Suite struct StreamResolverTests {
    @Test func expandsPlsToFirstEntry() async throws {
        let transport = FakeTransport(json: "[playlist]\nFile1=https://real.example/stream\nFile2=https://other/x\n")
        let url = try await StreamResolver(transport: transport)
            .resolve(StationStream(url: "https://radio.example/live.pls"))
        #expect(url == URL(string: "https://real.example/stream"))
    }

    @Test(arguments: [
        ("https://radio.example/stream", StreamType.icecast),
        ("https://radio.example/playlist.m3u8", StreamType.hls),
        ("https://radio.example/odd.pls", StreamType.hls),
    ])
    func passesThroughDirectStreams(url: String, type: StreamType) async throws {
        let transport = FakeTransport(json: "")
        let resolved = try await StreamResolver(transport: transport).resolve(StationStream(url: url, type: type))
        #expect(resolved == URL(string: url))
        #expect(transport.recorded.isEmpty)
    }

    @Test func emptyPlaylistThrows() async {
        let transport = FakeTransport(json: "#EXTM3U\n")
        await #expect(throws: PlaylistError.self) {
            try await StreamResolver(transport: transport).resolve(StationStream(url: "https://r/x.m3u"))
        }
    }

    @Test func httpErrorThrows() async {
        let transport = FakeTransport(json: "", status: 404)
        await #expect(throws: HTTPError(statusCode: 404)) {
            try await StreamResolver(transport: transport).resolve(StationStream(url: "https://r/x.pls"))
        }
    }

    @Test func resolvesRelativeEntriesAgainstPlaylistUrl() async throws {
        let transport = FakeTransport(json: "backup/live\n")
        let url = try await StreamResolver(transport: transport).resolve(StationStream(url: "https://radio.example/lists/a.m3u"))
        #expect(url == URL(string: "https://radio.example/lists/backup/live"))
    }
}
