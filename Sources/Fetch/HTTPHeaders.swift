/// A case-insensitive dictionary of HTTP headers.
public struct HTTPHeaders {
  private var headers: [String: String]

  /// The dictionary of HTTP headers.
  public var dictionary: [String: String] {
    headers
  }

  private static let lowercasedKeysToCanonicalKeys: Mutex<[String: String]> = Mutex([:])

  /// Initializes a new instance of ``HTTPHeaders`` with the given dictionary.
  public init(_ dictionary: [String: String] = [:]) {
    self.headers = dictionary.reduce(into: [String: String]()) {
      result,
      pair in
      result[HTTPHeaders._canonicalize(key: pair.key)] = pair.value
    }
  }

  public subscript(key: String) -> String? {
    get { headers[HTTPHeaders._canonicalize(key: key)] }
    set { headers[HTTPHeaders._canonicalize(key: key)] = newValue }
  }

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

extension HTTPHeaders: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let headers = try container.decode([String: String].self)
    self.init(headers)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(headers)
  }
}

extension HTTPHeaders: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, String)...) {
    self.init(Dictionary(uniqueKeysWithValues: elements))
  }
}

extension HTTPHeaders: Sequence {
  public typealias Element = (key: String, value: String)

  public func makeIterator() -> Dictionary<String, String>.Iterator {
    headers.makeIterator()
  }
}
