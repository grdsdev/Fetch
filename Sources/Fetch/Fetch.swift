import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A type-safe representation of HTTP methods.
/// 
/// This structure provides static constants for common HTTP methods
/// while allowing custom methods through the raw value initializer.
/// 
/// Example:
/// ```swift
/// let options = FetchOptions(method: .post)
/// let customMethod = HTTPMethod(rawValue: "PATCH")
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
/// 
/// Example:
/// ```swift
/// let options = FetchOptions(
///   method: .post,
///   headers: ["Authorization": "Bearer token123"],
///   body: ["key": "value"],
///   timeoutInterval: 30.0
/// )
/// let response = try await fetch("https://api.example.com/data", options: options)
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
  /// let options = FetchOptions(download: true)
  /// let response = try await fetch("https://example.com/large-file.zip", options: options)
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
public let fetch = Fetch()

/// A modern, async HTTP client for making network requests.
/// 
/// The `Fetch` actor provides a clean, type-safe API for making HTTP requests
/// with support for modern Swift concurrency features. It handles various
/// request types including data tasks, file uploads, and downloads.
/// 
/// Example:
/// ```swift
/// // Using the global instance
/// let response = try await fetch("https://api.example.com/users")
/// let users: [User] = try await response.json()
/// 
/// // Creating a custom instance
/// let customFetch = Fetch(configuration: .init(sessionConfiguration: .ephemeral))
/// let response = try await customFetch("https://api.example.com/data")
/// ```
public actor Fetch {
  /// Configuration options for customizing a Fetch instance.
  /// 
  /// Use `Configuration` to customize the underlying `URLSession` behavior,
  /// set custom delegates, or configure the operation queue for delegate callbacks.
  /// 
  /// Example:
  /// ```swift
  /// let config = Fetch.Configuration(
  ///   sessionConfiguration: .ephemeral,
  ///   sessionDelegate: myDelegate,
  ///   sessionDelegateQueue: .main
  /// )
  /// let fetch = Fetch(configuration: config)
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
  /// Makes an HTTP request to the specified URL with the given options.
  /// 
  /// This method allows the Fetch instance to be called as a function,
  /// providing a clean and intuitive API for making requests.
  /// 
  /// - Parameters:
  ///   - url: The URL to make the request to
  ///   - options: The request options (default: GET request with no body)
  /// - Returns: A `Response` object containing the server's response
  /// - Throws: An error if the request fails or cannot be completed
  /// 
  /// Example:
  /// ```swift
  /// let response = try await fetch(url)
  /// let data = await response.blob()
  /// ```
  public func callAsFunction(
    _ url: URL,
    options: FetchOptions = FetchOptions()
  ) async throws -> Response {
    var urlRequest = URLRequest(url: url)
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

  /// Makes an HTTP request to the specified URL string with the given options.
  /// 
  /// This convenience method allows making requests with string URLs,
  /// automatically validating and converting them to URL objects.
  /// 
  /// - Parameters:
  ///   - urlString: The URL string to make the request to
  ///   - options: The request options (default: GET request with no body)
  /// - Returns: A `Response` object containing the server's response
  /// - Throws: An error if the URL is invalid or the request fails
  /// 
  /// Example:
  /// ```swift
  /// let response = try await fetch("https://api.example.com/users")
  /// let users: [User] = try await response.json()
  /// ```
  public func callAsFunction(
    _ urlString: String,
    options: FetchOptions = FetchOptions()
  ) async throws -> Response {
    guard let url = URL(string: urlString) else {
      throw NSError(
        domain: "Fetch",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"]
      )
    }
    return try await self(url, options: options)
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
      return formData.encode()

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
