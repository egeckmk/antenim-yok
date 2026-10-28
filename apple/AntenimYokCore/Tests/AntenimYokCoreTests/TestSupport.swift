import Foundation
import Synchronization
@testable import AntenimYokCore

func makeTempDirectory() -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("AntenimYokTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

func makeStation(_ id: String, name: String? = nil, url: String = "https://x/live") -> Station {
    Station(id: id, name: name ?? id.uppercased(), streams: [StationStream(url: url)])
}

/// Fake transport: serves a fixed body for `data(for:)` and records requests.
final class FakeTransport: HTTPTransport {
    private let requests = Mutex<[URLRequest]>([])
    private let body: Data
    private let status: Int
    private let headers: [String: String]

    init(json: String, status: Int = 200, headers: [String: String] = [:]) {
        body = Data(json.utf8)
        self.status = status
        self.headers = headers
    }

    init(data: Data, status: Int = 200, headers: [String: String] = [:]) {
        body = data
        self.status = status
        self.headers = headers
    }

    var recorded: [URLRequest] { requests.withLock { $0 } }

    func data(for request: URLRequest) async throws -> HTTPResponseData {
        requests.withLock { $0.append(request) }
        return HTTPResponseData(statusCode: status, headers: headers, finalURL: request.url, data: body)
    }

    func stream(for request: URLRequest) async throws -> HTTPByteStream {
        requests.withLock { $0.append(request) }
        let body = body
        return HTTPByteStream(statusCode: status, headers: headers, finalURL: request.url, chunks: AsyncThrowingStream { c in
            c.yield(body)
            c.finish()
        })
    }
}

/// Sleeper whose sleeps end only when a test fires them, so timeouts and backoff are deterministic.
final class ManualSleeper: Sleeper {
    private struct Entry {
        var id: Int
        var duration: Duration
        var continuation: CheckedContinuation<Void, any Error>
    }
    private struct State {
        var nextId = 0
        var entries: [Entry] = []
        var cancelled: Set<Int> = []
    }
    private let state = Mutex(State())

    func sleep(for duration: Duration) async throws {
        let id = state.withLock { s -> Int in s.nextId += 1; return s.nextId }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in
                let cancelledAlready = state.withLock { s -> Bool in
                    if s.cancelled.remove(id) != nil { return true }
                    s.entries.append(Entry(id: id, duration: duration, continuation: c))
                    return false
                }
                if cancelledAlready { c.resume(throwing: CancellationError()) }
            }
        } onCancel: {
            let entry: Entry? = state.withLock { s in
                if let i = s.entries.firstIndex(where: { $0.id == id }) { return s.entries.remove(at: i) }
                s.cancelled.insert(id)
                return nil
            }
            entry?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Number of sleeps of exactly `duration` that are waiting.
    func waiting(_ duration: Duration) -> Int {
        state.withLock { $0.entries.filter { $0.duration == duration }.count }
    }

    /// Ends all waiting sleeps of `duration` normally.
    func fire(_ duration: Duration) {
        let fired: [Entry] = state.withLock { s in
            let matching = s.entries.filter { $0.duration == duration }
            s.entries.removeAll { $0.duration == duration }
            return matching
        }
        for e in fired { e.continuation.resume() }
    }
}

/// Polls until `condition` holds (max ~3 s).
@MainActor
func until(_ condition: @MainActor () -> Bool) async {
    for _ in 0..<600 where !condition() {
        try? await Task.sleep(for: .milliseconds(5))
    }
}
