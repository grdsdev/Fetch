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
    #expect(encoded.isEmpty || encoded.count < 100) // Should be minimal
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
      #expect(error.localizedDescription.contains("boundary") || error.localizedDescription.contains("missing"))
    }
  }
  
  @Test func testDecodeWithInvalidBoundaryFormat() {
    let data = Data()
    let contentTypeWithInvalidBoundary = "multipart/form-data; boundary="
    
    do {
      _ = try FormData.decode(from: data, contentType: contentTypeWithInvalidBoundary)
      #expect(Bool(false), "Should have thrown an error for invalid boundary format")
    } catch {
      #expect(error.localizedDescription.contains("boundary") || error.localizedDescription.contains("missing"))
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
    let largeData = Data(repeating: 0x42, count: 1024 * 1024) // 1MB
    
    formData.append("large", largeData)
    
    let encoded = try formData.encode()
    #expect(encoded.count > largeData.count) // Should be larger due to headers and boundaries
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
}
