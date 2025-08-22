import Foundation
import Testing

@testable import Fetch

struct FormDataTests {

  // MARK: - Initialization Tests

  @Test func testInitWithDefaultBoundary() {
    let formData = FormData()
    #expect(!formData.contentType.isEmpty)
    #expect(formData.contentType.contains("multipart/form-data"))
    #expect(formData.contentType.contains("boundary="))
  }

  @Test func testInitWithCustomBoundary() {
    let customBoundary = "custom-boundary-123"
    let formData = FormData(boundary: customBoundary)
    #expect(formData.contentType.contains(customBoundary))
  }

  // MARK: - Content Type Tests

  @Test func testContentTypeFormat() {
    let formData = FormData()
    let contentType = formData.contentType
    #expect(contentType.hasPrefix("multipart/form-data; boundary="))
  }

  // MARK: - String Value Tests

  @Test func testAppendString() throws {
    let formData = FormData()
    formData.append("username", "john_doe")

    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)

    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("john_doe"))
    #expect(encodedString.contains("name=\"username\""))
  }

  @Test func testAppendStringWithFilename() throws {
    let formData = FormData()
    formData.append("file", "content", filename: "test.txt")

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("filename=\"test.txt\""))
  }

  @Test func testAppendStringWithContentType() throws {
    let formData = FormData()
    formData.append("data", "content", contentType: "text/plain")

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("Content-Type: text/plain"))
  }

  // MARK: - Data Value Tests

  @Test func testAppendData() throws {
    let testData = "Hello, World!".data(using: .utf8)!
    let formData = FormData()
    formData.append("binary", testData)

    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)

    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("Hello, World!"))
  }

  @Test func testAppendDataWithFilenameAndContentType() throws {
    let testData = "Binary content".data(using: .utf8)!
    let formData = FormData()
    formData.append("file", testData, filename: "data.bin", contentType: "application/octet-stream")

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("filename=\"data.bin\""))
    #expect(encodedString.contains("Content-Type: application/octet-stream"))
  }

  // MARK: - URL Value Tests

  @Test func testAppendFileURL() throws {
    // Create a temporary file
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
    try "Test file content".write(to: tempURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let formData = FormData()
    formData.append("file", tempURL)

    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)

    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("Test file content"))
    #expect(encodedString.contains("filename=\"test.txt\""))
  }

  @Test func testAppendFileURLWithCustomFilename() throws {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("original.txt")
    try "Original content".write(to: tempURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let formData = FormData()
    formData.append("file", tempURL, filename: "custom.txt")

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("filename=\"custom.txt\""))
  }

  @Test func testAppendInvalidURL() {
    let formData = FormData()
    let invalidURL = URL(string: "https://example.com/file.txt")!

    formData.append("file", invalidURL)

    // Should not throw immediately, but should throw during encode
    do {
      _ = try formData.encode()
      #expect(Bool(false), "Should have thrown an error for invalid file URL")
    } catch {
      #expect(error.localizedDescription.contains("file URL"))
    }
  }

  // MARK: - URLSearchParams Tests

  @Test func testAppendURLSearchParams() throws {
    var params = URLSearchParams()
    params.append("key1", value: "value1")
    params.append("key2", value: "value2")

    let formData = FormData()
    formData.append("params", params)

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("key1=value1"))
    #expect(encodedString.contains("key2=value2"))
  }

  // MARK: - Encodable Tests

  @Test func testAppendEncodable() throws {
    struct TestStruct: Encodable {
      let name: String
      let age: Int
    }

    let testObject = TestStruct(name: "John", age: 30)
    let formData = FormData()
    formData.append("user", testObject)

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("John"))
    #expect(encodedString.contains("30"))
  }

  @Test func testAppendEncodableWithEncoder() throws {
    struct TestStruct: EncodableWithEncoder {
      let name: String
      let age: Int

      static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
      }
    }

    let testObject = TestStruct(name: "Jane", age: 25)
    let formData = FormData()
    formData.append("user", testObject)

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("Jane"))
    #expect(encodedString.contains("25"))
  }

  // MARK: - Dictionary and Array Tests

  @Test func testAppendDictionary() throws {
    let dict = ["name": "Alice", "city": "New York"]
    let formData = FormData()
    formData.append("data", dict)

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("Alice"))
    #expect(encodedString.contains("New York"))
  }

  @Test func testAppendArray() throws {
    let array = ["item1", "item2", "item3"]
    let formData = FormData()
    formData.append("items", array)

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("item1"))
    #expect(encodedString.contains("item2"))
    #expect(encodedString.contains("item3"))
  }

  // MARK: - Multiple Parts Tests

  @Test func testMultipleParts() throws {
    let formData = FormData()
    formData.append("name", "John Doe")
    formData.append("email", "john@example.com")
    formData.append("age", 30)

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("John Doe"))
    #expect(encodedString.contains("john@example.com"))
    #expect(encodedString.contains("30"))
  }

  @Test func testMixedContentTypes() throws {
    let formData = FormData()
    formData.append("text", "Hello World")
    formData.append("binary", "Binary data".data(using: .utf8)!, filename: "data.bin")

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("Hello World"))
    #expect(encodedString.contains("Binary data"))
    #expect(encodedString.contains("filename=\"data.bin\""))
  }

  // MARK: - Boundary Tests

  @Test func testBoundaryFormat() throws {
    let formData = FormData()
    formData.append("test", "value")

    let encoded = try formData.encode()
    let encodedString = String(data: encoded, encoding: .utf8)!

    // Should contain proper boundary format
    #expect(encodedString.contains("--"))
    #expect(encodedString.contains("\r\n"))
  }

  // MARK: - Error Handling Tests

  @Test func testDeferredErrorHandling() {
    let formData = FormData()

    // Append with invalid URL (should not throw immediately)
    let invalidURL = URL(string: "https://example.com/file.txt")!
    formData.append("file", invalidURL)

    // Should throw during encode
    do {
      _ = try formData.encode()
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      #expect(error.localizedDescription.contains("file URL"))
    }
  }

  @Test func testMultipleErrors() {
    let formData = FormData()

    // Add multiple invalid items
    let invalidURL = URL(string: "https://example.com/file.txt")!
    formData.append("file1", invalidURL)
    formData.append("file2", invalidURL)

    // Should throw during encode
    do {
      _ = try formData.encode()
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      #expect(error.localizedDescription.contains("file URL"))
    }
  }

  // MARK: - Empty FormData Tests

  @Test func testEmptyFormData() throws {
    let formData = FormData()
    let encoded = try formData.encode()
    #expect(encoded.isEmpty || encoded.count < 100)  // Should be minimal
  }

  // MARK: - MIME Type Tests

  @Test func testMimeTypeDetection() {
    #expect(FormData.mimeType(forPathExtension: "jpg") == "image/jpeg")
    #expect(FormData.mimeType(forPathExtension: "png") == "image/png")
    #expect(FormData.mimeType(forPathExtension: "pdf") == "application/pdf")
    #expect(FormData.mimeType(forPathExtension: "txt") == "text/plain")
    #expect(FormData.mimeType(forPathExtension: "unknown") == "application/octet-stream")
  }

  // MARK: - Decoding Tests

  @Test func testDecodeFormData() throws {
    // Create a simple form data
    let originalFormData = FormData()
    originalFormData.append("name", "Test User")
    originalFormData.append("email", "test@example.com")

    let encoded = try originalFormData.encode()
    let contentType = originalFormData.contentType

    // Decode it back
    let decodedFormData = try FormData.decode(from: encoded, contentType: contentType)

    // Verify the decoded data has the same content (headers might be formatted differently)
    let decodedEncoded = try decodedFormData.encode()
    let originalString = String(data: encoded, encoding: .utf8)!
    let decodedString = String(data: decodedEncoded, encoding: .utf8)!

    // Check that both contain the same field names and values
    #expect(originalString.contains("Test User"))
    #expect(decodedString.contains("Test User"))
    #expect(originalString.contains("test@example.com"))
    #expect(decodedString.contains("test@example.com"))
  }

  @Test func testDecodeWithFile() throws {
    // Create a temporary file
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("decode-test.txt")
    try "Decode test content".write(to: tempURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let originalFormData = FormData()
    originalFormData.append("file", tempURL)
    originalFormData.append("description", "Test file")

    let encoded = try originalFormData.encode()
    let contentType = originalFormData.contentType

    // Decode it back
    let decodedFormData = try FormData.decode(from: encoded, contentType: contentType)

    // Verify the decoded data has the same content
    let decodedEncoded = try decodedFormData.encode()
    let originalString = String(data: encoded, encoding: .utf8)!
    let decodedString = String(data: decodedEncoded, encoding: .utf8)!

    // Check that both contain the same content
    #expect(originalString.contains("Decode test content"))
    #expect(decodedString.contains("Decode test content"))
    #expect(originalString.contains("Test file"))
    #expect(decodedString.contains("Test file"))
  }

  @Test func testDecodeWithContentTypeMissingBoundary() {
    let data = Data()
    let contentTypeWithoutBoundary = "multipart/form-data"

    do {
      _ = try FormData.decode(from: data, contentType: contentTypeWithoutBoundary)
      #expect(Bool(false), "Should have thrown an error for missing boundary")
    } catch {
      #expect(
        error.localizedDescription.contains("boundary")
          || error.localizedDescription.contains("missing"))
    }
  }

  @Test func testDecodeWithInvalidBoundaryFormat() {
    let data = Data()
    let contentTypeWithInvalidBoundary = "multipart/form-data; boundary="

    do {
      _ = try FormData.decode(from: data, contentType: contentTypeWithInvalidBoundary)
      #expect(Bool(false), "Should have thrown an error for invalid boundary format")
    } catch {
      #expect(
        error.localizedDescription.contains("boundary")
          || error.localizedDescription.contains("missing"))
    }
  }

  // MARK: - Thread Safety Tests

  @Test func testConcurrentAppend() async throws {
    let formData = FormData()
    let iterations = 100

    await withTaskGroup(of: Void.self) { group in
      for i in 0..<iterations {
        group.addTask {
          formData.append("key\(i)", "value\(i)")
        }
      }
    }

    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)

    let encodedString = String(data: encoded, encoding: .utf8)!
    for i in 0..<iterations {
      #expect(encodedString.contains("key\(i)"))
      #expect(encodedString.contains("value\(i)"))
    }
  }

  // MARK: - Performance Tests

  @Test func testLargeDataAppend() throws {
    let formData = FormData()
    let largeData = Data(repeating: 0x42, count: 1024 * 1024)  // 1MB

    formData.append("large", largeData)

    let encoded = try formData.encode()
    #expect(encoded.count > largeData.count)  // Should be larger due to headers and boundaries
  }

  @Test func testManySmallParts() throws {
    let formData = FormData()
    let partCount = 1000

    for i in 0..<partCount {
      formData.append("part\(i)", "value\(i)")
    }

    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)

    let encodedString = String(data: encoded, encoding: .utf8)!
    for i in 0..<partCount {
      #expect(encodedString.contains("part\(i)"))
      #expect(encodedString.contains("value\(i)"))
    }
  }

  // MARK: - writeEncodedData Tests

  @Test func testWriteEncodedDataBasic() throws {
    let formData = FormData()
    formData.append("name", "John Doe")
    formData.append("email", "john@example.com")

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "test-form-data.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try formData.writeEncodedData(to: outputURL)

    // Verify file was created and contains expected content
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    let fileContent = try String(contentsOf: outputURL, encoding: .utf8)
    #expect(fileContent.contains("John Doe"))
    #expect(fileContent.contains("john@example.com"))
    #expect(fileContent.contains("name=\"name\""))
    #expect(fileContent.contains("name=\"email\""))
  }

  @Test func testWriteEncodedDataWithFile() throws {
    // Create a temporary input file
    let inputURL = FileManager.default.temporaryDirectory.appendingPathComponent("input.txt")
    try "File content for testing".write(to: inputURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: inputURL) }

    let formData = FormData()
    formData.append("file", inputURL)
    formData.append("description", "Test file upload")

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "output-form-data.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try formData.writeEncodedData(to: outputURL)

    // Verify file was created and contains expected content
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    let fileContent = try String(contentsOf: outputURL, encoding: .utf8)
    #expect(fileContent.contains("File content for testing"))
    #expect(fileContent.contains("Test file upload"))
    #expect(fileContent.contains("filename=\"input.txt\""))
  }

  @Test func testWriteEncodedDataWithLargeFile() throws {
    // Create a large temporary file
    let largeContent = String(repeating: "Large file content for testing. ", count: 10000)
    let inputURL = FileManager.default.temporaryDirectory.appendingPathComponent("large-input.txt")
    try largeContent.write(to: inputURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: inputURL) }

    let formData = FormData()
    formData.append("largeFile", inputURL)
    formData.append("metadata", "Large file metadata")

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "large-output.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try formData.writeEncodedData(to: outputURL)

    // Verify file was created and contains expected content
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    let fileContent = try String(contentsOf: outputURL, encoding: .utf8)
    #expect(fileContent.contains("Large file content for testing"))
    #expect(fileContent.contains("Large file metadata"))
    #expect(fileContent.contains("filename=\"large-input.txt\""))
  }

  @Test func testWriteEncodedDataWithBinaryData() throws {
    let binaryData = Data(repeating: 0x42, count: 1024)
    let formData = FormData()
    formData.append(
      "binary", binaryData, filename: "data.bin", contentType: "application/octet-stream")

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "binary-output.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try formData.writeEncodedData(to: outputURL)

    // Verify file was created and contains expected content
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    let fileContent = try String(contentsOf: outputURL, encoding: .utf8)
    #expect(fileContent.contains("filename=\"data.bin\""))
    #expect(fileContent.contains("Content-Type: application/octet-stream"))
  }

  @Test func testWriteEncodedDataWithMultipleParts() throws {
    let formData = FormData()
    formData.append("text1", "First text field")
    formData.append("text2", "Second text field")
    formData.append("number", 42)
    formData.append("array", ["item1", "item2", "item3"])

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "multiple-parts.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try formData.writeEncodedData(to: outputURL)

    // Verify file was created and contains expected content
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    let fileContent = try String(contentsOf: outputURL, encoding: .utf8)
    #expect(fileContent.contains("First text field"))
    #expect(fileContent.contains("Second text field"))
    #expect(fileContent.contains("42"))
    #expect(fileContent.contains("item1"))
    #expect(fileContent.contains("item2"))
    #expect(fileContent.contains("item3"))
  }

  @Test func testWriteEncodedDataEmptyFormData() throws {
    let formData = FormData()

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "empty-form-data.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try formData.writeEncodedData(to: outputURL)

    // Verify file was created (should be minimal content)
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
    let fileSize = fileAttributes[.size] as? Int ?? 0
    #expect(fileSize < 1000)  // Should be minimal size for empty form data
  }

  @Test func testWriteEncodedDataFileAlreadyExists() throws {
    let formData = FormData()
    formData.append("test", "value")

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "existing-file.txt")

    // Create the file first
    try "Existing content".write(to: outputURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: outputURL) }

    // Should throw an error when trying to write to existing file
    do {
      try formData.writeEncodedData(to: outputURL)
      #expect(Bool(false), "Should have thrown an error for existing file")
    } catch {
      #expect(error.localizedDescription.contains("already exists"))
    }
  }

  @Test func testWriteEncodedDataInvalidFileURL() {
    let formData = FormData()
    formData.append("test", "value")

    let invalidURL = URL(string: "https://example.com/file.txt")!

    // Should throw an error for invalid file URL
    do {
      try formData.writeEncodedData(to: invalidURL)
      #expect(Bool(false), "Should have thrown an error for invalid file URL")
    } catch {
      #expect(error.localizedDescription.contains("Invalid file URL"))
    }
  }

  @Test func testWriteEncodedDataWithAppendError() {
    let formData = FormData()

    // Add an invalid item that will cause an error during processing
    let invalidURL = URL(string: "https://example.com/file.txt")!
    formData.append("file", invalidURL)

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("error-test.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    // Should throw an error during write due to the invalid append
    do {
      try formData.writeEncodedData(to: outputURL)
      #expect(Bool(false), "Should have thrown an error for invalid append")
    } catch {
      #expect(error.localizedDescription.contains("file URL"))
    }
  }

  @Test func testWriteEncodedDataMemoryEfficiency() throws {
    // Create a large form data to test memory efficiency
    let formData = FormData()
    let largeData = Data(repeating: 0x42, count: 1024 * 1024)  // 1MB
    formData.append("large", largeData)
    formData.append("description", "Large data test")

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("memory-test.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    // This should complete without excessive memory usage
    try formData.writeEncodedData(to: outputURL)

    // Verify the file was created and has expected size
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
    let fileSize = fileAttributes[.size] as? Int ?? 0
    #expect(fileSize > largeData.count)  // Should be larger due to headers and boundaries
  }

  @Test func testWriteEncodedDataWithCustomBoundary() throws {
    let customBoundary = "custom-boundary-123"
    let formData = FormData(boundary: customBoundary)
    formData.append("test", "value")

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "custom-boundary.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try formData.writeEncodedData(to: outputURL)

    let fileContent = try String(contentsOf: outputURL, encoding: .utf8)
    #expect(fileContent.contains(customBoundary))
  }

  @Test func testWriteEncodedDataWithComplexData() throws {
    struct ComplexStruct: Encodable {
      let name: String
      let details: [String: String]
      let numbers: [Int]
    }

    let complexData = ComplexStruct(
      name: "Complex Test",
      details: ["key1": "value1", "key2": "value2"],
      numbers: [1, 2, 3, 4, 5]
    )

    let formData = FormData()
    formData.append("complex", complexData)
    formData.append("simple", "Simple string")

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "complex-data.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try formData.writeEncodedData(to: outputURL)

    let fileContent = try String(contentsOf: outputURL, encoding: .utf8)
    #expect(fileContent.contains("Complex Test"))
    #expect(fileContent.contains("Simple string"))
    #expect(fileContent.contains("key1"))
    #expect(fileContent.contains("value1"))
    #expect(fileContent.contains("1"))
    #expect(fileContent.contains("5"))
  }

  @Test func testWriteEncodedDataPermissions() throws {
    let formData = FormData()
    formData.append("test", "value")

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "permissions-test.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try formData.writeEncodedData(to: outputURL)

    // Verify file has appropriate permissions
    let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
    let permissions = fileAttributes[.posixPermissions] as? Int ?? 0

    // Should be readable and writable by owner
    #expect((permissions & 0o600) == 0o600 || (permissions & 0o644) == 0o644)
  }

  // MARK: - Large FormData Optimization Tests

  @Test func testEncodingMemoryThreshold() {
    // Test that the threshold is set to a reasonable value (10MB)
    #expect(FormData.encodingMemoryThreshold == 10_000_000)
  }

  @Test func testLargeFormDataContentLength() throws {
    // Create FormData with content that exceeds the threshold
    let formData = FormData()
    let largeData = Data(repeating: 0x42, count: 11_000_000)  // 11MB, exceeds 10MB threshold
    formData.append("large", largeData)

    // Verify content length is calculated correctly
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)
    #expect(formData.contentLength >= 11_000_000)
  }

  @Test func testSmallFormDataContentLength() throws {
    // Create FormData with content that doesn't exceed the threshold
    let formData = FormData()
    let smallData = Data(repeating: 0x42, count: 1_000_000)  // 1MB, below 10MB threshold
    formData.append("small", smallData)

    // Verify content length is calculated correctly
    #expect(formData.contentLength < FormData.encodingMemoryThreshold)
    #expect(formData.contentLength >= 1_000_000)
  }

  @Test func testFormDataWithMultipleLargeParts() throws {
    // Create FormData with multiple parts that together exceed the threshold
    let formData = FormData()
    let part1 = Data(repeating: 0x41, count: 6_000_000)  // 6MB
    let part2 = Data(repeating: 0x42, count: 5_000_000)  // 5MB
    formData.append("part1", part1)
    formData.append("part2", part2)

    // Total should be 11MB, exceeding the 10MB threshold
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)
    #expect(formData.contentLength >= 11_000_000)
  }

  @Test func testFormDataWithLargeFile() throws {
    // Create a large temporary file
    let largeContent = String(repeating: "Large file content for testing. ", count: 500_000)  // ~15MB
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "large-test-file.txt")
    try largeContent.write(to: tempURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let formData = FormData()
    formData.append("largeFile", tempURL)

    // Should exceed the threshold due to the large file
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)
  }

  @Test func testFormDataOptimizationIntegration() async throws {
    // Test the integration with FetchClient's optimization
    _ = FetchClient()  // Create instance to verify it can be instantiated

    // Create large FormData that should trigger optimization
    let formData = FormData()
    let largeData = Data(repeating: 0x42, count: 11_000_000)  // 11MB
    formData.append("large", largeData)
    formData.append("description", "Large data test")

    // Verify it exceeds threshold
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)

    // Create options with the large FormData
    var options = FetchOptions()
    options.method = .post
    options.body = formData

    // The optimization should convert FormData to a temporary file URL
    // We can't directly test the private optimizeRequest method, but we can
    // verify that the FormData is properly handled and doesn't cause memory issues

    // This test verifies that the optimization doesn't break the FormData
    let encoded = try formData.encode()
    #expect(encoded.count > largeData.count)  // Should include headers and boundaries
  }

  @Test func testFormDataOptimizationWithMixedContent() throws {
    // Test optimization with mixed content types
    let formData = FormData()

    // Add some small parts
    formData.append("name", "John Doe")
    formData.append("email", "john@example.com")

    // Add a large part that triggers optimization
    let largeData = Data(repeating: 0x42, count: 11_000_000)  // 11MB
    formData.append("large", largeData)

    // Add more small parts
    formData.append("description", "Mixed content test")

    // Should exceed threshold due to the large part
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)

    // Should still encode correctly
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)

    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("John Doe"))
    #expect(encodedString.contains("john@example.com"))
    #expect(encodedString.contains("Mixed content test"))
  }

  @Test func testFormDataOptimizationThresholdEdgeCase() throws {
    // Test exactly at the threshold boundary
    let formData = FormData()

    // Create data that's exactly at the threshold (10MB)
    let thresholdData = Data(repeating: 0x42, count: 10_000_000)
    formData.append("threshold", thresholdData)

    // Should be at or slightly above threshold due to headers and boundaries
    #expect(formData.contentLength >= FormData.encodingMemoryThreshold)

    // Should still encode correctly
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)
  }

  @Test func testFormDataOptimizationWithComplexData() throws {
    // Test optimization with complex data structures
    struct ComplexData: Encodable {
      let name: String
      let details: [String: String]
      let numbers: [Int]
    }

    let complexData = ComplexData(
      name: "Complex Test",
      details: ["key1": "value1", "key2": "value2"],
      numbers: Array(1...1000)  // Large array
    )

    let formData = FormData()

    // Add complex data
    formData.append("complex", complexData)

    // Add large binary data to trigger optimization
    let largeData = Data(repeating: 0x42, count: 11_000_000)  // 11MB
    formData.append("large", largeData)

    // Should exceed threshold
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)

    // Should still encode correctly
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)

    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("Complex Test"))
    #expect(encodedString.contains("key1"))
    #expect(encodedString.contains("value1"))
  }

  @Test func testFormDataOptimizationMemoryEfficiency() throws {
    // Test that the optimization actually improves memory efficiency
    let formData = FormData()

    // Create multiple large parts to stress test memory usage
    for i in 0..<5 {
      let largeData = Data(repeating: UInt8(i), count: 2_000_000)  // 2MB each, 10MB total
      formData.append("part\(i)", largeData)
    }

    // Should meet or exceed threshold (accounting for headers and boundaries)
    #expect(formData.contentLength >= FormData.encodingMemoryThreshold)

    // Test both encoding methods to ensure they work correctly
    let encodedInMemory = try formData.encode()
    #expect(!encodedInMemory.isEmpty)

    // Test file-based encoding
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "memory-efficiency-test.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try formData.writeEncodedData(to: outputURL)
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    // Verify the file was created successfully
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    // Verify the file contains the expected structure
    let fileContent = try Data(contentsOf: outputURL)
    let fileString = String(data: fileContent, encoding: .utf8)!
    #expect(fileString.contains("name=\"part0\""))
    #expect(fileString.contains("name=\"part1\""))
    #expect(fileString.contains("name=\"part2\""))
    #expect(fileString.contains("name=\"part3\""))
    #expect(fileString.contains("name=\"part4\""))
  }

  @Test func testFormDataOptimizationWithURLSearchParams() throws {
    // Test optimization with URLSearchParams
    var params = URLSearchParams()
    for i in 0..<1000 {
      params.append("key\(i)", value: "value\(i)")
    }

    let formData = FormData()
    formData.append("params", params)

    // Add large data to trigger optimization
    let largeData = Data(repeating: 0x42, count: 11_000_000)  // 11MB
    formData.append("large", largeData)

    // Should exceed threshold
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)

    // Should still encode correctly
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)

    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("key0"))
    #expect(encodedString.contains("value0"))
    #expect(encodedString.contains("key999"))
    #expect(encodedString.contains("value999"))
  }

  @Test func testFormDataOptimizationErrorHandling() throws {
    // Test that optimization doesn't interfere with error handling
    let formData = FormData()

    // Add an invalid URL that will cause an error
    let invalidURL = URL(string: "https://example.com/file.txt")!
    formData.append("invalid", invalidURL)

    // Add large data to trigger optimization
    let largeData = Data(repeating: 0x42, count: 11_000_000)  // 11MB
    formData.append("large", largeData)

    // Should exceed threshold
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)

    // Should still throw the same error during encoding
    do {
      _ = try formData.encode()
      #expect(Bool(false), "Should have thrown an error for invalid URL")
    } catch {
      #expect(error.localizedDescription.contains("file URL"))
    }

    // Should also throw during file writing
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("error-test.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    do {
      try formData.writeEncodedData(to: outputURL)
      #expect(Bool(false), "Should have thrown an error for invalid URL during file writing")
    } catch {
      #expect(error.localizedDescription.contains("file URL"))
    }
  }

  @Test func testFormDataOptimizationBoundaryConsistency() throws {
    // Test that optimization preserves boundary consistency
    let customBoundary = "custom-boundary-123"
    let formData = FormData(boundary: customBoundary)

    let largeData = Data(repeating: 0x42, count: 11_000_000)  // 11MB
    formData.append("large", largeData)
    formData.append("description", "Boundary test")

    // Should exceed threshold
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)

    // Test both encoding methods
    let encodedInMemory = try formData.encode()
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "boundary-test.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try formData.writeEncodedData(to: outputURL)

    // Both should contain the custom boundary
    let encodedString = String(data: encodedInMemory, encoding: .utf8)!
    let fileContent = try String(contentsOf: outputURL, encoding: .utf8)

    #expect(encodedString.contains(customBoundary))
    #expect(fileContent.contains(customBoundary))
  }

  @Test func testFormDataOptimizationPerformance() throws {
    // Test performance characteristics of the optimization
    let formData = FormData()

    // Create a very large FormData to test performance
    let largeData = Data(repeating: 0x42, count: 50_000_000)  // 50MB
    formData.append("veryLarge", largeData)

    // Should meet or exceed threshold (accounting for headers and boundaries)
    #expect(formData.contentLength >= FormData.encodingMemoryThreshold * 5)

    // Measure time for file-based encoding
    let startTime = CFAbsoluteTimeGetCurrent()

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "performance-test.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try formData.writeEncodedData(to: outputURL)

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime

    // Should complete within reasonable time (adjust threshold as needed)
    #expect(duration < 10.0)  // Should complete within 10 seconds

    // Verify file was created and has expected size
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
    let fileSize = fileAttributes[.size] as? Int ?? 0
    #expect(fileSize > largeData.count)  // Should be larger due to headers and boundaries
  }
}
