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

public struct FetchOptions: Sendable {
    public var method: HTTPMethod
    public var headers: HTTPHeaders
    public var body: Data?
    public var cachePolicy: URLRequest.CachePolicy
    public var timeoutInterval: TimeInterval

    public init(
        method: HTTPMethod = .get,
        headers: HTTPHeaders = HTTPHeaders(),
        body: Data? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeoutInterval: TimeInterval = 60.0
    ) {
        self.method = method
        self.headers = headers
        self.body = body
        self.cachePolicy = cachePolicy
        self.timeoutInterval = timeoutInterval
    }
}

public struct Response: Sendable {
    public let url: URL?
    public let status: Int
    public let headers: [String: String]
    public let body: any Body

    public typealias Body = AsyncSequence<UInt8, any Error> & Sendable

    public init(url: URL?, status: Int, headers: [String: String], body: any Body) {
        self.url = url
        self.status = status
        self.headers = headers
        self.body = body
    }

    /// Returns the response body as a `Data` object.
    ///
    /// - Returns: The response body as a `Data` object.
    /// - Throws: An error if the response body cannot be converted to a `Data` object.
    public func blob() async throws -> Data {
        var data = Data()
        for try await byte in body {
            data.append(byte)
        }
        return data
    }

    /// Returns the response body as a `JSON` object.
    ///
    /// - Returns: The response body as a `JSON` object.
    /// - Throws: An error if the response body cannot be converted to a `JSON` object.
    public func json() async throws -> Any {
        return try JSONSerialization.jsonObject(with: try await blob())
    }

    /// Returns the response body as a `Decodable` object.
    ///
    /// - Returns: The response body as a `Decodable` object.
    /// - Throws: An error if the response body cannot be converted to a `Decodable` object.
    public func json<T: Decodable>() async throws -> T {
        return try JSONDecoder().decode(T.self, from: try await blob())
    }

    /// Returns the response body as a `String` object.
    ///
    /// - Returns: The response body as a `String` object.
    /// - Throws: An error if the response body cannot be converted to a `String` object.
    public func text() async throws -> String {
        guard let string = String(data: try await blob(), encoding: .utf8) else {
            throw NSError(
                domain: "Fetch", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not decode response as UTF-8 string"])
        }
        return string
    }
}

public let fetch = Fetch()

public actor Fetch: Sendable {
    let session: URLSession

    public init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    public func callAsFunction(
        _ url: URL,
        options: FetchOptions = FetchOptions()
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = options.method.rawValue
        request.allHTTPHeaderFields = options.headers.dictionary
        request.httpBody = options.body
        request.cachePolicy = options.cachePolicy
        request.timeoutInterval = options.timeoutInterval

        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "Fetch", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }

        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) {
            result, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                result[key] = value
            }
        }

        return Response(
            url: httpResponse.url,
            status: httpResponse.statusCode,
            headers: headers,
            body: bytes
        )
    }

    public func callAsFunction(
        _ urlString: String,
        options: FetchOptions = FetchOptions()
    ) async throws -> Response {
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "Fetch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        return try await self(url, options: options)
    }
}
