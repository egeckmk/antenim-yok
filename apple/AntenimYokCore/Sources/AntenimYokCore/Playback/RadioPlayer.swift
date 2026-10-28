import Foundation
import Observation

public enum PlaybackState: Sendable, Equatable {
    case stopped
    case connecting
    case playing
    /// A playing stream dropped; waiting to retry.
    case reconnecting
    case error
}

/// Plays a station by trying its streams in priority order, falling back to the next one
/// when a stream fails or does not open within `openTimeout`.
/// If a playing stream drops (or stalls for `stallTimeout`), it keeps reconnecting with backoff (`reconnectDelays`).
@MainActor
@Observable
public final class RadioPlayer {
    public static let defaultOpenTimeout: Duration = .seconds(10)
    public static let defaultStallTimeout: Duration = .seconds(15)

    /// ~5 minutes in total before giving up.
    public static let defaultReconnectDelays: [Duration] = [
        .seconds(1), .seconds(2), .seconds(5), .seconds(10),
        .seconds(20), .seconds(30), .seconds(30), .seconds(30),
        .seconds(30), .seconds(30), .seconds(30), .seconds(30),
    ]

    public private(set) var state: PlaybackState = .stopped
    public private(set) var currentStation: Station?
    public private(set) var currentStream: StationStream?
    /// The URL actually playing (after playlist resolution); nil unless `state == .playing`.
    public private(set) var currentURL: URL?

    /// 0.0 - 1.0
    public var volume: Double {
        get { storedVolume }
        set {
            storedVolume = min(max(newValue, 0), 1)
            player.volume = storedVolume
        }
    }

    public var isMuted: Bool {
        get { storedIsMuted }
        set {
            storedIsMuted = newValue
            player.isMuted = newValue
        }
    }

    // Backing storage: a didSet that re-assigns an @Observable property recurses, so volume is clamped in a setter.
    private var storedVolume: Double
    private var storedIsMuted: Bool

    public let openTimeout: Duration
    public let stallTimeout: Duration
    /// Wait before each reconnect attempt; after the last one the player gives up with `.error`.
    public let reconnectDelays: [Duration]

    @ObservationIgnored private let player: any StreamPlayer
    @ObservationIgnored private let resolver: any StreamResolving
    @ObservationIgnored private let sleeper: any Sleeper
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var attemptTask: Task<Void, Never>?
    @ObservationIgnored private var stallTask: Task<Void, Never>?
    @ObservationIgnored private var wakeReconnectWait: (@MainActor () -> Void)?
    @ObservationIgnored private var waitToken = 0
    @ObservationIgnored private var observers: [@MainActor () -> Void] = []

    public init(
        player: any StreamPlayer,
        resolver: any StreamResolving,
        sleeper: any Sleeper = TaskSleeper(),
        openTimeout: Duration = RadioPlayer.defaultOpenTimeout,
        stallTimeout: Duration = RadioPlayer.defaultStallTimeout,
        reconnectDelays: [Duration] = RadioPlayer.defaultReconnectDelays,
        volume: Double = 0.5,
        isMuted: Bool = false
    ) {
        self.player = player
        self.resolver = resolver
        self.sleeper = sleeper
        self.openTimeout = openTimeout
        self.stallTimeout = stallTimeout
        self.reconnectDelays = reconnectDelays
        self.storedVolume = min(max(volume, 0), 1)
        self.storedIsMuted = isMuted
        player.volume = storedVolume
        player.isMuted = isMuted
        player.onEvent = { [weak self] event in self?.handle(event) }
    }

    /// Connecting, playing or reconnecting - i.e. "stop" is the meaningful action.
    public var isActive: Bool {
        state == .connecting || state == .playing || state == .reconnecting
    }

    /// Called after every state change (also from several places, e.g. the song title monitor and system integration).
    public func observeState(_ handler: @escaping @MainActor () -> Void) {
        observers.append(handler)
    }

    /// Plays `station`; returns when it is playing, failed, or was superseded by `play`/`stop`.
    public func play(_ station: Station) async {
        let gen = beginOperation()
        setState(.connecting, station: station)
        let task = Task { await self.connect(station, generation: gen) }
        attemptTask = task
        await task.value
    }

    public func stop() {
        _ = beginOperation()
        player.stop()
        setState(.stopped, station: currentStation)
    }

    /// Call when the network comes back: a pending reconnect retries right away.
    public func notifyNetworkAvailable() {
        wakeReconnectWait?()
    }

    // MARK: - Connecting

    private func connect(_ station: Station, generation gen: Int) async {
        if await tryStreams(of: station, generation: gen) { return }
        guard gen == generation else { return } // Superseded by another play or stop.
        player.stop()
        setState(.error, station: station)
    }

    /// Tries each stream in order; on success sets `.playing` and returns true.
    private func tryStreams(of station: Station, generation gen: Int) async -> Bool {
        for stream in station.streams {
            guard gen == generation else { return false }
            do {
                let player = player, resolver = resolver
                let url = try await Self.race(timeout: openTimeout, sleeper: sleeper) {
                    let url = try await resolver.resolve(stream)
                    try await player.open(url: url, type: stream.type)
                    return url
                }
                guard gen == generation else { return false }
                setState(.playing, station: station, stream: stream, url: url)
                return true
            } catch {
                guard gen == generation else { return false }
                player.stop()
            }
        }
        return false
    }

    private func reconnect(_ station: Station, generation gen: Int) async {
        for delay in reconnectDelays {
            guard gen == generation else { return }
            setState(.reconnecting, station: station)
            await waitBeforeRetry(delay)
            guard gen == generation else { return }
            if await tryStreams(of: station, generation: gen) { return }
        }
        guard gen == generation else { return }
        player.stop()
        setState(.error, station: station)
    }

    /// Waits `delay`, or until the network comes back / the operation is superseded.
    private func waitBeforeRetry(_ delay: Duration) async {
        let sleeper = sleeper
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let once = Once(continuation)
            let timer = Task { @MainActor in
                try? await sleeper.sleep(for: delay)
                once.fire()
            }
            waitToken += 1
            let token = waitToken
            once.onFire = { [weak self] in
                timer.cancel()
                // Only clear our own wake-up; a newer wait may have replaced it already.
                if self?.waitToken == token { self?.wakeReconnectWait = nil }
            }
            wakeReconnectWait = { once.fire() }
        }
    }

    // MARK: - Player events

    private func handle(_ event: StreamPlayerEvent) {
        guard state == .playing, let station = currentStation else { return }
        switch event {
        case .failed:
            beginReconnect(station)
        case .stalled:
            guard stallTask == nil else { return }
            let gen = generation, sleeper = sleeper, timeout = stallTimeout
            stallTask = Task {
                do { try await sleeper.sleep(for: timeout) } catch { return }
                guard gen == self.generation, self.state == .playing else { return }
                self.beginReconnect(station)
            }
        case .resumed:
            stallTask?.cancel()
            stallTask = nil
        case .pausedBySystem:
            stop()
        }
    }

    private func beginReconnect(_ station: Station) {
        let gen = beginOperation()
        player.stop()
        setState(.reconnecting, station: station)
        attemptTask = Task { await self.reconnect(station, generation: gen) }
    }

    // MARK: - State

    /// Invalidates whatever is in flight (connect, reconnect, stall timer) and returns the new generation.
    private func beginOperation() -> Int {
        generation += 1
        attemptTask?.cancel()
        attemptTask = nil
        stallTask?.cancel()
        stallTask = nil
        wakeReconnectWait?()
        return generation
    }

    private func setState(_ state: PlaybackState, station: Station?, stream: StationStream? = nil, url: URL? = nil) {
        currentStation = station
        currentStream = stream
        currentURL = url
        self.state = state
        for observer in observers { observer() }
    }

    // MARK: - Helpers

    private struct TimedOut: Error {}

    /// Runs `operation`, failing with a timeout after `timeout`. Does not wait for an operation that ignores cancellation.
    private static func race<T: Sendable>(
        timeout: Duration,
        sleeper: any Sleeper,
        operation: @escaping @MainActor @Sendable () async throws -> T
    ) async throws -> T {
        let box = RaceBox<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
                box.continuation = continuation
                box.operationTask = Task { @MainActor in
                    do { box.finish(.success(try await operation())) } catch { box.finish(.failure(error)) }
                }
                box.timerTask = Task { @MainActor in
                    do { try await sleeper.sleep(for: timeout) } catch { return }
                    box.finish(.failure(TimedOut()))
                }
            }
        } onCancel: {
            Task { @MainActor in box.finish(.failure(CancellationError())) }
        }
    }
}

@MainActor
private final class RaceBox<T: Sendable> {
    var continuation: CheckedContinuation<T, any Error>?
    var operationTask: Task<Void, Never>?
    var timerTask: Task<Void, Never>?

    func finish(_ result: Result<T, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        operationTask?.cancel()
        timerTask?.cancel()
        continuation.resume(with: result)
    }
}

@MainActor
private final class Once {
    private var continuation: CheckedContinuation<Void, Never>?
    var onFire: (@MainActor () -> Void)?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func fire() {
        guard let continuation else { return }
        self.continuation = nil
        onFire?()
        continuation.resume()
    }
}
