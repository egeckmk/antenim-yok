import Foundation
import Synchronization
import Testing
@testable import AntenimYokCore

@Suite struct IcyParsingTests {
    @Test(arguments: [
        ("StreamTitle='Tarkan - Şımarık';StreamUrl='';", "Tarkan - Şımarık"),
        ("StreamTitle='It''s fine';", "It''s fine"),
    ])
    func parsesTitle(block: String, expected: String) {
        #expect(IcyMetadataReader.parseStreamTitle(Data(block.utf8)) == expected)
    }

    @Test(arguments: ["StreamTitle='';", "StreamTitle=' - ';", "StreamUrl='x';"])
    func blankOrMissingIsNil(block: String) {
        #expect(IcyMetadataReader.parseStreamTitle(Data(block.utf8)) == nil)
    }

    @Test func fallsBackToTurkishCodePage() throws {
        let data = try #require("StreamTitle='Şımarık';".data(using: .windowsCP1254))
        #expect(IcyMetadataReader.parseStreamTitle(data) == "Şımarık")
    }

    @Test func ignoresNulPadding() {
        var data = Data("StreamTitle='A';".utf8)
        data.append(contentsOf: [UInt8](repeating: 0, count: 8))
        #expect(IcyMetadataReader.parseStreamTitle(data) == "A")
    }

    static func interleaved(metaInt: Int, metas: [String]) -> Data {
        var body = Data()
        for meta in metas {
            body.append(Data(count: metaInt))
            let bytes = Data(meta.utf8)
            let blocks = (bytes.count + 15) / 16
            body.append(UInt8(blocks))
            body.append(bytes)
            body.append(Data(count: blocks * 16 - bytes.count))
        }
        return body
    }

    @Test func blockParserYieldsTitlesAcrossArbitraryChunking() {
        let body = Self.interleaved(metaInt: 8, metas: ["StreamTitle='A';", "", "StreamTitle='B';"])
        var parser = IcyBlockParser(metaInterval: 8)
        var titles: [String] = []
        for byte in body { titles += parser.feed(Data([byte])) }
        #expect(titles == ["A", "B"])

        var whole = IcyBlockParser(metaInterval: 8)
        #expect(whole.feed(body) == ["A", "B"])
    }

    @Test func readerSkipsRepeatsAndSendsIcyHeader() async throws {
        let body = Self.interleaved(metaInt: 8, metas: ["StreamTitle='A';", "", "StreamTitle='A';", "StreamTitle='B';"])
        let transport = FakeTransport(data: body, headers: ["icy-metaint": "8"])
        var titles: [String] = []
        for try await t in IcyMetadataReader(transport: transport).titles(for: URL(string: "https://radio/live")!) {
            titles.append(t)
        }
        #expect(titles == ["A", "B"])
        #expect(transport.recorded.first?.value(forHTTPHeaderField: "Icy-MetaData") == "1")
    }

    @Test func readerWithoutMetaIntYieldsNothing() async throws {
        let transport = FakeTransport(data: Data([1, 2, 3]))
        var titles: [String] = []
        for try await t in IcyMetadataReader(transport: transport).titles(for: URL(string: "https://radio/live")!) {
            titles.append(t)
        }
        #expect(titles.isEmpty)
    }
}

final class ScriptedReader: IcyMetadataReading {
    private struct State { var calls = 0; var lastURL: URL? }
    private let state = Mutex(State())
    private let titlesPerCall: [[String]]
    private let failFirstCall: Bool

    init(_ titles: [String], failFirstCall: Bool = false) {
        titlesPerCall = [titles]
        self.failFirstCall = failFirstCall
    }

    var calls: Int { state.withLock { $0.calls } }
    var lastURL: URL? { state.withLock { $0.lastURL } }

    func titles(for url: URL) -> AsyncThrowingStream<String, any Error> {
        let call = state.withLock { s -> Int in s.calls += 1; s.lastURL = url; return s.calls }
        let titles = titlesPerCall[0]
        let fail = failFirstCall && call == 1
        return AsyncThrowingStream { c in
            if fail { c.finish(throwing: URLError(.networkConnectionLost)); return }
            for t in titles { c.yield(t) }
            // never finishes: the connection stays open
        }
    }
}

@MainActor
@Suite struct SongTitleMonitorTests {
    func make(reader: ScriptedReader, retryDelay: Duration = .seconds(11))
        -> (RadioPlayer, SongTitleMonitor, ManualSleeper) {
        let radio = RadioPlayer(player: FakeStreamPlayer(), resolver: PassThroughResolver(), sleeper: ManualSleeper())
        let retry = ManualSleeper()
        return (radio, SongTitleMonitor(player: radio, reader: reader, sleeper: retry, retryDelay: retryDelay), retry)
    }

    @Test func readsOnlyWhileIcecastPlays() async {
        let reader = ScriptedReader(["Song 1"])
        let (radio, monitor, _) = make(reader: reader)

        await radio.play(station("a", "https://a/live"))
        await until { monitor.currentTitle == "Song 1" }
        #expect(monitor.currentTitle == "Song 1")
        #expect(reader.lastURL == URL(string: "https://a/live"))

        radio.stop()
        #expect(monitor.currentTitle == nil)

        let hls = Station(id: "h", name: "H", streams: [StationStream(url: "https://b/p.m3u8", type: .hls)])
        await radio.play(hls)
        try? await Task.sleep(for: .milliseconds(30))
        #expect(monitor.currentTitle == nil)
        #expect(reader.calls == 1)
    }

    @Test func disabledOpensNoConnection() async {
        let reader = ScriptedReader(["Song 1"])
        let (radio, monitor, _) = make(reader: reader)
        monitor.isEnabled = false
        await radio.play(station("a", "https://a/live"))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(reader.calls == 0)
        #expect(monitor.currentTitle == nil)
    }

    @Test func disablingWhilePlayingClearsTitle() async {
        let reader = ScriptedReader(["Song 1"])
        let (radio, monitor, _) = make(reader: reader)
        await radio.play(station("a", "https://a/live"))
        await until { monitor.currentTitle != nil }
        monitor.isEnabled = false
        #expect(monitor.currentTitle == nil)
    }

    @Test func retriesAfterDroppedMetadataConnection() async {
        let reader = ScriptedReader(["Song 1"], failFirstCall: true)
        let (radio, monitor, retry) = make(reader: reader, retryDelay: .seconds(11))
        await radio.play(station("a", "https://a/live"))
        await until { retry.waiting(.seconds(11)) == 1 }
        #expect(monitor.currentTitle == nil)
        retry.fire(.seconds(11))
        await until { monitor.currentTitle == "Song 1" }
        #expect(monitor.currentTitle == "Song 1")
        #expect(reader.calls == 2)
    }
}
