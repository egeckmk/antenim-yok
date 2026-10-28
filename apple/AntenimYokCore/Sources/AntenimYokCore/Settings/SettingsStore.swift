import Foundation
import Synchronization

/// Keeps `AppSettings` in a JSON file. Updates are written after a short delay
/// so dragging the volume slider does not hit the disk on every tick.
public final class SettingsStore: Sendable {
    public static var defaultURL: URL { AtomicFile.defaultURL(fileName: "settings.json") }

    private struct State {
        var current: AppSettings
        var pendingSave: Task<Void, Never>?
        var generation = 0
    }

    private let url: URL
    private let saveDelay: Duration
    private let sleeper: any Sleeper
    private let state: Mutex<State>

    public init(
        url: URL = SettingsStore.defaultURL,
        saveDelay: Duration = .milliseconds(500),
        sleeper: any Sleeper = TaskSleeper()
    ) {
        self.url = url
        self.saveDelay = saveDelay
        self.sleeper = sleeper
        var loaded = AppSettings()
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            loaded = decoded
        }
        state = Mutex(State(current: loaded))
    }

    public var current: AppSettings { state.withLock { $0.current } }

    public func update(_ change: (inout AppSettings) -> Void) {
        state.withLock { state in
            var next = state.current
            change(&next)
            guard next != state.current else { return }
            state.current = next
            state.pendingSave?.cancel()
            state.generation += 1
            let generation = state.generation
            let delay = saveDelay
            let sleeper = sleeper
            state.pendingSave = Task { [self] in
                do { try await sleeper.sleep(for: delay) } catch { return }
                self.saveIfCurrent(generation: generation)
            }
        }
    }

    /// Writes pending changes now (call when the app goes to the background or quits).
    public func flush() {
        let pending: Bool = state.withLock { state in
            guard let task = state.pendingSave else { return false }
            task.cancel()
            state.pendingSave = nil
            return true
        }
        if pending { write(current) }
    }

    private func saveIfCurrent(generation: Int) {
        let snapshot: AppSettings? = state.withLock { state in
            guard state.generation == generation else { return nil }
            state.pendingSave = nil
            return state.current
        }
        if let snapshot { write(snapshot) }
    }

    private func write(_ settings: AppSettings) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(settings) else { return }
        try? AtomicFile.write(data, to: url)
    }
}
