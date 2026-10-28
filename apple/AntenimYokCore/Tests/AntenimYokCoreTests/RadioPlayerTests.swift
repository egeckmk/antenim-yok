import Foundation
import Testing
@testable import AntenimYokCore

@MainActor
final class FakeStreamPlayer: StreamPlayer {
    var failing: Set<String> = []
    var hanging: Set<String> = []
    var opened: [String] = []
    var stopCount = 0
    var volume: Double = 0
    var isMuted = false
    var onEvent: (@MainActor (StreamPlayerEvent) -> Void)?

    func open(url: URL, type: StreamType) async throws {
        opened.append(url.absoluteString)
        if hanging.contains(url.absoluteString) { try await Task.sleep(for: .seconds(3600)) }
        if failing.contains(url.absoluteString) { throw URLError(.cannotConnectToHost) }
    }

    func stop() { stopCount += 1 }
    func raise(_ event: StreamPlayerEvent) { onEvent?(event) }
}

struct PassThroughResolver: StreamResolving {
    func resolve(_ stream: StationStream) async throws -> URL { URL(string: stream.url)! }
}

@MainActor
struct Rig {
    let fake = FakeStreamPlayer()
    let sleeper = ManualSleeper()
    let radio: RadioPlayer
    var states: StateLog

    @MainActor final class StateLog { var list: [PlaybackState] = [] }

    init(openTimeout: Duration = .seconds(7), stallTimeout: Duration = .seconds(9),
         delays: [Duration] = [.seconds(3)], volume: Double = 0.5) {
        radio = RadioPlayer(player: fake, resolver: PassThroughResolver(), sleeper: sleeper,
                            openTimeout: openTimeout, stallTimeout: stallTimeout,
                            reconnectDelays: delays, volume: volume)
        states = StateLog()
        let log = states
        let r = radio
        radio.observeState { log.list.append(r.state) }
    }
}

func station(_ id: String = "test", _ urls: String...) -> Station {
    Station(id: id, name: "\(id) FM", streams: urls.map { StationStream(url: $0) })
}

@MainActor
@Suite struct RadioPlayerTests {
    @Test func firstStreamWorksPlays() async {
        let rig = Rig()
        await rig.radio.play(station("t", "https://a/1", "https://a/2"))
        #expect(rig.radio.state == .playing)
        #expect(rig.radio.currentStream?.url == "https://a/1")
        #expect(rig.radio.currentURL == URL(string: "https://a/1"))
        #expect(rig.states.list == [.connecting, .playing])
        #expect(rig.fake.opened == ["https://a/1"])
        #expect(rig.radio.isActive)
    }

    @Test func firstStreamFailsFallsBackToNext() async {
        let rig = Rig()
        rig.fake.failing = ["https://a/1"]
        await rig.radio.play(station("t", "https://a/1", "https://a/2"))
        #expect(rig.radio.state == .playing)
        #expect(rig.radio.currentStream?.url == "https://a/2")
        #expect(rig.fake.opened == ["https://a/1", "https://a/2"])
    }

    @Test func firstStreamHangsTimesOutAndFallsBack() async {
        let rig = Rig(openTimeout: .seconds(7))
        rig.fake.hanging = ["https://a/1"]
        let play = Task { await rig.radio.play(station("t", "https://a/1", "https://a/2")) }
        await until { rig.sleeper.waiting(.seconds(7)) == 1 }
        rig.sleeper.fire(.seconds(7))
        await play.value
        #expect(rig.radio.state == .playing)
        #expect(rig.radio.currentStream?.url == "https://a/2")
    }

    @Test func allStreamsFailReportsError() async {
        let rig = Rig()
        rig.fake.failing = ["https://a/1", "https://a/2"]
        await rig.radio.play(station("t", "https://a/1", "https://a/2"))
        #expect(rig.radio.state == .error)
        #expect(rig.radio.currentStation?.name == "t FM")
        #expect(rig.fake.stopCount > 0)
        #expect(!rig.radio.isActive)
    }

    @Test func stationWithoutStreamsReportsError() async {
        let rig = Rig()
        await rig.radio.play(Station(id: "e", name: "Empty"))
        #expect(rig.radio.state == .error)
    }

    @Test func supersededPlayDoesNotOverwriteState() async {
        let rig = Rig()
        rig.fake.hanging = ["https://a/1"]
        let first = Task { await rig.radio.play(station("a", "https://a/1")) }
        await until { rig.fake.opened.count == 1 }
        await rig.radio.play(station("b", "https://b/1"))
        await first.value
        #expect(rig.radio.state == .playing)
        #expect(rig.radio.currentStation?.id == "b")
    }

    @Test func stopWhileConnectingEndsStopped() async {
        let rig = Rig()
        rig.fake.hanging = ["https://a/1"]
        let play = Task { await rig.radio.play(station("t", "https://a/1", "https://a/2")) }
        await until { rig.fake.opened.count == 1 }
        rig.radio.stop()
        await play.value
        #expect(rig.radio.state == .stopped)
        #expect(rig.fake.opened == ["https://a/1"])
    }

    @Test func failureWhilePlayingReconnectsAndPlaysAgain() async {
        let rig = Rig(delays: [.seconds(3)])
        await rig.radio.play(station("t", "https://a/1"))
        rig.fake.raise(.failed)
        #expect(rig.radio.state == .reconnecting)
        await until { rig.sleeper.waiting(.seconds(3)) == 1 }
        rig.sleeper.fire(.seconds(3))
        await until { rig.radio.state == .playing }
        #expect(rig.radio.state == .playing)
        #expect(rig.fake.opened == ["https://a/1", "https://a/1"])
    }

    @Test func reconnectBacksOffThroughDelaysThenErrors() async {
        let rig = Rig(delays: [.seconds(3), .seconds(4)])
        await rig.radio.play(station("t", "https://a/1"))
        rig.fake.failing = ["https://a/1"]
        rig.fake.raise(.failed)
        await until { rig.sleeper.waiting(.seconds(3)) == 1 }
        rig.sleeper.fire(.seconds(3))
        await until { rig.sleeper.waiting(.seconds(4)) == 1 }
        #expect(rig.radio.state == .reconnecting)
        rig.sleeper.fire(.seconds(4))
        await until { rig.radio.state == .error }
        #expect(rig.radio.state == .error)
        #expect(rig.fake.opened.count == 3) // initial + 2 attempts
    }

    @Test func defaultReconnectDelaysAreBoundedByFiveMinutes() {
        let seconds = RadioPlayer.defaultReconnectDelays.map { $0.components.seconds }
        #expect(seconds.first == 1)
        #expect(seconds.max() == 30)
        #expect(seconds.reduce(0, +) <= 300)
        #expect(RadioPlayer.defaultOpenTimeout == .seconds(10))
        #expect(RadioPlayer.defaultStallTimeout == .seconds(15))
    }

    @Test func networkAvailableSkipsWait() async {
        let rig = Rig(delays: [.seconds(3600)])
        await rig.radio.play(station("t", "https://a/1"))
        rig.fake.raise(.failed)
        await until { rig.sleeper.waiting(.seconds(3600)) == 1 }
        rig.radio.notifyNetworkAvailable()
        await until { rig.radio.state == .playing }
        #expect(rig.radio.state == .playing)
        #expect(rig.fake.opened.count == 2)
    }

    @Test func stopWhileReconnectingEndsStopped() async {
        let rig = Rig(delays: [.seconds(3)])
        await rig.radio.play(station("t", "https://a/1"))
        rig.fake.raise(.failed)
        await until { rig.sleeper.waiting(.seconds(3)) == 1 }
        rig.radio.stop()
        rig.sleeper.fire(.seconds(3))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(rig.radio.state == .stopped)
        #expect(rig.fake.opened.count == 1)
    }

    @Test func eventsWhenNotPlayingAreIgnored() async {
        let rig = Rig()
        await rig.radio.play(station("t", "https://a/1"))
        rig.radio.stop()
        rig.fake.raise(.failed)
        rig.fake.raise(.stalled)
        #expect(rig.radio.state == .stopped)
        #expect(rig.sleeper.waiting(.seconds(9)) == 0)
    }

    @Test func stallLongerThanTimeoutCountsAsDrop() async {
        let rig = Rig(stallTimeout: .seconds(9), delays: [.seconds(3)])
        await rig.radio.play(station("t", "https://a/1"))
        rig.fake.raise(.stalled)
        await until { rig.sleeper.waiting(.seconds(9)) == 1 }
        #expect(rig.radio.state == .playing)
        rig.sleeper.fire(.seconds(9))
        await until { rig.radio.state == .reconnecting }
        #expect(rig.radio.state == .reconnecting)
    }

    @Test func resumedCancelsStallTimer() async {
        let rig = Rig(stallTimeout: .seconds(9))
        await rig.radio.play(station("t", "https://a/1"))
        rig.fake.raise(.stalled)
        await until { rig.sleeper.waiting(.seconds(9)) == 1 }
        rig.fake.raise(.resumed)
        await until { rig.sleeper.waiting(.seconds(9)) == 0 }
        rig.sleeper.fire(.seconds(9))
        try? await Task.sleep(for: .milliseconds(30))
        #expect(rig.radio.state == .playing)
    }

    @Test func pausedBySystemStops() async {
        let rig = Rig()
        await rig.radio.play(station("t", "https://a/1"))
        rig.fake.raise(.pausedBySystem)
        #expect(rig.radio.state == .stopped)
    }

    @Test func volumeIsClampedAndForwarded() {
        let rig = Rig(volume: 0.3)
        #expect(rig.fake.volume == 0.3)
        rig.radio.volume = 0.7
        #expect(rig.fake.volume == 0.7)
        rig.radio.volume = 1.5
        #expect(rig.radio.volume == 1)
        #expect(rig.fake.volume == 1)
        rig.radio.volume = -1
        #expect(rig.fake.volume == 0)
        rig.radio.isMuted = true
        #expect(rig.fake.isMuted)
    }
}
