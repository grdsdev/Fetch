import Foundation

/// A protocol that allows an `Encodable` type to specify a custom `JSONEncoder` for encoding.
///
/// Types conforming to this protocol can provide their own JSON encoder configuration,
/// which is useful when you need specific encoding settings like custom date formats,
/// key encoding strategies, or output formatting.
///
/// Example:
/// ```swift
/// struct APIRequest: EncodableWithEncoder {
///   let timestamp: Date
///   let userId: String
///
///   static var encoder: JSONEncoder {
///     let encoder = JSONEncoder()
///     encoder.dateEncodingStrategy = .iso8601
///     encoder.keyEncodingStrategy = .convertToSnakeCase
///     return encoder
///   }
/// }
///
/// let request = APIRequest(timestamp: Date(), userId: "123")
/// let data = try request.encode()
/// ```
public protocol EncodableWithEncoder: Encodable {
  /// The custom `JSONEncoder` instance to use for encoding this type.
  ///
  /// Implement this property to return a configured encoder with your desired settings.
  /// The encoder will be used whenever this type needs to be encoded to JSON data.
  ///
  /// Example:
  /// ```swift
  /// static var encoder: JSONEncoder {
  ///   let encoder = JSONEncoder()
  ///   encoder.outputFormatting = .prettyPrinted
  ///   encoder.dateEncodingStrategy = .iso8601
  ///   return encoder
  /// }
  /// ```
  static var encoder: JSONEncoder { get }
}

extension EncodableWithEncoder {
  /// Encodes this instance to JSON data using the custom encoder.
  ///
  /// This method uses the encoder provided by the `encoder` static property
  /// to convert the instance to JSON data.
  ///
  /// - Returns: The JSON data representation of this instance
  /// - Throws: An `EncodingError` if the instance cannot be encoded
  ///
  /// Example:
  /// ```swift
  /// let request = APIRequest(timestamp: Date(), userId: "123")
  /// let jsonData = try request.encode()
  /// ```
  public func encode() throws -> Data {
    try Self.encoder.encode(self)
  }
}

/// A protocol that allows a `Decodable` type to specify a custom `JSONDecoder` for decoding.
///
/// Types conforming to this protocol can provide their own JSON decoder configuration,
/// which is useful when you need specific decoding settings like custom date formats,
/// key decoding strategies, or error handling.
///
/// Example:
/// ```swift
/// struct APIResponse: DecodableWithDecoder {
///   let createdAt: Date
///   let userId: String
///
///   static var decoder: JSONDecoder {
///     let decoder = JSONDecoder()
///     decoder.dateDecodingStrategy = .iso8601
///     decoder.keyDecodingStrategy = .convertFromSnakeCase
///     return decoder
///   }
/// }
///
/// let response = try APIResponse.decode(from: jsonData)
/// ```
public protocol DecodableWithDecoder: Decodable {
  /// The custom `JSONDecoder` instance to use for decoding this type.
  ///
  /// Implement this property to return a configured decoder with your desired settings.
  /// The decoder will be used whenever this type needs to be decoded from JSON data.
  ///
  /// Example:
  /// ```swift
  /// static var decoder: JSONDecoder {
  ///   let decoder = JSONDecoder()
  ///   decoder.dateDecodingStrategy = .iso8601
  ///   decoder.keyDecodingStrategy = .convertFromSnakeCase
  ///   return decoder
  /// }
  /// ```
  static var decoder: JSONDecoder { get }
}

extension DecodableWithDecoder {
  /// Decodes an instance of this type from JSON data using the custom decoder.
  ///
  /// This method uses the decoder provided by the `decoder` static property
  /// to convert JSON data into an instance of this type.
  ///
  /// - Parameter data: The JSON data to decode
  /// - Returns: A decoded instance of this type
  /// - Throws: A `DecodingError` if the data cannot be decoded
  ///
  /// Example:
  /// ```swift
  /// let jsonData = Data('{"created_at":"2023-01-01T00:00:00Z","user_id":"123"}'.utf8)
  /// let response = try APIResponse.decode(from: jsonData)
  /// ```
  public static func decode(from data: Data) throws -> Self {
    try Self.decoder.decode(Self.self, from: data)
  }
}

/// A convenience typealias for types that need both custom encoding and decoding.
///
/// `CodableWithCoder` combines both `EncodableWithEncoder` and `DecodableWithDecoder`,
/// allowing a type to specify custom JSON encoder and decoder configurations.
///
/// Example:
/// ```swift
/// struct APIModel: CodableWithCoder {
///   let createdAt: Date
///   let userId: String
///
///   static var encoder: JSONEncoder {
///     let encoder = JSONEncoder()
///     encoder.dateEncodingStrategy = .iso8601
///     encoder.keyEncodingStrategy = .convertToSnakeCase
///     return encoder
///   }
///
///   static var decoder: JSONDecoder {
///     let decoder = JSONDecoder()
///     decoder.dateDecodingStrategy = .iso8601
///     decoder.keyDecodingStrategy = .convertFromSnakeCase
///     return decoder
///   }
/// }
///
/// // Usage in requests and responses
/// let model = APIModel(createdAt: Date(), userId: "123")
/// let data = try model.encode()
/// let decoded = try APIModel.decode(from: data)
/// ```
public typealias CodableWithCoder = EncodableWithEncoder & DecodableWithDecoder
