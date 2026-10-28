import Foundation
import Network
import Observation

/// Tells when the device gets network access again, so `RadioPlayer` can retry right away.
@MainActor
@Observable
public final class NetworkMonitor {
    public private(set) var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var onBecameOnline: (@MainActor () -> Void)?

    public init() {}

    /// Starts watching; `onBecameOnline` runs each time the connection changes from lost to available.
    public func start(onBecameOnline: @escaping @MainActor () -> Void) {
        self.onBecameOnline = onBecameOnline
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.update(isOnline: online) }
        }
        monitor.start(queue: DispatchQueue(label: "AntenimYok.NetworkMonitor"))
    }

    public func stop() {
        monitor.cancel()
    }

    private func update(isOnline online: Bool) {
        let wasOnline = isOnline
        isOnline = online
        if online && !wasOnline { onBecameOnline?() }
    }
}
