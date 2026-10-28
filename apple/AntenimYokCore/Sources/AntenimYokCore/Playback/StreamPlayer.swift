import Foundation

/// Something the platform player reports after a stream has been opened.
public enum StreamPlayerEvent: Sendable, Equatable {
    /// The stream failed or ended (server closed it).
    case failed
    /// Audio ran dry (buffering). `RadioPlayer` treats a stall that lasts `stallTimeout` as a drop.
    case stalled
    /// Audio flows again after a stall.
    case resumed
    /// The system paused playback on purpose (headphones unplugged, interruption that must not resume).
    case pausedBySystem
}

/// Platform audio player (Apple: `AVStreamPlayer` around `AVPlayer`). Behind a protocol so playback logic is testable.
@MainActor
public protocol StreamPlayer: AnyObject {
    /// Starts playing `url`; returns once the media has opened, throws if it fails.
    /// Must honor task cancellation (throw `CancellationError`) and leave nothing playing when it throws.
    func open(url: URL, type: StreamType) async throws

    func stop()

    /// 0.0 - 1.0
    var volume: Double { get set }
    var isMuted: Bool { get set }

    /// Events about the stream that is currently open. Not raised after `stop()` or while opening.
    var onEvent: (@MainActor (StreamPlayerEvent) -> Void)? { get set }
}
