import Foundation

/// A structure for creating and encoding multipart/form-data content.
///
/// `FormData` is commonly used for file uploads and complex form submissions
/// in HTTP requests. It automatically handles boundary generation, content-type
/// detection, and proper multipart encoding according to RFC 2388.
///
/// Example:
/// ```swift
/// var formData = FormData()
/// formData.append("username", "john_doe")
/// formData.append("avatar", avatarData, filename: "avatar.jpg", contentType: "image/jpeg")
///
/// let options = FetchOptions(method: .post, body: formData)
/// let response = try await fetch("https://api.example.com/upload", options: options)
/// ```
public final class FormData: Sendable {
  /// The boundary string used to separate form parts
  private let boundary: String
  /// Internal storage for all form parts
  private let bodyParts = Mutex<[BodyPart]>([])

  /// Initializes a new FormData instance.
  ///
  /// The boundary is used to separate different parts of the multipart form data.
  /// If no boundary is provided, a random one will be generated.
  ///
  /// - Parameter boundary: Custom boundary string (default: auto-generated)
  ///
  /// Example:
  /// ```swift
  /// let formData = FormData()
  /// // or with custom boundary
  /// let customFormData = FormData(boundary: "my-custom-boundary")
  /// ```
  public init(boundary: String? = nil) {
    self.boundary = boundary ?? BoundaryGenerator.randomBoundary()
  }

  /// Adds a new part to the multipart form data.
  ///
  /// This method supports various value types and automatically handles encoding
  /// and content-type detection. For file uploads, provide a filename to trigger
  /// proper file upload headers.
  ///
  /// - Parameters:
  ///   - name: The name of the form field
  ///   - value: The value to include. Supported types:
  ///     - `String`: Text content
  ///     - `Data`: Binary data
  ///     - `URL`: File from local filesystem
  ///     - `URLSearchParams`: URL-encoded parameters
  ///     - `Encodable`: Objects encoded as JSON
  ///     - Dictionary/Array: Valid JSON objects
  ///   - filename: Optional filename for file uploads (auto-detected for URL values)
  ///   - contentType: Optional MIME type (auto-detected when possible)
  /// - Throws: An error if the value cannot be converted to Data
  ///
  /// Example:
  /// ```swift
  /// var formData = FormData()
  ///
  /// // Simple text field
  /// try formData.append("username", "john_doe")
  ///
  /// // File upload
  /// try formData.append("avatar", avatarURL)
  ///
  /// // Binary data with explicit content type
  /// try formData.append("data", binaryData, filename: "file.bin", contentType: "application/octet-stream")
  ///
  /// // JSON object
  /// try formData.append("metadata", ["key": "value"])
  /// ```
  public func append(
    _ name: String,
    _ value: Any,
    filename: String? = nil,
    contentType: String? = nil
  ) throws {
    let stream: InputStream
    let contentLength: UInt64

    var filename = filename
    var contentType = contentType

    switch value {
    case let data as Data:
      stream = InputStream(data: data)
      contentLength = UInt64(data.count)
    case let str as String:
      let data = Data(str.utf8)
      stream = InputStream(data: data)
      contentLength = UInt64(data.count)
    case let url as URL:
      if contentType == nil {
        contentType = FormData.mimeType(forPathExtension: url.pathExtension)
      }

      if filename == nil {
        filename = url.lastPathComponent
      }

      guard url.isFileURL else {
        throw FormDataError("The URL is not a file URL: \(url)")
      }

      #if !(os(Linux) || os(Windows) || os(Android))
        let isReachable = try url.checkPromisedItemIsReachable()
        guard isReachable else {
          throw FormDataError("The file is not reachable: \(url)")
        }
      #endif

      var isDirectory: ObjCBool = false
      let path = url.path

      guard
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
          && !isDirectory.boolValue
      else {
        throw FormDataError("The file is a directory: \(url)")
      }

      guard
        let fileSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber
      else {
        throw FormDataError("The file size is not available: \(url)")
      }

      contentLength = fileSize.uint64Value

      guard let inputStream = InputStream(url: url) else {
        throw FormDataError("Failed to create input stream from URL: \(url)")
      }

      stream = inputStream

    case let searchParams as URLSearchParams:
      let data = Data(searchParams.description.utf8)
      stream = InputStream(data: data)
      contentLength = UInt64(data.count)
    case let value as any EncodableWithEncoder:
      let data = try value.encode()
      stream = InputStream(data: data)
      contentLength = UInt64(data.count)
    case let value as any Encodable:
      let data = try JSONEncoder().encode(value)
      stream = InputStream(data: data)
      contentLength = UInt64(data.count)
    default:
      if JSONSerialization.isValidJSONObject(value) {
        let data = try JSONSerialization.data(withJSONObject: value)
        stream = InputStream(data: data)
        contentLength = UInt64(data.count)
      } else {
        fatalError("Unsupported value type for form data: \(type(of: value))")
      }
    }

    // no content type provided, try to extract it from the filename.
    if contentType == nil, let filename {
      contentType = FormData.mimeType(forPathExtension: (filename as NSString).pathExtension)
    }

    let headers = createHeaders(
      name: name,
      filename: filename,
      contentType: contentType
    )

    let bodyPart = BodyPart(headers: headers, bodyStream: stream, bodyContentLength: contentLength)
    bodyParts.withLock { $0.append(bodyPart) }
  }

  /// Encodes the multipart form data into a single Data object.
  ///
  /// This method combines all added parts with appropriate headers and boundaries
  /// according to the multipart/form-data specification (RFC 2388).
  ///
  /// - Returns: A Data object containing the complete encoded form data
  ///
  /// Example:
  /// ```swift
  /// var formData = FormData()
  /// try formData.append("field", "value")
  /// let encodedData = formData.encode()
  /// ```
  public func encode() throws -> Data {
    var encoded = Data()

    try bodyParts.withLock { parts in
      parts.first?.hasInitialBoundary = true
      parts.last?.hasFinalBoundary = true

      for bodyPart in parts {
        let encodedData = try encode(bodyPart)
        encoded.append(encodedData)
      }
    }

    return encoded
  }

  /// Returns the Content-Type header value for this multipart form data.
  ///
  /// This property provides the complete Content-Type header value including
  /// the boundary parameter, ready to be used in HTTP requests.
  ///
  /// Example:
  /// ```swift
  /// let formData = FormData()
  /// let contentType = formData.contentType
  /// // "multipart/form-data; boundary=dev.grds.fetch.boundary.12345678"
  /// ```
  public var contentType: String {
    "multipart/form-data; boundary=\(boundary)"
  }

  /// Creates appropriate headers for a form part.
  ///
  /// This method generates the Content-Disposition and Content-Type headers
  /// for each part of the multipart form data.
  ///
  /// - Parameters:
  ///   - name: The form field name
  ///   - filename: Optional filename for file uploads
  ///   - contentType: Optional MIME type
  /// - Returns: HTTPHeaders with appropriate disposition and type headers
  private func createHeaders(
    name: String,
    filename: String?,
    contentType: String?
  ) -> HTTPHeaders {
    var headers = HTTPHeaders()

    var disposition = "form-data; name=\"\(name)\""
    if let filename = filename {
      disposition += "; filename=\"\(filename)\""
    }
    headers["Content-Disposition"] = disposition

    if let contentType = contentType {
      headers["Content-Type"] = contentType
    }

    return headers
  }

  private enum EncodingCharacters {
    static let crlf = "\r\n"
  }

  private enum BoundaryGenerator {
    enum BoundaryType {
      case initial, encapsulated, final
    }

    static func randomBoundary() -> String {
      let first = UInt32.random(in: UInt32.min...UInt32.max)
      let second = UInt32.random(in: UInt32.min...UInt32.max)

      return String(format: "dev.grds.fetch.boundary.%08x%08x", first, second)
    }

    static func boundaryData(forBoundaryType boundaryType: BoundaryType, boundary: String) -> Data {
      let boundaryText =
        switch boundaryType {
        case .initial:
          "--\(boundary)\(EncodingCharacters.crlf)"
        case .encapsulated:
          "\(EncodingCharacters.crlf)--\(boundary)\(EncodingCharacters.crlf)"
        case .final:
          "\(EncodingCharacters.crlf)--\(boundary)--\(EncodingCharacters.crlf)"
        }

      return Data(boundaryText.utf8)
    }
  }

  /// Represents a single part within the multipart form data.
  /// Each part consists of headers and a stream of the body content.
  final class BodyPart {
    /// The headers for this part (Content-Disposition, Content-Type, etc.)
    let headers: HTTPHeaders
    /// The stream of the body content for this part
    let bodyStream: InputStream
    /// The length of the body content for this part
    let bodyContentLength: UInt64

    var hasInitialBoundary: Bool = false
    var hasFinalBoundary: Bool = false

    init(headers: HTTPHeaders, bodyStream: InputStream, bodyContentLength: UInt64) {
      self.headers = headers
      self.bodyStream = bodyStream
      self.bodyContentLength = bodyContentLength
    }
  }

  private func encode(_ bodyPart: BodyPart) throws -> Data {
    var encoded = Data()

    let initialData =
      bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulatedBoundaryData()
    encoded.append(initialData)

    let headerData = encodeHeaders(for: bodyPart)
    encoded.append(headerData)

    let bodyStreamData = try encodeBodyStream(for: bodyPart)
    encoded.append(bodyStreamData)

    if bodyPart.hasFinalBoundary {
      encoded.append(finalBoundaryData())
    }

    return encoded
  }

  private func encodeHeaders(for bodyPart: BodyPart) -> Data {
    let headerText =
      bodyPart.headers.map { "\($0.key): \($0.value)\(EncodingCharacters.crlf)" }
      .joined()
      + EncodingCharacters.crlf

    return Data(headerText.utf8)
  }

  private func encodeBodyStream(for bodyPart: BodyPart) throws -> Data {
    let inputStream = bodyPart.bodyStream
    inputStream.open()
    defer { inputStream.close() }

    var encoded = Data()

    while inputStream.hasBytesAvailable {
      //
      // The optimal read/write buffer size in bytes for input and output streams is 1024 (1KB). For more
      // information, please refer to the following article:
      //   - https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Streams/Articles/ReadingInputStreams.html
      //
      var buffer = [UInt8](repeating: 0, count: 1024)
      let bytesRead = inputStream.read(&buffer, maxLength: 1024)

      if let error = inputStream.streamError {
        throw FormDataError("Failed to read from input stream: \(error)")
      }

      if bytesRead > 0 {
        encoded.append(buffer, count: bytesRead)
      } else {
        break
      }
    }

    guard UInt64(encoded.count) == bodyPart.bodyContentLength else {
      throw FormDataError(
        "Unexpected input stream length: expected \(bodyPart.bodyContentLength) bytes, got \(encoded.count)"
      )
    }

    return encoded
  }

  private func initialBoundaryData() -> Data {
    BoundaryGenerator.boundaryData(forBoundaryType: .initial, boundary: boundary)
  }

  private func encapsulatedBoundaryData() -> Data {
    BoundaryGenerator.boundaryData(forBoundaryType: .encapsulated, boundary: boundary)
  }

  private func finalBoundaryData() -> Data {
    BoundaryGenerator.boundaryData(forBoundaryType: .final, boundary: boundary)
  }

}

extension FormData {
  /// Decodes a FormData instance from raw multipart form data.
  ///
  /// This static method parses multipart/form-data according to RFC 2388,
  /// extracting the boundary from the Content-Type header and parsing
  /// individual parts with their headers and content.
  ///
  /// - Parameters:
  ///   - data: The raw multipart form data to decode
  ///   - contentType: The Content-Type header value containing the boundary
  /// - Returns: A decoded FormData instance with all parts
  /// - Throws: `FormDataError` if the data is malformed or boundary is missing
  ///
  /// Example:
  /// ```swift
  /// let contentType = "multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW"
  /// let formData = try FormData.decode(from: rawData, contentType: contentType)
  /// ```
  static func decode(from data: Data, contentType: String) throws -> FormData {
    // Extract boundary from content type
    guard let boundary = contentType.components(separatedBy: "boundary=").last else {
      throw FormDataError.missingBoundary
    }

    // Create FormData instance with the extracted boundary
    let formData = FormData(boundary: boundary)

    // Convert boundary to Data for binary search
    let boundaryData = "--\(boundary)".data(using: .utf8)!
    let crlfData = "\r\n".data(using: .utf8)!
    let doubleCrlfData = "\r\n\r\n".data(using: .utf8)!

    // Find all boundary positions
    var currentIndex = data.startIndex
    var parts: [(start: Int, end: Int)] = []
    while let boundaryRange = data[currentIndex...].range(of: boundaryData) {
      let partStart = boundaryRange.endIndex
      currentIndex = partStart

      // Skip if this is the final boundary
      if let dashRange = data[currentIndex...].range(of: "--".data(using: .utf8)!) {
        if dashRange.lowerBound == currentIndex {
          break
        }
      }

      // Find the next boundary
      if let nextBoundaryRange = data[currentIndex...].range(of: boundaryData) {
        let partEnd = nextBoundaryRange.lowerBound - crlfData.count
        if partStart < partEnd {
          parts.append((start: partStart, end: partEnd))
        }
        currentIndex = nextBoundaryRange.lowerBound
      }
    }

    // Process each part
    for part in parts {
      let partData = data[part.start..<part.end]

      // Find headers section
      guard let headersSeparator = partData.range(of: doubleCrlfData) else { continue }
      let headersData = partData[..<headersSeparator.lowerBound]

      // Parse headers (headers are always UTF-8)
      guard let headersString = String(data: headersData, encoding: .utf8) else { continue }
      var headers = HTTPHeaders()

      let headerLines = headersString.components(separatedBy: "\r\n")
      for line in headerLines {
        let headerParts = line.split(separator: ":", maxSplits: 1).map(String.init)
        guard headerParts.count == 2 else { continue }
        headers[headerParts[0].trimmingCharacters(in: .whitespaces)] =
          headerParts[1].trimmingCharacters(in: .whitespaces)
      }

      // Extract content (binary data)
      let contentStart = headersSeparator.upperBound
      let contentData = partData[contentStart...]

      // Create body part with raw data
      let contentDataBytes = Data(contentData)
      let bodyPart = BodyPart(
        headers: headers,
        bodyStream: InputStream(data: contentDataBytes),
        bodyContentLength: UInt64(contentDataBytes.count)
      )
      formData.bodyParts.withLock { $0.append(bodyPart) }
    }

    return formData
  }
}

/// Errors that can occur during FormData operations.
///
/// These errors are thrown when parsing or encoding multipart form data fails.
struct FormDataError: LocalizedError {
  var errorDescription: String?
  let underlyingError: Error?

  init(_ message: String, underlyingError: Error? = nil) {
    self.errorDescription = message
    self.underlyingError = underlyingError
  }

  /// The Content-Type header is missing the required boundary parameter
  static let missingBoundary = FormDataError(
    "The Content-Type header is missing the required boundary parameter")
  /// The data cannot be decoded with the expected text encoding
  static let invalidEncoding = FormDataError(
    "The data cannot be decoded with the expected text encoding")
  /// The multipart structure is malformed or doesn't follow RFC 2388
  static let malformedContent = FormDataError(
    "The multipart structure is malformed or doesn't follow RFC 2388")
}

#if canImport(UniformTypeIdentifiers)
  import UniformTypeIdentifiers

  #if canImport(CoreServices)
    import CoreServices
  #endif

  #if canImport(MobileCoreServices)
    import MobileCoreServices
  #endif

  extension FormData {
    /// Determines the MIME type based on the file extension.
    ///
    /// This method uses the system's type identification services to determine
    /// the appropriate MIME type for a given file extension. It prefers
    /// UniformTypeIdentifiers on newer platforms, falling back to CoreServices
    /// or MobileCoreServices on older platforms.
    ///
    /// - Parameter pathExtension: The file extension (without the dot)
    /// - Returns: The MIME type string (defaults to "application/octet-stream")
    ///
    /// Example:
    /// ```swift
    /// let mimeType = FormData.mimeType(forPathExtension: "jpg")
    /// // Returns "image/jpeg"
    /// ```
    package static func mimeType(forPathExtension pathExtension: String) -> String {
      if #available(iOS 14, macOS 11, tvOS 14, watchOS 7, visionOS 1, *) {
        return UTType(filenameExtension: pathExtension)?.preferredMIMEType
          ?? "application/octet-stream"
      } else {
        if let id = UTTypeCreatePreferredIdentifierForTag(
          kUTTagClassFilenameExtension,
          pathExtension as CFString,
          nil
        )?.takeRetainedValue(),
          let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?
            .takeRetainedValue()
        {
          return contentType as String
        }

        return "application/octet-stream"
      }
    }
  }
#else
  extension FormData {
    /// Determines the MIME type based on the file extension.
    ///
    /// This fallback implementation is used on platforms where UniformTypeIdentifiers
    /// is not available. It uses CoreServices or MobileCoreServices when available.
    ///
    /// - Parameter pathExtension: The file extension (without the dot)
    /// - Returns: The MIME type string (defaults to "application/octet-stream")
    package static func mimeType(forPathExtension pathExtension: String) -> String {
      #if canImport(CoreServices) || canImport(MobileCoreServices)
        if let id = UTTypeCreatePreferredIdentifierForTag(
          kUTTagClassFilenameExtension,
          pathExtension as CFString,
          nil
        )?.takeRetainedValue(),
          let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?
            .takeRetainedValue()
        {
          return contentType as String
        }
      #endif

      return "application/octet-stream"
    }
  }
#endif
