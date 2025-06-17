import Foundation

/// A protocol that allows an `Encodable` type to specify a custom `JSONEncoder` for encoding.
public protocol EncodableWithEncoder: Encodable {
    /// The `JSONEncoder` to use for encoding.
    static var encoder: JSONEncoder { get }
}

extension EncodableWithEncoder {
    public func encode() throws -> Data {
        try Self.encoder.encode(self)
    }
}

/// A protocol that allows a `Decodable` type to specify a custom `JSONDecoder` for decoding.
public protocol DecodableWithDecoder: Decodable {
    /// The `JSONDecoder` to use for decoding.
    static var decoder: JSONDecoder { get }
}

extension DecodableWithDecoder {
    public static func decode(from data: Data) throws -> Self {
        try Self.decoder.decode(Self.self, from: data)
    }
}

/// A protocol that allows a `Codable` type to specify a custom `JSONEncoder` and `JSONDecoder` for encoding and decoding.
public typealias CodableWithCoder = EncodableWithEncoder & DecodableWithDecoder
