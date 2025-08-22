import Foundation

// MARK: - FormData
//
// Note: This implementation is heavily inspired by Alamofire's MultipartFormData:
// https://github.com/Alamofire/Alamofire/blob/master/Source/Features/MultipartFormData.swift

/// A class for creating and encoding multipart/form-data content.
///
/// `FormData` is commonly used for file uploads and complex form submissions
/// in HTTP requests. It automatically handles boundary generation, content-type
/// detection, and proper multipart encoding according to RFC 2388.
///
/// **Error Handling**: The `append` method captures errors internally and defers
/// their throwing until `encode()` is called. This allows for better error
/// aggregation and more predictable error handling patterns. Errors from multiple
/// append operations are collected and thrown together during encoding.
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

  // MARK: - Properties

  /// Default memory threshold used when encoding `FormData`, in bytes.
  public static let encodingMemoryThreshold: UInt64 = 10_000_000

  /// The boundary string used to separate form parts
  private let boundary: String
  /// Internal storage for all form parts and error state
  internal let mutableState = Mutex(MutablesState())

  /// Encapsulates the mutable state of FormData including body parts and error handling
  struct MutablesState {
    /// Collection of all form data parts
    var bodyParts: [BodyPart] = []
    /// Captured error from append operations, thrown during encode()
    var bodyPartError: (any Error)?
  }

  // MARK: - Initialization

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

  // MARK: - Public Interface

  /// Adds a new part to the multipart form data.
  ///
  /// This method supports various value types and automatically handles encoding
  /// and content-type detection. For file uploads, provide a filename to trigger
  /// proper file upload headers.
  ///
  /// **Error Handling**: Errors are captured internally and will be thrown when
  /// `encode()` is called. This allows for better error aggregation across
  /// multiple append operations.
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
  ///
  /// Example:
  /// ```swift
  /// var formData = FormData()
  ///
  /// // Simple text field
  /// formData.append("username", "john_doe")
  ///
  /// // File upload
  /// formData.append("avatar", avatarURL)
  ///
  /// // Binary data with explicit content type
  /// formData.append("data", binaryData, filename: "file.bin", contentType: "application/octet-stream")
  ///
  /// // JSON object
  /// formData.append("metadata", ["key": "value"])
  ///
  /// // Errors are thrown during encode()
  /// do {
  ///   let encodedData = try formData.encode()
  /// } catch {
  ///   // Handle any errors from append operations
  /// }
  /// ```
  public func append(
    _ name: String,
    _ value: Any,
    filename: String? = nil,
    contentType: String? = nil
  ) {
    do {
      let processedValue = try ValueProcessor.process(value)
      let finalFilename = filename ?? processedValue.filename
      let finalContentType =
        contentType ?? processedValue.contentType
        ?? Self.mimeType(forPathExtension: (finalFilename as NSString?)?.pathExtension ?? "")

      let headers = createHeaders(
        name: name,
        filename: finalFilename,
        contentType: finalContentType
      )

      let bodyPart = BodyPart(
        headers: headers,
        bodyStream: processedValue.stream,
        bodyContentLength: processedValue.contentLength
      )

      mutableState.withLock { $0.bodyParts.append(bodyPart) }
    } catch {
      mutableState.withLock { $0.bodyPartError = error }
    }
  }

  /// Encodes the multipart form data into a single Data object.
  ///
  /// This method combines all added parts with appropriate headers and boundaries
  /// according to the multipart/form-data specification (RFC 2388).
  ///
  /// **Error Handling**: This method will throw any errors that occurred during
  /// previous `append` operations, allowing for deferred error handling.
  ///
  /// - Returns: A Data object containing the complete encoded form data
  /// - Throws: Any errors that occurred during `append` operations
  ///
  /// Example:
  /// ```swift
  /// var formData = FormData()
  /// formData.append("field", "value")
  ///
  /// do {
  ///   let encodedData = try formData.encode()
  /// } catch {
  ///   // Handle any errors from append operations
  /// }
  /// ```
  public func encode() throws -> Data {
    var encoded = Data()

    try mutableState.withLock { state in
      if let error = state.bodyPartError {
        throw error
      }

      let parts = state.bodyParts
      parts.first?.hasInitialBoundary = true
      parts.last?.hasFinalBoundary = true

      for bodyPart in parts {
        let encodedData = try encode(bodyPart)
        encoded.append(encodedData)
      }
    }

    return encoded
  }

  /// Writes all appended body parts to the given file `URL`.
  ///
  /// This process is facilitated by reading and writing with input and output streams, respectively. Thus,
  /// this approach is very memory efficient and should be used for large body part data.
  ///
  /// - Parameter fileURL: File `URL` to which to write the form data.
  public func writeEncodedData(to fileURL: URL) throws {
    try mutableState.withLock {
      if let error = $0.bodyPartError {
        throw error
      }

      if FileManager.default.fileExists(atPath: fileURL.path) {
        throw FormDataError("File already exists: \(fileURL)")
      } else if !fileURL.isFileURL {
        throw FormDataError("Invalid file URL: \(fileURL)")
      }

      guard let outputStream = OutputStream(url: fileURL, append: false) else {
        throw FormDataError("Failed to create output stream: \(fileURL)")
      }

      outputStream.open()
      defer { outputStream.close() }

      $0.bodyParts.first?.hasInitialBoundary = true
      $0.bodyParts.last?.hasFinalBoundary = true

      for bodyPart in $0.bodyParts {
        try write(bodyPart, to: outputStream)
      }
    }
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
}

// MARK: - Private Encoding Methods

extension FormData {

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

  /// Encodes a single body part with boundaries and headers.
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

  /// Encodes headers for a body part.
  private func encodeHeaders(for bodyPart: BodyPart) -> Data {
    let headerText =
      bodyPart.headers
      .map { "\($0.key): \($0.value)\(EncodingConstants.crlf)" }
      .joined() + EncodingConstants.crlf

    return Data(headerText.utf8)
  }

  /// Encodes the body stream for a body part.
  private func encodeBodyStream(for bodyPart: BodyPart) throws -> Data {
    let inputStream = bodyPart.bodyStream
    inputStream.open()
    defer { inputStream.close() }

    var encoded = Data()

    while inputStream.hasBytesAvailable {
      var buffer = [UInt8](repeating: 0, count: EncodingConstants.bufferSize)
      let bytesRead = inputStream.read(&buffer, maxLength: EncodingConstants.bufferSize)

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

  // MARK: - Boundary Data Methods

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

// MARK: - Private File Writing Methods

extension FormData {

  /// Writes a body part to the output stream.
  private func write(_ bodyPart: BodyPart, to outputStream: OutputStream) throws {
    try writeInitialBoundaryData(for: bodyPart, to: outputStream)
    try writeHeaderData(for: bodyPart, to: outputStream)
    try writeBodyStream(for: bodyPart, to: outputStream)
    try writeFinalBoundaryData(for: bodyPart, to: outputStream)
  }

  /// Writes initial boundary data for a body part.
  private func writeInitialBoundaryData(for bodyPart: BodyPart, to outputStream: OutputStream)
    throws
  {
    let initialData =
      bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulatedBoundaryData()
    return try write(initialData, to: outputStream)
  }

  /// Writes header data for a body part.
  private func writeHeaderData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
    let headerData = encodeHeaders(for: bodyPart)
    return try write(headerData, to: outputStream)
  }

  /// Writes body stream for a body part.
  private func writeBodyStream(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
    let inputStream = bodyPart.bodyStream

    inputStream.open()
    defer { inputStream.close() }

    var bytesLeftToRead = bodyPart.bodyContentLength
    while inputStream.hasBytesAvailable && bytesLeftToRead > 0 {
      let bufferSize = min(EncodingConstants.bufferSize, Int(bytesLeftToRead))
      var buffer = [UInt8](repeating: 0, count: bufferSize)
      let bytesRead = inputStream.read(&buffer, maxLength: bufferSize)

      if let streamError = inputStream.streamError {
        throw FormDataError("Failed to read from input stream: \(streamError)")
      }

      if bytesRead > 0 {
        if buffer.count != bytesRead {
          buffer = Array(buffer[0..<bytesRead])
        }

        try write(&buffer, to: outputStream)
        bytesLeftToRead -= UInt64(bytesRead)
      } else {
        break
      }
    }
  }

  /// Writes final boundary data for a body part.
  private func writeFinalBoundaryData(for bodyPart: BodyPart, to outputStream: OutputStream) throws
  {
    if bodyPart.hasFinalBoundary {
      try write(finalBoundaryData(), to: outputStream)
    }
  }

  // MARK: - Output Stream Writing Methods

  /// Writes data to the output stream.
  private func write(_ data: Data, to outputStream: OutputStream) throws {
    var buffer = [UInt8](repeating: 0, count: data.count)
    data.copyBytes(to: &buffer, count: data.count)

    return try write(&buffer, to: outputStream)
  }

  /// Writes buffer to the output stream.
  private func write(_ buffer: inout [UInt8], to outputStream: OutputStream) throws {
    var bytesToWrite = buffer.count

    while bytesToWrite > 0, outputStream.hasSpaceAvailable {
      let bytesWritten = outputStream.write(buffer, maxLength: bytesToWrite)

      if let error = outputStream.streamError {
        throw FormDataError("Failed to write to output stream: \(error)")
      }

      bytesToWrite -= bytesWritten

      if bytesToWrite > 0 {
        buffer = Array(buffer[bytesWritten..<buffer.count])
      }
    }
  }
}

// MARK: - BodyPart

extension FormData {
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
}

// MARK: - Constants

private enum EncodingConstants {
  static let crlf = "\r\n"
  static let bufferSize = 1024  // Optimal buffer size for input/output streams
}

// MARK: - Boundary Generator

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
        "--\(boundary)\(EncodingConstants.crlf)"
      case .encapsulated:
        "\(EncodingConstants.crlf)--\(boundary)\(EncodingConstants.crlf)"
      case .final:
        "\(EncodingConstants.crlf)--\(boundary)--\(EncodingConstants.crlf)"
      }

    return Data(boundaryText.utf8)
  }
}

// MARK: - Value Processor

private enum ValueProcessor {

  struct ProcessedValue {
    let stream: InputStream
    let contentLength: UInt64
    let filename: String?
    let contentType: String?
  }

  static func process(_ value: Any) throws -> ProcessedValue {
    switch value {
    case let data as Data:
      return ProcessedValue(
        stream: InputStream(data: data),
        contentLength: UInt64(data.count),
        filename: nil,
        contentType: nil
      )

    case let str as String:
      let data = Data(str.utf8)
      return ProcessedValue(
        stream: InputStream(data: data),
        contentLength: UInt64(data.count),
        filename: nil,
        contentType: nil
      )

    case let url as URL:
      return try processURL(url)

    case let searchParams as URLSearchParams:
      let data = Data(searchParams.description.utf8)
      return ProcessedValue(
        stream: InputStream(data: data),
        contentLength: UInt64(data.count),
        filename: nil,
        contentType: nil
      )

    case let value as any EncodableWithEncoder:
      let data = try value.encode()
      return ProcessedValue(
        stream: InputStream(data: data),
        contentLength: UInt64(data.count),
        filename: nil,
        contentType: nil
      )

    case let value as any Encodable:
      let data = try JSONEncoder().encode(value)
      return ProcessedValue(
        stream: InputStream(data: data),
        contentLength: UInt64(data.count),
        filename: nil,
        contentType: nil
      )

    default:
      if JSONSerialization.isValidJSONObject(value) {
        let data = try JSONSerialization.data(withJSONObject: value)
        return ProcessedValue(
          stream: InputStream(data: data),
          contentLength: UInt64(data.count),
          filename: nil,
          contentType: nil
        )
      } else {
        fatalError("Unsupported value type for form data: \(type(of: value))")
      }
    }
  }

  private static func processURL(_ url: URL) throws -> ProcessedValue {
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

    guard let fileSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber
    else {
      throw FormDataError("The file size is not available: \(url)")
    }

    guard let inputStream = InputStream(url: url) else {
      throw FormDataError("Failed to create input stream from URL: \(url)")
    }

    return ProcessedValue(
      stream: inputStream,
      contentLength: fileSize.uint64Value,
      filename: url.lastPathComponent,
      contentType: FormData.mimeType(forPathExtension: url.pathExtension)
    )
  }
}

// MARK: - Decoding Extension

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
    let decoder = FormDataDecoder()
    return try decoder.decode(from: data, contentType: contentType)
  }
}

// MARK: - FormData Decoder

private class FormDataDecoder {

  func decode(from data: Data, contentType: String) throws -> FormData {
    let boundary = try extractBoundary(from: contentType)
    let formData = FormData(boundary: boundary)

    let parts = try parseParts(from: data, boundary: boundary)

    for part in parts {
      let bodyPart = try createBodyPart(from: part)
      formData.mutableState.withLock { $0.bodyParts.append(bodyPart) }
    }

    return formData
  }

  private func extractBoundary(from contentType: String) throws -> String {
    guard contentType.contains("boundary="),
      let boundary = contentType.components(separatedBy: "boundary=").last,
      !boundary.isEmpty
    else {
      throw FormDataError.missingBoundary
    }
    return boundary
  }

  private func parseParts(from data: Data, boundary: String) throws -> [PartData] {
    let boundaryData = "--\(boundary)".data(using: .utf8)!
    let crlfData = "\r\n".data(using: .utf8)!
    let doubleCrlfData = "\r\n\r\n".data(using: .utf8)!

    var currentIndex = data.startIndex
    var parts: [PartData] = []

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
          let partData = data[partStart..<partEnd]
          if let part = parsePart(from: partData, doubleCrlfData: doubleCrlfData) {
            parts.append(part)
          }
        }
        currentIndex = nextBoundaryRange.lowerBound
      }
    }

    return parts
  }

  private func parsePart(from partData: Data, doubleCrlfData: Data) -> PartData? {
    guard let headersSeparator = partData.range(of: doubleCrlfData) else { return nil }

    let headersData = partData[..<headersSeparator.lowerBound]
    let contentStart = headersSeparator.upperBound
    let contentData = partData[contentStart...]

    guard let headers = parseHeaders(from: headersData) else { return nil }

    return PartData(headers: headers, content: Data(contentData))
  }

  private func parseHeaders(from headersData: Data) -> HTTPHeaders? {
    guard let headersString = String(data: headersData, encoding: .utf8) else { return nil }

    var headers = HTTPHeaders()
    let headerLines = headersString.components(separatedBy: "\r\n")

    for line in headerLines {
      let headerParts = line.split(separator: ":", maxSplits: 1).map(String.init)
      guard headerParts.count == 2 else { continue }

      let key = headerParts[0].trimmingCharacters(in: .whitespaces)
      let value = headerParts[1].trimmingCharacters(in: .whitespaces)
      headers[key] = value
    }

    return headers
  }

  private func createBodyPart(from part: PartData) throws -> FormData.BodyPart {
    return FormData.BodyPart(
      headers: part.headers,
      bodyStream: InputStream(data: part.content),
      bodyContentLength: UInt64(part.content.count)
    )
  }
}

private struct PartData {
  let headers: HTTPHeaders
  let content: Data
}

// MARK: - Errors

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

// MARK: - MIME Type Extensions

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
