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
public struct FormData: Sendable {
  /// The boundary string used to separate form parts
  private var boundary: String
  /// Internal storage for all form parts
  var bodyParts: [BodyPart] = []

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
    if let boundary {
      self.boundary = boundary
    } else {
      let first = UInt32.random(in: UInt32.min...UInt32.max)
      let second = UInt32.random(in: UInt32.min...UInt32.max)
      self.boundary = String(format: "dev.grds.fetch.boundary.%08x%08x", first, second)
    }
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
  public mutating func append(
    _ name: String,
    _ value: Any,
    filename: String? = nil,
    contentType: String? = nil
  ) throws {
    let data: Data

    var filename = filename
    var contentType = contentType

    switch value {
    case let d as Data:
      data = d
    case let str as String:
      data = Data(str.utf8)
    case let url as URL:
      if contentType == nil {
        contentType = FormData.mimeType(forPathExtension: url.pathExtension)
      }

      if filename == nil {
        filename = url.lastPathComponent
      }

      data = try Data(contentsOf: url)
    case let searchParams as URLSearchParams:
      data = Data(searchParams.description.utf8)
    case let value as any EncodableWithEncoder:
      data = try value.encode()
    case let value as any Encodable:
      data = try JSONEncoder().encode(value)
    default:
      if JSONSerialization.isValidJSONObject(value) {
        data = try JSONSerialization.data(withJSONObject: value)
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

    let bodyPart = BodyPart(headers: headers, data: data)
    bodyParts.append(bodyPart)
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
  public func encode() -> Data {
    var data = Data()

    for bodyPart in bodyParts {
      data.append("--\(boundary)\r\n".data(using: .utf8)!)
      for field in bodyPart.headers {
        data.append("\(field.key): \(field.value)\r\n".data(using: .utf8)!)
      }
      data.append("\r\n".data(using: .utf8)!)
      data.append(bodyPart.data)
      data.append("\r\n".data(using: .utf8)!)
    }

    data.append("--\(boundary)--\r\n".data(using: .utf8)!)
    return data
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

  /// Represents a single part within the multipart form data.
  /// Each part consists of headers and binary data content.
  struct BodyPart {
    /// The headers for this part (Content-Disposition, Content-Type, etc.)
    let headers: HTTPHeaders
    /// The binary data content for this part
    let data: Data
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
    var formData = FormData()
    formData.boundary = boundary

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
      let bodyPart = BodyPart(headers: headers, data: Data(contentData))
      formData.bodyParts.append(bodyPart)
    }

    return formData
  }
}

/// Errors that can occur during FormData operations.
/// 
/// These errors are thrown when parsing or encoding multipart form data fails.
enum FormDataError: Error {
  /// The Content-Type header is missing the required boundary parameter
  case missingBoundary
  /// The data cannot be decoded with the expected text encoding
  case invalidEncoding
  /// The multipart structure is malformed or doesn't follow RFC 2388
  case malformedContent
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
