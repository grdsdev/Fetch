import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Represents an HTTP response received from a server.
/// 
/// The `Response` struct contains all the information about an HTTP response,
/// including the URL, status code, headers, and a streaming body. It provides
/// convenient methods for accessing the response data in different formats.
/// 
/// Example:
/// ```swift
/// let response = try await fetch("https://api.example.com/users")
/// 
/// // Check if the request was successful
/// if response.ok {
///   let users: [User] = try await response.json()
///   print("Received \(users.count) users")
/// } else {
///   print("Request failed with status: \(response.status)")
/// }
/// ```
public struct Response: Sendable {
  /// The URL of the response, which may differ from the request URL due to redirects
  public let url: URL?
  /// The HTTP status code (e.g., 200, 404, 500)
  public let status: Int
  /// The HTTP response headers
  public let headers: HTTPHeaders
  /// The response body as a streamable sequence of data chunks
  public let body: Body
  /// Indicates whether the response represents a successful HTTP status (200-299)
  /// 
  /// Example:
  /// ```swift
  /// let response = try await fetch("https://api.example.com/data")
  /// if response.ok {
  ///   // Handle successful response
  ///   let data = await response.blob()
  /// } else {
  ///   // Handle error response
  ///   print("HTTP Error: \(response.status)")
  /// }
  /// ```
  public var ok: Bool { status >= 200 && status < 300 }

  /// Represents the body of an HTTP response as a streamable sequence of data chunks.
  /// 
  /// The `Body` class implements `AsyncSequence`, allowing you to process response data
  /// as it arrives from the server. This is particularly useful for large responses
  /// or when you want to process data incrementally.
  /// 
  /// Example:
  /// ```swift
  /// let response = try await fetch("https://api.example.com/large-dataset")
  /// 
  /// // Process data as it streams in
  /// for await chunk in response.body {
  ///   // Process each chunk of data
  ///   processDataChunk(chunk)
  /// }
  /// 
  /// // Or collect all data at once
  /// let allData = await response.blob()
  /// ```
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

    /// Collects all data chunks from the response body into a single `Data` object.
    /// 
    /// This method consumes the entire response body and returns it as a single
    /// `Data` object. The data is cached after the first call, so subsequent
    /// calls will return the same data without re-reading from the stream.
    /// 
    /// - Returns: The complete response body as a `Data` object
    /// 
    /// Note: This method is called internally by `blob()`, `json()`, and `text()`.
    func collect() async -> Data {
      if let data = _data.withLock({ $0 }) {
        return data
      }

      let data = await stream.reduce(into: Data()) { $0 += $1 }
      _data.withLock { $0 = data }
      return data
    }

    /// Yields a chunk of data to the response body stream.
    /// This method is used internally by the networking layer.
    func yield(_ data: Data) {
      continuation.yield(data)
    }

    /// Signals that the response body stream has finished.
    /// This method is used internally by the networking layer.
    func finish() {
      continuation.finish()
    }
  }

  /// Creates a new Response instance.
  /// 
  /// This initializer is typically used internally by the Fetch library
  /// when creating responses from network operations.
  /// 
  /// - Parameters:
  ///   - url: The response URL (may differ from request URL due to redirects)
  ///   - status: The HTTP status code
  ///   - headers: The HTTP response headers
  ///   - body: The response body stream
  public init(url: URL?, status: Int, headers: HTTPHeaders, body: Body) {
    self.url = url
    self.status = status
    self.headers = headers
    self.body = body
  }

  /// Returns the response body as a `Data` object.
  /// 
  /// This method collects all chunks from the response body stream and
  /// returns them as a single `Data` object. The data is cached, so
  /// subsequent calls will return the same data without re-processing.
  /// 
  /// - Returns: The complete response body as a `Data` object
  /// 
  /// Example:
  /// ```swift
  /// let response = try await fetch("https://example.com/image.jpg")
  /// let imageData = await response.blob()
  /// let image = UIImage(data: imageData)
  /// ```
  public func blob() async -> Data {
    await body.collect()
  }

  /// Returns the response body as a parsed JSON object.
  /// 
  /// This method parses the response body as JSON and returns the result
  /// as an `Any` object (typically a Dictionary or Array).
  /// 
  /// - Returns: The parsed JSON object
  /// - Throws: An error if the response body is not valid JSON
  /// 
  /// Example:
  /// ```swift
  /// let response = try await fetch("https://api.example.com/config")
  /// let config = try await response.json() as! [String: Any]
  /// let apiKey = config["apiKey"] as! String
  /// ```
  public func json() async throws -> Any {
    return try JSONSerialization.jsonObject(with: await blob())
  }

  /// Returns the response body as a decoded Swift object.
  /// 
  /// This method parses the response body as JSON and decodes it into
  /// the specified `Decodable` type using the provided `JSONDecoder`.
  /// 
  /// - Parameter decoder: The JSON decoder to use (default: JSONDecoder())
  /// - Returns: The decoded object of type `T`
  /// - Throws: An error if the response body is not valid JSON or cannot be decoded
  /// 
  /// Example:
  /// ```swift
  /// struct User: Decodable {
  ///   let id: Int
  ///   let name: String
  /// }
  /// 
  /// let response = try await fetch("https://api.example.com/user/123")
  /// let user: User = try await response.json()
  /// print("User: \(user.name)")
  /// ```
  public func json<T: Decodable>(decoder: JSONDecoder = JSONDecoder()) async throws -> T {
    return try decoder.decode(T.self, from: await blob())
  }

  /// Returns the response body as a decoded object using a custom decoder.
  /// 
  /// This method is used for types that conform to `DecodableWithDecoder`,
  /// which provides their own custom decoding logic.
  /// 
  /// - Returns: The decoded object of type `T`
  /// - Throws: An error if the response body cannot be decoded
  /// 
  /// Example:
  /// ```swift
  /// struct CustomModel: DecodableWithDecoder {
  ///   static func decode(from data: Data) throws -> CustomModel {
  ///     // Custom decoding logic
  ///     return CustomModel()
  ///   }
  /// }
  /// 
  /// let response = try await fetch("https://api.example.com/custom")
  /// let model: CustomModel = try await response.json()
  /// ```
  public func json<T: DecodableWithDecoder>() async throws -> T {
    return try T.decode(from: await blob())
  }

  /// Returns the response body as a UTF-8 decoded string.
  /// 
  /// This method converts the response body data to a string using UTF-8 encoding.
  /// 
  /// - Returns: The response body as a `String`
  /// - Throws: An error if the response body cannot be decoded as UTF-8
  /// 
  /// Example:
  /// ```swift
  /// let response = try await fetch("https://api.example.com/readme.txt")
  /// let text = try await response.text()
  /// print("Response text: \(text)")
  /// ```
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
  /// A producer for manually creating response body streams.
  /// 
  /// The `Producer` struct provides methods for yielding data chunks
  /// and signaling completion when manually constructing response bodies.
  /// This is primarily used for testing or custom response creation.
  /// 
  /// Example:
  /// ```swift
  /// let body = Response.Body { producer in
  ///   producer.yield("Hello, ")
  ///   producer.yield("World!")
  ///   producer.finish()
  /// }
  /// ```
  public struct Producer {
    /// The underlying continuation for the async stream
    let continuation: AsyncStream<Data>.Continuation

    /// Yields a data chunk to the response body stream.
    /// - Parameter data: The data chunk to add to the stream
    public func yield(_ data: Data) {
      continuation.yield(data)
    }

    /// Yields a string as UTF-8 encoded data to the response body stream.
    /// - Parameter string: The string to add to the stream
    public func yield(_ string: String) {
      let data = Data(string.utf8)
      yield(data)
    }

    /// Yields a JSON object as encoded data to the response body stream.
    /// - Parameter json: The JSON object to encode and add to the stream
    /// - Throws: An error if the JSON object cannot be serialized
    public func yield(_ json: Any) throws {
      let data = try JSONSerialization.data(withJSONObject: json)
      yield(data)
    }

    /// Yields an encodable value as JSON data to the response body stream.
    /// - Parameters:
    ///   - value: The encodable value to add to the stream
    ///   - encoder: The JSON encoder to use (default: JSONEncoder())
    /// - Throws: An error if the value cannot be encoded
    public func yield<T: Encodable>(_ value: T, encoder: JSONEncoder = JSONEncoder()) throws {
      let data = try encoder.encode(value)
      yield(data)
    }

    /// Yields a custom encodable value to the response body stream.
    /// - Parameter value: The value that conforms to EncodableWithEncoder
    /// - Throws: An error if the value cannot be encoded
    public func yield<T: EncodableWithEncoder>(_ value: T) throws {
      let data = try value.encode()
      yield(data)
    }

    /// Signals that no more data will be yielded to the stream.
    /// This completes the response body stream.
    public func finish() {
      continuation.finish()
    }
  }

  /// Creates a response body by calling a producer function.
  /// 
  /// This convenience initializer allows you to create a response body
  /// by providing a closure that uses a `Producer` to yield data chunks.
  /// 
  /// - Parameter producer: A closure that takes a `Producer` and uses it to yield data
  /// 
  /// Example:
  /// ```swift
  /// let body = Response.Body { producer in
  ///   producer.yield("First chunk")
  ///   producer.yield("Second chunk")
  ///   producer.finish()
  /// }
  /// ```
  public convenience init(producer: (Producer) -> Void) {
    self.init()

    producer(Producer(continuation: continuation))
  }
}
