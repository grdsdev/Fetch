/// A case-insensitive dictionary of HTTP headers.
public struct HTTPHeaders: Sendable {
  private var headers: [String: String]

  public var dictionary: [String: String] {
    headers
  }

  private static let lowercasedKeysToCanonicalKeys: Mutex<[String: String]> = Mutex([:])

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
    let lowercasedKey = key.lowercased()
    if let canonicalKey = lowercasedKeysToCanonicalKeys.withLock({ $0[lowercasedKey] }) {
      return canonicalKey
    }

    let canonicalKey = lowercasedKey.split(separator: "-")
      .map { $0.capitalized }
      .joined(separator: "-")

    lowercasedKeysToCanonicalKeys.withLock { $0[lowercasedKey] = canonicalKey }
    return canonicalKey
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
