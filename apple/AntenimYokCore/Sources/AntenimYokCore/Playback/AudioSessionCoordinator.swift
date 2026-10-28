import Foundation
import Synchronization

/// The platform audio session (iOS `AVAudioSession`). Both calls block, so the coordinator only
/// ever calls them off the main thread, one at a time.
public protocol AudioSessionBackend: Sendable {
    /// Sets the playback category; called once, before the first activation.
    func configureCategory()
    func setActive(_ active: Bool)
}

/// Activates / deactivates the audio session without ever blocking the main thread
/// (`AVAudioSession.setActive` can stall for a long time), in a safe order:
/// requests are applied one at a time on a background task and coalesced, so the session ends in the state
/// of the *last* request - a quick play / stop / play never lets a late deactivation kill the new playback.
public final class AudioSessionCoordinator: Sendable {
    private struct State {
        var desired = false
        var applied = false
        var drain: Task<Void, Never>?
    }

    private let state = Mutex(State())
    private let worker: Worker

    public init(backend: any AudioSessionBackend) {
        worker = Worker(backend: backend)
    }

    /// Returns once the session is active (or the backend finished trying), so playback can start.
    public func activate() async {
        await request(true).value
    }

    /// Fire and forget: `stop()` must not wait for the session.
    public func deactivate() {
        _ = request(false)
    }

    /// What the session is now (after the work done so far); for tests.
    public var isActive: Bool { state.withLock { $0.applied } }

    private func request(_ active: Bool) -> Task<Void, Never> {
        state.withLock { state in
            state.desired = active
            if let drain = state.drain { return drain }
            let drain = Task { await self.drain() }
            state.drain = drain
            return drain
        }
    }

    private func drain() async {
        while true {
            let target: Bool? = state.withLock { state in
                if state.applied == state.desired {
                    state.drain = nil
                    return nil
                }
                return state.desired
            }
            guard let target else { return }
            await worker.apply(target)
            state.withLock { $0.applied = target }
        }
    }

    /// Runs the backend calls on the actor's own executor (never the main thread), strictly one after another.
    private actor Worker {
        private let backend: any AudioSessionBackend
        private var configured = false

        init(backend: any AudioSessionBackend) {
            self.backend = backend
        }

        func apply(_ active: Bool) {
            if active, !configured {
                backend.configureCategory()
                configured = true
            }
            backend.setActive(active)
        }
    }
}
