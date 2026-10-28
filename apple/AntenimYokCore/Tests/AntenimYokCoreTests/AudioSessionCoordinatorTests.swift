import Dispatch
import Foundation
import Synchronization
import Testing
@testable import AntenimYokCore

/// Records backend calls; a setActive call whose 1-based index is in `blocking` waits until `release()`.
final class RecordingBackend: AudioSessionBackend {
    enum Call: Equatable { case configure, setActive(Bool) }
    private struct State { var calls: [Call] = []; var onMain: [Bool] = []; var setActiveCount = 0 }
    private let state = Mutex(State())
    private let blocking: Set<Int>
    private let gate = DispatchSemaphore(value: 0)

    init(blocking: Set<Int> = []) { self.blocking = blocking }

    var calls: [Call] { state.withLock { $0.calls } }
    var anyOnMainThread: Bool { state.withLock { $0.onMain.contains(true) } }
    var setActiveCount: Int { state.withLock { $0.setActiveCount } }
    func release() { gate.signal() }

    func configureCategory() {
        state.withLock { $0.calls.append(.configure); $0.onMain.append(Thread.isMainThread) }
    }

    func setActive(_ active: Bool) {
        let index = state.withLock { s -> Int in
            s.calls.append(.setActive(active)); s.onMain.append(Thread.isMainThread); s.setActiveCount += 1
            return s.setActiveCount
        }
        if blocking.contains(index) { gate.wait() }
    }
}

@Suite struct AudioSessionCoordinatorTests {
    @Test func activateConfiguresCategoryFirstThenActivates() async {
        let backend = RecordingBackend()
        let c = AudioSessionCoordinator(backend: backend)
        await c.activate()
        #expect(backend.calls == [.configure, .setActive(true)])
        #expect(c.isActive)
    }

    @Test func activateReturnsOnlyAfterSessionIsActive() async {
        let backend = RecordingBackend(blocking: [1])
        let c = AudioSessionCoordinator(backend: backend)
        let done = Mutex(false)
        let task = Task { await c.activate(); done.withLock { $0 = true } }
        await until2 { backend.setActiveCount == 1 }
        try? await Task.sleep(for: .milliseconds(30))
        #expect(!done.withLock { $0 })
        backend.release()
        await task.value
        #expect(done.withLock { $0 })
        #expect(c.isActive)
    }

    @Test func repeatedSameStateDoesNotCallBackendAgain() async {
        let backend = RecordingBackend()
        let c = AudioSessionCoordinator(backend: backend)
        await c.activate()
        await c.activate()
        #expect(backend.setActiveCount == 1)
        c.deactivate()
        await until2 { !c.isActive }
        c.deactivate()
        try? await Task.sleep(for: .milliseconds(30))
        #expect(backend.calls == [.configure, .setActive(true), .setActive(false)])
    }

    @Test func categoryIsConfiguredOnlyOnce() async {
        let backend = RecordingBackend()
        let c = AudioSessionCoordinator(backend: backend)
        await c.activate()
        c.deactivate()
        await until2 { !c.isActive }
        await c.activate()
        #expect(backend.calls == [.configure, .setActive(true), .setActive(false), .setActive(true)])
    }

    @Test func deactivateAloneNeverConfiguresOrCallsBackend() async {
        let backend = RecordingBackend()
        let c = AudioSessionCoordinator(backend: backend)
        c.deactivate()
        try? await Task.sleep(for: .milliseconds(30))
        #expect(backend.calls.isEmpty)
        #expect(!c.isActive)
    }

    @Test func playStopPlayEndsActive_lateDeactivateDoesNotWin() async {
        let backend = RecordingBackend(blocking: [1])
        let c = AudioSessionCoordinator(backend: backend)
        let first = Task { await c.activate() }
        await until2 { backend.setActiveCount == 1 }   // first activation in flight
        c.deactivate()                                  // stop
        let second = Task { await c.activate() }        // play again
        try? await Task.sleep(for: .milliseconds(30))
        backend.release()
        await first.value
        await second.value
        #expect(c.isActive)
        #expect(backend.calls.last == .setActive(true))
        #expect(backend.calls == [.configure, .setActive(true)])  // coalesced: no needless off/on
    }

    @Test func stopDuringActiveSessionThenPlayReactivatesInOrder() async {
        let slow = RecordingBackend(blocking: [2])
        let c2 = AudioSessionCoordinator(backend: slow)
        await c2.activate()
        c2.deactivate()                                 // setActive(false) blocks
        await until2 { slow.setActiveCount == 2 }
        let again = Task { await c2.activate() }       // play while deactivation in flight
        slow.release()
        await again.value
        #expect(slow.calls == [.configure, .setActive(true), .setActive(false), .setActive(true)])
        #expect(c2.isActive)
    }

    @Test func finalStateIsLastRequestWhenStopWins() async {
        let backend = RecordingBackend(blocking: [1])
        let c = AudioSessionCoordinator(backend: backend)
        let play = Task { await c.activate() }
        await until2 { backend.setActiveCount == 1 }
        c.deactivate()
        backend.release()
        await play.value
        await until2 { backend.calls.last == .setActive(false) }
        #expect(!c.isActive)
        #expect(backend.calls == [.configure, .setActive(true), .setActive(false)])
    }

    @Test func backendIsNeverCalledOnMainThread() async {
        let backend = RecordingBackend()
        let c = AudioSessionCoordinator(backend: backend)
        await MainActor.run { }
        await c.activate()
        c.deactivate()
        await until2 { !c.isActive }
        await c.activate()
        #expect(!backend.anyOnMainThread)
    }

    @Test @MainActor func callingFromMainActorStillRunsBackendOffMain() async {
        let backend = RecordingBackend()
        let c = AudioSessionCoordinator(backend: backend)
        await c.activate()
        c.deactivate()
        await until2 { !c.isActive }
        #expect(!backend.anyOnMainThread)
    }
}

/// Polls until `condition` holds (max ~3 s).
func until2(_ condition: @Sendable () -> Bool) async {
    for _ in 0..<600 where !condition() {
        try? await Task.sleep(for: .milliseconds(5))
    }
}
