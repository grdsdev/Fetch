import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A protocol for making HTTP requests with a clean, modern API.
///
/// The `Fetch` protocol defines the interface for HTTP clients that support
/// Swift's callable syntax and builder pattern for configuring requests.
///
/// Example:
/// ```swift
/// let response = try await fetch("https://api.example.com/data")
/// let json = try await response.json()
///
/// // With configuration
/// let response = try await fetch("https://api.example.com/users") {
///   $0.method = .post
///   $0.headers["Authorization"] = "Bearer token"
///   $0.body = ["name": "John"]
/// }
/// ```
public protocol Fetch: Sendable {
  /// Makes an HTTP request to the specified URL with configurable options.
  ///
  /// - Parameters:
  ///   - url: The URL to make the request to
  ///   - builder: A closure that configures the request options
  /// - Returns: A `Response` object containing the server's response
  /// - Throws: An error if the request fails or cannot be completed
  func callAsFunction(_ url: URL, options builder: (inout FetchOptions) -> Void) async throws
    -> Response
}
extension Fetch {
  /// Makes an HTTP request to the specified URL string with configurable options.
  ///
  /// - Parameters:
  ///   - urlString: The URL string to make the request to
  ///   - builder: A closure that configures the request options
  /// - Returns: A `Response` object containing the server's response
  /// - Throws: An error if the URL is invalid or the request fails
  public func callAsFunction(_ urlString: String, options builder: (inout FetchOptions) -> Void)
    async throws -> Response
  {
    try await self(URL(string: urlString)!, options: builder)
  }

  /// Makes a simple GET request to the specified URL.
  ///
  /// - Parameter url: The URL to make the request to
  /// - Returns: A `Response` object containing the server's response
  /// - Throws: An error if the request fails or cannot be completed
  public func callAsFunction(_ url: URL) async throws -> Response {
    try await self(url, options: { _ in })
  }

  /// Makes a simple GET request to the specified URL string.
  ///
  /// - Parameter urlString: The URL string to make the request to
  /// - Returns: A `Response` object containing the server's response
  /// - Throws: An error if the URL is invalid or the request fails
  public func callAsFunction(_ urlString: String) async throws -> Response {
    try await self(urlString, options: { _ in })
  }
}

/// A type-safe representation of HTTP methods.
///
/// This structure provides static constants for common HTTP methods
/// while allowing custom methods through the raw value initializer.
///
/// Example:
/// ```swift
/// // Using predefined methods
/// let response = try await fetch(url) {
///   $0.method = .post
/// }
///
/// // Using custom method
/// let customMethod = HTTPMethod(rawValue: "PATCH")
/// let response = try await fetch(url) {
///   $0.method = customMethod
/// }
/// ```
public struct HTTPMethod: RawRepresentable, Sendable {
  /// HTTP GET method - used for retrieving data
  public static let get = HTTPMethod(rawValue: "GET")
  /// HTTP POST method - used for creating new resources
  public static let post = HTTPMethod(rawValue: "POST")
  /// HTTP PUT method - used for updating entire resources
  public static let put = HTTPMethod(rawValue: "PUT")
  /// HTTP DELETE method - used for removing resources
  public static let delete = HTTPMethod(rawValue: "DELETE")
  /// HTTP PATCH method - used for partial updates
  public static let patch = HTTPMethod(rawValue: "PATCH")
  /// HTTP HEAD method - used for retrieving headers only
  public static let head = HTTPMethod(rawValue: "HEAD")
  /// HTTP OPTIONS method - used for discovering allowed methods
  public static let options = HTTPMethod(rawValue: "OPTIONS")

  /// Creates a new HTTP method with the specified raw value.
  /// - Parameter rawValue: The string representation of the HTTP method
  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// The string representation of the HTTP method
  public var rawValue: String
}

/// Configuration options for HTTP requests made with the Fetch API.
///
/// Use `FetchOptions` to customize various aspects of your HTTP request,
/// including the method, headers, body, caching policy, and timeout.
/// The options are configured using a builder pattern in the fetch call.
///
/// Example:
/// ```swift
/// let response = try await fetch("https://api.example.com/data") {
///   $0.method = .post
///   $0.headers["Authorization"] = "Bearer token123"
///   $0.body = ["key": "value"]
///   $0.timeoutInterval = 30.0
/// }
/// ```
public struct FetchOptions: Sendable {
  /// The HTTP method to use for the request (default: .get)
  public var method: HTTPMethod
  /// The headers to include in the request (default: empty)
  public var headers: HTTPHeaders
  /// The body content of the request.
  ///
  /// Supported types include:
  /// - `Data` - Raw binary data
  /// - `String` - Text content
  /// - `URL` - File upload from local file
  /// - `FormData` - Multipart form data
  /// - `URLSearchParams` - URL-encoded form data
  /// - `Encodable` types - Automatically encoded as JSON
  /// - Dictionary/Array - Valid JSON objects
  public var body: (any Sendable)?
  /// The cache policy to use for the request (default: .useProtocolCachePolicy)
  public var cachePolicy: URLRequest.CachePolicy
  /// The timeout interval in seconds for the request (default: 60.0)
  public var timeoutInterval: TimeInterval
  /// Whether to download the response body to a file (default: false).
  ///
  /// When `download` is `true`, the response is downloaded to a temporary file using `URLSessionDownloadTask`,
  /// which is more memory-efficient for large files as the content is streamed directly to disk.
  /// The response body can then be accessed as a streaming `AsyncSequence`.
  ///
  /// Example:
  /// ```swift
  /// let response = try await fetch("https://example.com/large-file.zip") {
  ///   $0.download = true
  /// }
  /// let data = await response.blob()
  /// ```
  ///
  /// - Note: Download requests should not have a body.
  public var download: Bool

  /// Creates a new `FetchOptions` instance with the specified parameters.
  ///
  /// - Parameters:
  ///   - method: The HTTP method to use (default: .get)
  ///   - headers: The headers to include (default: empty)
  ///   - body: The request body content (default: nil)
  ///   - cachePolicy: The cache policy (default: .useProtocolCachePolicy)
  ///   - timeoutInterval: The timeout in seconds (default: 60.0)
  ///   - download: Whether to download to file (default: false)
  public init(
    method: HTTPMethod = .get,
    headers: HTTPHeaders = HTTPHeaders(),
    body: (any Sendable)? = nil,
    cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
    timeoutInterval: TimeInterval = 60.0,
    download: Bool = false
  ) {
    self.method = method
    self.headers = headers
    self.body = body
    self.cachePolicy = cachePolicy
    self.timeoutInterval = timeoutInterval
    self.download = download
  }
}

/// The default Fetch instance for making HTTP requests.
///
/// This is a convenient global instance that you can use directly
/// without creating your own Fetch instance.
///
/// Example:
/// ```swift
/// let response = try await fetch("https://api.example.com/data")
/// let json = try await response.json()
/// ```
public let fetch: any Fetch = FetchClient()

/// A modern, async HTTP client for making network requests.
///
/// The `FetchClient` actor provides a clean, type-safe API for making HTTP requests
/// with support for modern Swift concurrency features. It handles various
/// request types including data tasks, file uploads, and downloads.
///
/// Example:
/// ```swift
/// // Using the global instance
/// let response = try await fetch("https://api.example.com/users")
/// let users: [User] = try await response.json()
///
/// // Using with configuration
/// let response = try await fetch("https://api.example.com/data") {
///   $0.method = .post
///   $0.headers["Content-Type"] = "application/json"
///   $0.body = user
/// }
///
/// // Creating a custom instance
/// let customFetch = FetchClient(configuration: .init(sessionConfiguration: .ephemeral))
/// let response = try await customFetch("https://api.example.com/data")
/// ```
public actor FetchClient: Fetch {
  /// Configuration options for customizing a Fetch instance.
  ///
  /// Use `Configuration` to customize the underlying `URLSession` behavior,
  /// set custom delegates, or configure the operation queue for delegate callbacks.
  ///
  /// Example:
  /// ```swift
  /// let config = FetchClient.Configuration(
  ///   sessionConfiguration: .ephemeral,
  ///   sessionDelegate: myDelegate,
  ///   sessionDelegateQueue: .main
  /// )
  /// let customFetch = FetchClient(configuration: config)
  /// ```
  public struct Configuration {
    /// The `URLSessionConfiguration` to use for network requests (default: .default)
    public var sessionConfiguration: URLSessionConfiguration
    /// An optional `URLSessionDelegate` for advanced session management and custom handling
    public var sessionDelegate: URLSessionDelegate?
    /// An optional `OperationQueue` for handling delegate calls (default: serial queue)
    public var sessionDelegateQueue: OperationQueue?

    /// Creates a new configuration with the specified parameters.
    ///
    /// - Parameters:
    ///   - sessionConfiguration: The session configuration (default: .default)
    ///   - sessionDelegate: Optional session delegate for custom handling
    ///   - sessionDelegateQueue: Optional queue for delegate callbacks
    public init(
      sessionConfiguration: URLSessionConfiguration = .default,
      sessionDelegate: URLSessionDelegate? = nil,
      sessionDelegateQueue: OperationQueue? = nil
    ) {
      self.sessionConfiguration = sessionConfiguration
      self.sessionDelegate = sessionDelegate
      self.sessionDelegateQueue = sessionDelegateQueue
    }

    /// The default configuration using standard URLSession settings.
    public static var `default`: Configuration {
      Configuration()
    }
  }

  /// The `URLSession` used for making network requests
  let session: URLSession
  /// Internal data loader for handling different types of URL session tasks
  let dataLoader = DataLoader()

  /// Initializes a new `Fetch` instance with the given configuration.
  ///
  /// - Parameter configuration: The configuration to use for this Fetch instance (default: .default)
  ///
  /// Example:
  /// ```swift
  /// let customConfig = Fetch.Configuration(
  ///   sessionConfiguration: .ephemeral,
  ///   sessionDelegate: myDelegate
  /// )
  /// let customFetch = Fetch(configuration: customConfig)
  /// ```
  public init(configuration: Configuration = .default) {
    self.session = URLSession(
      configuration: configuration.sessionConfiguration,
      delegate: dataLoader,
      delegateQueue: configuration.sessionDelegateQueue ?? .serial()
    )

    dataLoader.userSessionDelegate = configuration.sessionDelegate
  }
  /// Makes an HTTP request to the specified URL with configurable options.
  ///
  /// This method allows the Fetch instance to be called as a function,
  /// providing a clean and intuitive API for making requests using a builder pattern.
  ///
  /// - Parameters:
  ///   - url: The URL to make the request to
  ///   - builder: A closure that configures the request options
  /// - Returns: A `Response` object containing the server's response
  /// - Throws: An error if the request fails or cannot be completed
  ///
  /// Example:
  /// ```swift
  /// // Simple GET request
  /// let response = try await fetch(url)
  /// let data = await response.blob()
  ///
  /// // POST request with JSON body
  /// let response = try await fetch(url) {
  ///   $0.method = .post
  ///   $0.headers["Content-Type"] = "application/json"
  ///   $0.body = ["name": "John", "age": 30]
  /// }
  /// ```
  public func callAsFunction(
    _ url: URL,
    options builder: (inout FetchOptions) -> Void = { _ in }
  ) async throws -> Response {
    var urlRequest = URLRequest(url: url)
    var options = FetchOptions()
    builder(&options)
    urlRequest.httpMethod = options.method.rawValue
    urlRequest.allHTTPHeaderFields = options.headers.dictionary
    urlRequest.cachePolicy = options.cachePolicy
    urlRequest.timeoutInterval = options.timeoutInterval

    if options.download {
      assert(
        options.body == nil,
        "Download requests should not have a body."
      )
    }

    try optimizeRequest(for: &options)

    if let body = options.body {
      if let url = body as? URL {
        let task = session.uploadTask(with: urlRequest, fromFile: url)
        return try await dataLoader.startUploadTask(
          task,
          session: session,
          delegate: nil
        )
      } else {
        let uploadData = try encode(body, in: &urlRequest)
        let task = session.uploadTask(with: urlRequest, from: uploadData)
        return try await dataLoader.startUploadTask(
          task,
          session: session,
          delegate: nil
        )
      }
    } else if options.download {
      // For download requests, we use a download task.
      let task = session.downloadTask(with: urlRequest)
      return try await dataLoader.startDownloadTask(
        task,
        session: session,
        delegate: nil
      )
    } else {
      // If not a download, nor we have a body, we use a data task.
      let task = session.dataTask(with: urlRequest)
      return try await dataLoader.startDataTask(
        task,
        session: session,
        delegate: nil
      )
    }
  }

  /// Makes an HTTP request to the specified URL string with configurable options.
  ///
  /// This convenience method allows making requests with string URLs,
  /// automatically validating and converting them to URL objects.
  ///
  /// - Parameters:
  ///   - urlString: The URL string to make the request to
  ///   - builder: A closure that configures the request options
  /// - Returns: A `Response` object containing the server's response
  /// - Throws: An error if the URL is invalid or the request fails
  ///
  /// Example:
  /// ```swift
  /// // Simple GET request
  /// let response = try await fetch("https://api.example.com/users")
  /// let users: [User] = try await response.json()
  ///
  /// // File upload
  /// let response = try await fetch("https://api.example.com/upload") {
  ///   $0.method = .post
  ///   $0.body = fileURL
  /// }
  /// ```
  public func callAsFunction(
    _ urlString: String,
    options builder: (inout FetchOptions) -> Void = { _ in }
  ) async throws -> Response {
    guard let url = URL(string: urlString) else {
      throw NSError(
        domain: "Fetch",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"]
      )
    }
    return try await self(url, options: builder)
  }

  /// Optimizes the request by writing the body to a temporary file if it's a `FormData`
  /// and the content length is larger than the threshold.
  private func optimizeRequest(for options: inout FetchOptions) throws {
    guard
      let formData = options.body as? FormData,
      formData.contentLength > FormData.encodingMemoryThreshold
    else {
      return
    }
    let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString)
    try formData.writeEncodedData(to: tempFile)
    options.body = tempFile
  }

  /// Encodes the request body based on its type and sets appropriate Content-Type headers.
  ///
  /// This method automatically determines the appropriate encoding and Content-Type header
  /// based on the type of the provided value. Supported types include:
  /// - `Data`: Used as-is with `application/octet-stream`
  /// - `String`: UTF-8 encoded with `text/plain`
  /// - `FormData`: Multipart form data encoding
  /// - `URLSearchParams`: URL-encoded form data
  /// - `EncodableWithEncoder`: Custom encoding protocol
  /// - `Encodable`: JSON encoding with `application/json`
  /// - Dictionary/Array: JSON serialization
  ///
  /// - Parameters:
  ///   - value: The value to encode as the request body
  ///   - request: The `URLRequest` to modify with the encoded body and headers
  /// - Returns: The encoded data ready to be sent in the request body
  /// - Throws: An error if encoding fails or if the value type is not supported
  private func encode(
    _ value: Any,
    in request: inout URLRequest
  ) throws -> Data {
    switch value {
    case let data as Data:
      if request.value(forHTTPHeaderField: "Content-Type") == nil {
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
      }
      return data

    case let str as String:
      if request.value(forHTTPHeaderField: "Content-Type") == nil {
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
      }
      return Data(str.utf8)

    case is URL:
      fatalError("URL body should be handled before reaching this point.")

    case let formData as FormData:
      if request.value(forHTTPHeaderField: "Content-Type") == nil {
        request.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")
      }
      return try formData.encode()

    case let searchParams as URLSearchParams:
      if request.value(forHTTPHeaderField: "Content-Type") == nil {
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
      }
      return searchParams.description.data(using: .utf8)!

    case let value as any EncodableWithEncoder:
      if request.value(forHTTPHeaderField: "Content-Type") == nil {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      }
      return try value.encode()

    case let value as any Encodable:
      if request.value(forHTTPHeaderField: "Content-Type") == nil {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      }

      return try JSONEncoder().encode(value)

    default:
      if JSONSerialization.isValidJSONObject(value) {
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return try JSONSerialization.data(withJSONObject: value)
      } else {
        fatalError("Unsupported body type: \(type(of: value))")
      }
    }
  }
}

extension OperationQueue {
  /// Creates a serial operation queue with maximum concurrent operation count of 1.
  /// Used internally for URLSession delegate callbacks.
  static func serial() -> OperationQueue {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
  }
}
