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

    init(json: String, status: Int = 200) {
        body = Data(json.utf8)
        self.status = status
    }

    var recorded: [URLRequest] { requests.withLock { $0 } }

    func data(for request: URLRequest) async throws -> HTTPResponseData {
        requests.withLock { $0.append(request) }
        return HTTPResponseData(statusCode: status, finalURL: request.url, data: body)
    }

    func stream(for request: URLRequest) async throws -> HTTPByteStream {
        requests.withLock { $0.append(request) }
        let body = body
        return HTTPByteStream(statusCode: status, finalURL: request.url, chunks: AsyncThrowingStream { c in
            c.yield(body)
            c.finish()
        })
    }
}
