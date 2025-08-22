/// A case-insensitive dictionary for managing HTTP headers.
///
/// `HTTPHeaders` provides a convenient way to work with HTTP headers
/// while automatically handling case-insensitive lookups and canonical
/// key formatting (e.g., "content-type" becomes "Content-Type").
///
/// Example:
/// ```swift
/// var headers = HTTPHeaders()
/// headers["content-type"] = "application/json"
/// headers["Authorization"] = "Bearer token123"
///
/// // Case-insensitive access
/// print(headers["CONTENT-TYPE"]) // Optional("application/json")
///
/// // Dictionary literal initialization
/// let headers2: HTTPHeaders = [
///   "Accept": "application/json",
///   "User-Agent": "MyApp/1.0"
/// ]
/// ```
public struct HTTPHeaders {
  /// Internal storage for the canonicalized headers
  private var headers: [String: String]

  /// Returns the internal dictionary representation of the headers.
  ///
  /// The keys in this dictionary are canonicalized (e.g., "Content-Type")
  /// and can be used directly with URLRequest's `allHTTPHeaderFields`.
  ///
  /// Example:
  /// ```swift
  /// let headers: HTTPHeaders = ["content-type": "application/json"]
  /// urlRequest.allHTTPHeaderFields = headers.dictionary
  /// ```
  public var dictionary: [String: String] {
    headers
  }

  /// Thread-safe cache for mapping lowercase keys to their canonical forms
  private static let lowercasedKeysToCanonicalKeys: Mutex<[String: String]> = Mutex([:])

  /// Creates a new `HTTPHeaders` instance from a dictionary.
  ///
  /// The keys in the provided dictionary will be canonicalized to follow
  /// standard HTTP header formatting (e.g., "content-type" → "Content-Type").
  ///
  /// - Parameter dictionary: A dictionary of header names and values (default: empty)
  ///
  /// Example:
  /// ```swift
  /// let headers = HTTPHeaders([
  ///   "content-type": "application/json",
  ///   "authorization": "Bearer token123"
  /// ])
  /// ```
  public init(_ dictionary: [String: String] = [:]) {
    self.headers = dictionary.reduce(into: [String: String]()) {
      result,
      pair in
      result[HTTPHeaders._canonicalize(key: pair.key)] = pair.value
    }
  }

  /// Gets or sets a header value using case-insensitive key lookup.
  ///
  /// The key will be canonicalized to follow standard HTTP header formatting.
  /// Setting a value to `nil` removes the header.
  ///
  /// - Parameter key: The header name (case-insensitive)
  /// - Returns: The header value, or `nil` if not found
  ///
  /// Example:
  /// ```swift
  /// var headers = HTTPHeaders()
  /// headers["content-type"] = "application/json"
  /// print(headers["Content-Type"]) // Optional("application/json")
  /// headers["authorization"] = nil // Removes the header
  /// ```
  public subscript(key: String) -> String? {
    get { headers[HTTPHeaders._canonicalize(key: key)] }
    set { headers[HTTPHeaders._canonicalize(key: key)] = newValue }
  }

  /// Converts a header key to its canonical form with proper capitalization.
  ///
  /// This method converts header keys like "content-type" to "Content-Type"
  /// and caches the results for performance. The canonicalization follows
  /// HTTP header naming conventions.
  ///
  /// - Parameter key: The header key to canonicalize
  /// - Returns: The canonicalized header key
  private static func _canonicalize(key: String) -> String {
    lowercasedKeysToCanonicalKeys.withLock {
      let lowercasedKey = key.lowercased()

      if let canonicalKey = $0[lowercasedKey] {
        return canonicalKey
      }

      let canonicalKey = lowercasedKey.split(separator: "-")
        .map { $0.capitalized }
        .joined(separator: "-")

      $0[lowercasedKey] = canonicalKey
      return canonicalKey
    }
  }
}

extension HTTPHeaders: Sendable {}
extension HTTPHeaders: Hashable {}
extension HTTPHeaders: Equatable {}

extension HTTPHeaders: Codable {
  /// Creates an `HTTPHeaders` instance from a decoder.
  ///
  /// The headers are decoded as a dictionary and then canonicalized.
  ///
  /// - Parameter decoder: The decoder to read from
  /// - Throws: A decoding error if the data cannot be decoded as a dictionary
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let headers = try container.decode([String: String].self)
    self.init(headers)
  }

  /// Encodes the headers to an encoder.
  ///
  /// The headers are encoded as their internal dictionary representation
  /// with canonicalized keys.
  ///
  /// - Parameter encoder: The encoder to write to
  /// - Throws: An encoding error if the headers cannot be encoded
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(headers)
  }
}

extension HTTPHeaders: ExpressibleByDictionaryLiteral {
  /// Creates an `HTTPHeaders` instance from a dictionary literal.
  ///
  /// This allows you to create headers using dictionary literal syntax.
  ///
  /// Example:
  /// ```swift
  /// let headers: HTTPHeaders = [
  ///   "Content-Type": "application/json",
  ///   "Authorization": "Bearer token123"
  /// ]
  /// ```
  ///
  /// - Parameter elements: The key-value pairs for the headers
  public init(dictionaryLiteral elements: (String, String)...) {
    self.init(Dictionary(uniqueKeysWithValues: elements))
  }
}

extension HTTPHeaders: Sequence {
  /// The element type when iterating over headers
  public typealias Element = (key: String, value: String)

  /// Creates an iterator for the headers.
  ///
  /// This allows you to iterate over all headers using for-in loops.
  ///
  /// Example:
  /// ```swift
  /// let headers: HTTPHeaders = ["Content-Type": "application/json"]
  /// for (name, value) in headers {
  ///   print("\(name): \(value)")
  /// }
  /// ```
  ///
  /// - Returns: An iterator over the header key-value pairs
  public func makeIterator() -> Dictionary<String, String>.Iterator {
    headers.makeIterator()
  }
}
