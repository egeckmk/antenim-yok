import Foundation

/// Response head plus the body as a stream of chunks.
public struct HTTPByteStream: Sendable {
    public var statusCode: Int
    /// Header names are lower-cased.
    public var headers: [String: String]
    /// Final URL after redirects.
    public var finalURL: URL?
    public var chunks: AsyncThrowingStream<Data, any Error>

    public init(statusCode: Int, headers: [String: String] = [:], finalURL: URL? = nil, chunks: AsyncThrowingStream<Data, any Error>) {
        self.statusCode = statusCode
        self.headers = headers
        self.finalURL = finalURL
        self.chunks = chunks
    }
}

public struct HTTPResponseData: Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var finalURL: URL?
    public var data: Data

    public init(statusCode: Int, headers: [String: String] = [:], finalURL: URL? = nil, data: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.finalURL = finalURL
        self.data = data
    }
}

/// Network access behind a protocol, so Radio Browser, playlists and ICY titles are testable with fakes.
public protocol HTTPTransport: Sendable {
    /// Whole body in memory (JSON, small files).
    func data(for request: URLRequest) async throws -> HTTPResponseData
    /// Streams the body (endless audio streams, ICY metadata).
    func stream(for request: URLRequest) async throws -> HTTPByteStream
}

public struct HTTPError: Error, Equatable, Sendable {
    public var statusCode: Int
    public init(statusCode: Int) { self.statusCode = statusCode }
}

/// `URLSession`-backed transport.
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> HTTPResponseData {
        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        return HTTPResponseData(
            statusCode: http?.statusCode ?? 200,
            headers: Self.headers(of: http),
            finalURL: response.url,
            data: data)
    }

    public func stream(for request: URLRequest) async throws -> HTTPByteStream {
        let (bytes, response) = try await session.bytes(for: request)
        let http = response as? HTTPURLResponse
        let chunks = AsyncThrowingStream<Data, any Error> { continuation in
            let task = Task {
                do {
                    var buffer = Data()
                    buffer.reserveCapacity(2048)
                    for try await byte in bytes {
                        buffer.append(byte)
                        if buffer.count >= 2048 {
                            continuation.yield(buffer)
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty { continuation.yield(buffer) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return HTTPByteStream(
            statusCode: http?.statusCode ?? 200,
            headers: Self.headers(of: http),
            finalURL: response.url,
            chunks: chunks)
    }

    private static func headers(of response: HTTPURLResponse?) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in response?.allHeaderFields ?? [:] {
            if let key = key as? String, let value = value as? String {
                result[key.lowercased()] = value
            }
        }
        return result
    }
}
