import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct Response: Sendable {
  public let url: URL?
  public let status: Int
  public let headers: HTTPHeaders
  public let body: Body

  /// A type that represents the body of an HTTP response.
  public final class Body: AsyncSequence, Sendable {
    public typealias AsyncIterator = AsyncStream<Data>.Iterator
    public typealias Element = Data
    public typealias Failure = Never

    let stream: AsyncStream<Data>
    let continuation: AsyncStream<Data>.Continuation

    package init() {
      (stream, continuation) = AsyncStream.makeStream()
    }

    public func makeAsyncIterator() -> AsyncIterator {
      stream.makeAsyncIterator()
    }

    private let _data: Mutex<Data?> = Mutex(nil)

    /// Collects the response body as a ``Data``.
    /// - Returns: The response body as ``Data``.
    func collect() async -> Data {
      if let data = _data.withLock({ $0 }) {
        return data
      }

      let data = await stream.reduce(into: Data()) { $0 += $1 }
      _data.withLock { $0 = data }
      return data
    }

    func yield(_ data: Data) {
      continuation.yield(data)
    }

    func finish() {
      continuation.finish()
    }
  }

  public init(url: URL?, status: Int, headers: HTTPHeaders, body: Body) {
    self.url = url
    self.status = status
    self.headers = headers
    self.body = body
  }

  /// Returns the response body as a `Data` object.
  ///
  /// - Returns: The response body as a `Data` object.
  /// - Throws: An error if the response body cannot be converted to a `Data` object.
  public func blob() async -> Data {
    await body.collect()
  }

  /// Returns the response body as a `JSON` object.
  ///
  /// - Returns: The response body as a `JSON` object.
  /// - Throws: An error if the response body cannot be converted to a `JSON` object.
  public func json() async throws -> Any {
    return try JSONSerialization.jsonObject(with: await blob())
  }

  /// Returns the response body as a `Decodable` object.
  ///
  /// - Returns: The response body as a `Decodable` object.
  /// - Throws: An error if the response body cannot be converted to a `Decodable` object.
  public func json<T: Decodable>(decoder: JSONDecoder = JSONDecoder()) async throws -> T {
    return try decoder.decode(T.self, from: await blob())
  }

  /// Returns the response body as a `DecodableWithDecoder` object.
  ///
  /// - Returns: The response body as a `DecodableWithDecoder` object.
  /// - Throws: An error if the response body cannot be converted to a `DecodableWithDecoder` object.
  public func json<T: DecodableWithDecoder>() async throws -> T {
    return try T.decode(from: await blob())
  }

  /// Returns the response body as a `String` object.
  ///
  /// - Returns: The response body as a `String` object.
  /// - Throws: An error if the response body cannot be converted to a `String` object.
  public func text() async throws -> String {
    guard let string = String(data: await blob(), encoding: .utf8) else {
      throw NSError(
        domain: "Fetch",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Could not decode response as UTF-8 string"]
      )
    }
    return string
  }
}

extension Response.Body {
  public struct Producer {
    let continuation: AsyncStream<Data>.Continuation

    public func yield(_ data: Data) {
      continuation.yield(data)
    }

    public func yield(_ string: String) {
      let data = Data(string.utf8)
      yield(data)
    }

    public func yield(_ json: Any) throws {
      let data = try JSONSerialization.data(withJSONObject: json)
      yield(data)
    }

    public func yield<T: Encodable>(_ value: T, encoder: JSONEncoder = JSONEncoder()) throws {
      let data = try encoder.encode(value)
      yield(data)
    }

    public func yield<T: EncodableWithEncoder>(_ value: T) throws {
      let data = try value.encode()
      yield(data)
    }

    public func finish() {
      continuation.finish()
    }
  }

  public convenience init(producer: (Producer) -> Void) {
    self.init()

    producer(Producer(continuation: continuation))
  }
}
