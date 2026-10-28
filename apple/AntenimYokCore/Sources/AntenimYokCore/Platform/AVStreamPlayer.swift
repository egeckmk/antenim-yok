import AVFoundation
import Foundation

/// `StreamPlayer` on top of `AVPlayer`: HLS and Icecast/SHOUTcast both play through `AVPlayerItem(url:)`.
/// On iOS it sets up the `.playback` audio session so audio continues in the background (needs `UIBackgroundModes=audio`).
@MainActor
public final class AVStreamPlayer: StreamPlayer {
    public var onEvent: (@MainActor (StreamPlayerEvent) -> Void)?

    public var volume: Double {
        get { Double(player.volume) }
        set { player.volume = Float(min(max(newValue, 0), 1)) }
    }

    public var isMuted: Bool {
        get { player.isMuted }
        set { player.isMuted = newValue }
    }

    private let player = AVPlayer()
    private var openWaiter: OpenWaiter?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var notificationTokens: [any NSObjectProtocol] = []
    private var isOpen = false
    private var hasPlayed = false
    private var isInterrupted = false

    public init() {
        player.automaticallyWaitsToMinimizeStalling = true
        #if os(iOS)
        observeAudioSession()
        #endif
    }

    public func open(url: URL, type: StreamType) async throws {
        teardown()
        activateAudioSession()

        let item = AVPlayerItem(url: url)
        let waiter = OpenWaiter()
        openWaiter = waiter

        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    waiter.continuation = continuation
                    statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                        let status = item.status
                        let error = item.error
                        Task { @MainActor in self?.itemStatusChanged(status, error: error, waiter: waiter) }
                    }
                    player.replaceCurrentItem(with: item)
                }
            } onCancel: {
                Task { @MainActor in waiter.finish(.failure(CancellationError())) }
            }
        } catch {
            if waiter === openWaiter { stop() }
            throw error
        }

        // Opened: start playing and watch the stream from now on.
        isOpen = true
        player.play()
        observePlayback(of: item)
    }

    public func stop() {
        teardown()
        player.pause()
        player.replaceCurrentItem(with: nil)
        deactivateAudioSession()
    }

    // MARK: - Opening

    private func itemStatusChanged(_ status: AVPlayerItem.Status, error: (any Error)?, waiter: OpenWaiter) {
        guard waiter === openWaiter else { return }
        switch status {
        case .readyToPlay:
            waiter.finish(.success(()))
        case .failed:
            waiter.finish(.failure(error ?? URLError(.cannotConnectToHost)))
        default:
            break
        }
    }

    // MARK: - Watching the open stream

    private func observePlayback(of item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor in self?.emit(.failed) }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor in self?.timeControlChanged(status) }
        }

        let center = NotificationCenter.default
        for name in [AVPlayerItem.failedToPlayToEndTimeNotification, AVPlayerItem.didPlayToEndTimeNotification] {
            notificationTokens.append(center.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.emit(.failed) }
            })
        }
        notificationTokens.append(
            center.addObserver(forName: AVPlayerItem.playbackStalledNotification, object: item, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.emit(.stalled) }
            })
    }

    private func timeControlChanged(_ status: AVPlayer.TimeControlStatus) {
        guard isOpen else { return }
        switch status {
        case .playing:
            hasPlayed = true
            emit(.resumed)
        case .waitingToPlayAtSpecifiedRate:
            if hasPlayed { emit(.stalled) }
        case .paused:
            // We never pause except in stop() (which tears down first), so the system did.
            if !isInterrupted { emit(.pausedBySystem) }
        @unknown default:
            break
        }
    }

    private func emit(_ event: StreamPlayerEvent) {
        guard isOpen else { return }
        onEvent?(event)
    }

    private func teardown() {
        openWaiter?.finish(.failure(CancellationError()))
        openWaiter = nil
        statusObservation = nil
        timeControlObservation = nil
        for token in notificationTokens { NotificationCenter.default.removeObserver(token) }
        notificationTokens = []
        isOpen = false
        hasPlayed = false
    }

    // MARK: - Audio session (iOS)

    private func activateAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        #endif
    }

    private func deactivateAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    #if os(iOS)
    private func observeAudioSession() {
        let center = NotificationCenter.default
        // A phone call or another app takes the audio: AVPlayer pauses itself; resume when the system says so.
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated {
                guard let self, let typeValue, let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
                let event: AudioInterruptionEvent? = switch type {
                case .began: .began
                case .ended:
                    .ended(shouldResume: optionsValue.map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false)
                @unknown default: nil
                }
                guard let event else { return }
                self.handleInterruption(event)
            }
        }
        // Headphones / AirPods / car removed: stop instead of continuing on the speaker.
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            let previous = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
            let outputs = previous?.outputs.map { Self.outputKind(of: $0.portType) } ?? []
            MainActor.assumeIsolated {
                guard let self, self.isOpen else { return }
                let reason = reasonValue.flatMap { AVAudioSession.RouteChangeReason(rawValue: $0) }.map(Self.routeReason) ?? .unknown
                if AudioRoutePolicy.shouldStop(reason: reason, previousOutputs: outputs) {
                    self.emit(.pausedBySystem)
                }
            }
        }
    }

    private func handleInterruption(_ event: AudioInterruptionEvent) {
        switch AudioInterruptionPolicy.action(for: event) {
        case .waitForEnd:
            isInterrupted = true
        case .resume:
            isInterrupted = false
            if isOpen {
                activateAudioSession()
                player.play()
            }
        case .stop:
            isInterrupted = false
            if isOpen { emit(.pausedBySystem) }
        }
    }

    private nonisolated static func outputKind(of port: AVAudioSession.Port) -> AudioOutputKind {
        switch port {
        case .builtInSpeaker: .builtInSpeaker
        case .builtInReceiver: .builtInReceiver
        case .headphones, .usbAudio, .headsetMic: .headphones
        case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP: .bluetooth
        case .airPlay: .airPlay
        case .carAudio: .car
        default: .other
        }
    }

    private nonisolated static func routeReason(_ reason: AVAudioSession.RouteChangeReason) -> AudioRouteChangeReason {
        switch reason {
        case .newDeviceAvailable: .newDeviceAvailable
        case .oldDeviceUnavailable: .oldDeviceUnavailable
        case .categoryChange: .categoryChange
        case .override: .override
        case .wakeFromSleep: .wakeFromSleep
        case .noSuitableRouteForCategory: .noSuitableRouteForCategory
        case .routeConfigurationChange: .routeConfigurationChange
        default: .unknown
        }
    }
    #endif
}

@MainActor
private final class OpenWaiter {
    var continuation: CheckedContinuation<Void, any Error>?

    func finish(_ result: Result<Void, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
