import Foundation

public struct HTTPMethod: RawRepresentable, Sendable {
  public static let get = HTTPMethod(rawValue: "GET")
  public static let post = HTTPMethod(rawValue: "POST")
  public static let put = HTTPMethod(rawValue: "PUT")
  public static let delete = HTTPMethod(rawValue: "DELETE")
  public static let patch = HTTPMethod(rawValue: "PATCH")
  public static let head = HTTPMethod(rawValue: "HEAD")
  public static let options = HTTPMethod(rawValue: "OPTIONS")

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public var rawValue: String
}

/// Options for the Fetch API.
public struct FetchOptions: Sendable {
  /// The HTTP method to use for the request.
  public var method: HTTPMethod
  /// The headers to include in the request.
  public var headers: HTTPHeaders
  /// The body of the request.
  public var body: (any Sendable)?
  /// The cache policy to use for the request.
  public var cachePolicy: URLRequest.CachePolicy
  /// The timeout interval for the request.
  public var timeoutInterval: TimeInterval
  /// Whether to download the response body.
  ///
  /// When `download` is `true`, the response is downloaded to a temporary file using `URLSessionDownloadTask`,
  /// and the response body is streamed by chunks of ``downloadChunkSize``.
  ///
  /// - Note: Download requests should not have a body.
  public var download: Bool

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

/// The default Fetch instance.
public let fetch = Fetch()

/// The Fetch API.
public actor Fetch: Sendable {
  /// Configuration options for the Fetch instance.
  public struct Configuration {
    /// The `URLSessionConfiguration` to use for network requests.
    public var sessionConfiguration: URLSessionConfiguration
    /// An optional `URLSessionDelegate` for advanced session management.
    public var sessionDelegate: URLSessionDelegate?
    /// An optional `OperationQueue` for handling delegate calls.
    public var sessionDelegateQueue: OperationQueue?

    public init(
      sessionConfiguration: URLSessionConfiguration = .default,
      sessionDelegate: URLSessionDelegate? = nil,
      sessionDelegateQueue: OperationQueue? = nil
    ) {
      self.sessionConfiguration = sessionConfiguration
      self.sessionDelegate = sessionDelegate
      self.sessionDelegateQueue = sessionDelegateQueue
    }

    /// The default configuration.
    public static var `default`: Configuration {
      Configuration()
    }
  }

  /// The `URLSession` used for making network requests.
  let session: URLSession
  let dataLoader = DataLoader()

  /// Initializes a new `Fetch` instance with the given configuration.
  /// - Parameter configuration: The configuration to use for this Fetch instance.
  ///
  /// Example:
  /// ```swift
  /// let customConfig = Fetch.Configuration(sessionConfiguration: .ephemeral, encoder: JSONEncoder())
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

  public func callAsFunction(
    _ urlString: String,
    options: FetchOptions = FetchOptions()
  ) async throws -> Response {
    guard let url = URL(string: urlString) else {
      throw NSError(
        domain: "Fetch",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
      )
    }
    return try await self(url, options: options)
  }

  /// Encodes the request body based on its type.
  /// - Parameters:
  ///   - value: The value to encode as the request body.
  ///   - request: The `URLRequest` to modify with the encoded body.
  /// - Throws: An error if encoding fails or if the value type is not supported.
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
  static func serial() -> OperationQueue {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
  }
}
