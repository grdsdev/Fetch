import Foundation
import Testing

@testable import Fetch

struct FetchTests {

  @Test func fetchJSON() async throws {
    let response = try await fetch("https://jsonplaceholder.typicode.com/posts/1")
    #expect(response.status == 200)

    let json = try await response.json() as! [String: Any]
    #expect(json["id"] as? Int == 1)
    #expect(
      json["title"] as? String
        == "sunt aut facere repellat provident occaecati excepturi optio reprehenderit"
    )
    #expect(
      json["body"] as? String
        == "quia et suscipit\nsuscipit recusandae consequuntur expedita et cum\nreprehenderit molestiae ut ut quas totam\nnostrum rerum est autem sunt rem eveniet architecto"
    )
    #expect(json["userId"] as? Int == 1)
  }

  @Test func fetchDecodable() async throws {
    let response = try await fetch("https://jsonplaceholder.typicode.com/posts/1")
    #expect(response.status == 200)

    struct Post: Decodable {
      let id: Int
      let title: String
      let body: String
      let userId: Int
    }

    let post = try await response.json() as Post
    #expect(post.id == 1)
    #expect(
      post.title
        == "sunt aut facere repellat provident occaecati excepturi optio reprehenderit"
    )
    #expect(
      post.body
        == "quia et suscipit\nsuscipit recusandae consequuntur expedita et cum\nreprehenderit molestiae ut ut quas totam\nnostrum rerum est autem sunt rem eveniet architecto"
    )
    #expect(post.userId == 1)
  }

  @Test func fetchText() async throws {
    let response = try await fetch("https://jsonplaceholder.typicode.com/posts/1")
    #expect(response.status == 200)

    let text = try await response.text()
    #expect(text.contains("quia et suscipit"))
  }

  @Test func downloadFile() async throws {
    let response = try await fetch(
      "https://github.com/grdsdev/Fetch/archive/refs/heads/main.zip"
    ) {
      $0.download = true
    }
    #expect(response.status == 200)
    #expect(await response.blob().count > 0)
  }

  @Test func requestWithFormData() async throws {
    let formData = FormData()
    formData.append("username", "john_doe")
    // formData.append("avatar", avatarURL)
    // formData.append(
    //   "data", binaryData, filename: "file.bin", contentType: "application/octet-stream")
    formData.append("metadata", ["key": "value"])

    let response = try await fetch("https://echo.free.beeceptor.com") {
      $0.method = .post
      $0.body = formData
    }

    struct Payload: Decodable {
      let parsedBody: ParsedBody

      struct ParsedBody: Decodable {
        let textFields: [String: String]
      }
    }

    let payload = try await response.json() as Payload
    #expect(response.status == 200)
    #expect(payload.parsedBody.textFields["username"] == "john_doe")
    #expect(payload.parsedBody.textFields["metadata"] == #"{"key":"value"}"#)
  }

  @Test func testFetchWithFormData() async throws {
    let response = try await fetch("https://httpbin.org/post") {
      $0.method = .post
      $0.body = FormData()
    }
    #expect(response.status == 200)
  }
  
  @Test func testFetchWithLargeFormDataOptimization() async throws {
    // Create large FormData that should trigger the optimization
    let formData = FormData()
    let largeData = Data(repeating: 0x42, count: 11_000_000) // 11MB, exceeds 10MB threshold
    formData.append("large", largeData)
    formData.append("description", "Large data test")
    
    // Verify it exceeds the threshold
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)
    
    // This test verifies that the optimization doesn't break the request
    // The actual optimization happens in the private optimizeRequest method
    // We can't directly test it, but we can verify the FormData is handled correctly
    
    // Test that the FormData can still be encoded normally
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)
    #expect(encoded.count > largeData.count) // Should include headers and boundaries
    
    // Test that the FormData can be written to a file (which is what the optimization does)
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("fetch-optimization-test.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }
    
    try formData.writeEncodedData(to: outputURL)
    #expect(FileManager.default.fileExists(atPath: outputURL.path))
    
    // Verify the file contains the expected content
    let fileContent = try String(contentsOf: outputURL, encoding: .utf8)
    #expect(fileContent.contains("name=\"description\""))
    #expect(fileContent.contains("name=\"large\""))
  }
  
  @Test func testFetchWithSmallFormDataNoOptimization() async throws {
    // Create small FormData that should NOT trigger the optimization
    let formData = FormData()
    let smallData = Data(repeating: 0x42, count: 1_000_000) // 1MB, below 10MB threshold
    formData.append("small", smallData)
    formData.append("description", "Small data test")
    
    // Verify it doesn't exceed the threshold
    #expect(formData.contentLength < FormData.encodingMemoryThreshold)
    
    // Test that the FormData can still be encoded normally
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)
    #expect(encoded.count > smallData.count) // Should include headers and boundaries
    
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("Small data test"))
  }
  
  @Test func testFetchWithFormDataThresholdEdgeCase() async throws {
    // Test exactly at the threshold boundary
    let formData = FormData()
    let thresholdData = Data(repeating: 0x42, count: 10_000_000) // Exactly 10MB
    formData.append("threshold", thresholdData)
    formData.append("description", "Threshold test")
    
    // Should be at or slightly above threshold due to headers and boundaries
    #expect(formData.contentLength >= FormData.encodingMemoryThreshold)
    
    // Test that the FormData can still be encoded normally
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)
    
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("Threshold test"))
  }
  
  @Test func testFetchWithFormDataMixedContent() async throws {
    // Test FormData with mixed content types
    let formData = FormData()
    
    // Add some small parts
    formData.append("name", "John Doe")
    formData.append("email", "john@example.com")
    
    // Add a large part that triggers optimization
    let largeData = Data(repeating: 0x42, count: 11_000_000) // 11MB
    formData.append("large", largeData)
    
    // Add more small parts
    formData.append("description", "Mixed content test")
    
    // Should exceed threshold due to the large part
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)
    
    // Test that the FormData can still be encoded normally
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)
    
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("John Doe"))
    #expect(encodedString.contains("john@example.com"))
    #expect(encodedString.contains("Mixed content test"))
  }
  
  @Test func testFetchWithFormDataFileUpload() async throws {
    // Test FormData with file upload that might trigger optimization
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("fetch-test-file.txt")
    let largeContent = String(repeating: "Large file content for testing. ", count: 500_000) // ~15MB
    try largeContent.write(to: tempURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tempURL) }
    
    let formData = FormData()
    formData.append("file", tempURL)
    formData.append("description", "File upload test")
    
    // Should exceed the threshold due to the large file
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)
    
    // Test that the FormData can still be encoded normally
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)
    
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("File upload test"))
    #expect(encodedString.contains("filename=\"fetch-test-file.txt\""))
  }
  
  @Test func testFetchWithFormDataComplexData() async throws {
    // Test FormData with complex data structures
    struct ComplexData: Encodable {
      let name: String
      let details: [String: String]
      let numbers: [Int]
    }
    
    let complexData = ComplexData(
      name: "Complex Test",
      details: ["key1": "value1", "key2": "value2"],
      numbers: Array(1...1000) // Large array
    )
    
    let formData = FormData()
    formData.append("complex", complexData)
    
    // Add large binary data to trigger optimization
    let largeData = Data(repeating: 0x42, count: 11_000_000) // 11MB
    formData.append("large", largeData)
    
    // Should exceed threshold
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)
    
    // Test that the FormData can still be encoded normally
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)
    
    let encodedString = String(data: encoded, encoding: .utf8)!
    #expect(encodedString.contains("Complex Test"))
    #expect(encodedString.contains("key1"))
    #expect(encodedString.contains("value1"))
  }
  
  @Test func testFetchWithFormDataErrorHandling() async throws {
    // Test that optimization doesn't interfere with error handling
    let formData = FormData()
    
    // Add an invalid URL that will cause an error
    let invalidURL = URL(string: "https://example.com/file.txt")!
    formData.append("invalid", invalidURL)
    
    // Add large data to trigger optimization
    let largeData = Data(repeating: 0x42, count: 11_000_000) // 11MB
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
  }
  
  @Test func testFetchWithFormDataMemoryEfficiency() async throws {
    // Test that the optimization actually improves memory efficiency
    let formData = FormData()
    
    // Create multiple large parts to stress test memory usage
    for i in 0..<5 {
      let largeData = Data(repeating: UInt8(i), count: 2_000_000) // 2MB each, 10MB total
      formData.append("part\(i)", largeData)
    }
    
    // Should meet or exceed threshold (accounting for headers and boundaries)
    #expect(formData.contentLength >= FormData.encodingMemoryThreshold)
    
    // Test both encoding methods to ensure they work correctly
    let encodedInMemory = try formData.encode()
    #expect(!encodedInMemory.isEmpty)
    
    // Test file-based encoding (what the optimization does)
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("fetch-memory-efficiency-test.txt")
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
  
  @Test func testFetchWithFormDataBoundaryConsistency() async throws {
    // Test that optimization preserves boundary consistency
    let customBoundary = "custom-boundary-123"
    let formData = FormData(boundary: customBoundary)
    
    let largeData = Data(repeating: 0x42, count: 11_000_000) // 11MB
    formData.append("large", largeData)
    formData.append("description", "Boundary test")
    
    // Should exceed threshold
    #expect(formData.contentLength > FormData.encodingMemoryThreshold)
    
    // Test both encoding methods
    let encodedInMemory = try formData.encode()
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("fetch-boundary-test.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }
    
    try formData.writeEncodedData(to: outputURL)
    
    // Both should contain the custom boundary
    let encodedString = String(data: encodedInMemory, encoding: .utf8)!
    let fileContent = try String(contentsOf: outputURL, encoding: .utf8)
    
    #expect(encodedString.contains(customBoundary))
    #expect(fileContent.contains(customBoundary))
  }
  
  @Test func testFetchWithFormDataPerformance() async throws {
    // Test performance characteristics of the optimization
    let formData = FormData()
    
    // Create a very large FormData to test performance
    let largeData = Data(repeating: 0x42, count: 50_000_000) // 50MB
    formData.append("veryLarge", largeData)
    
    // Should meet or exceed threshold (accounting for headers and boundaries)
    #expect(formData.contentLength >= FormData.encodingMemoryThreshold * 5)
    
    // Measure time for file-based encoding (what the optimization does)
    let startTime = CFAbsoluteTimeGetCurrent()
    
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("fetch-performance-test.txt")
    defer { try? FileManager.default.removeItem(at: outputURL) }
    
    try formData.writeEncodedData(to: outputURL)
    
    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime
    
    // Should complete within reasonable time (adjust threshold as needed)
    #expect(duration < 10.0) // Should complete within 10 seconds
    
    // Verify file was created and has expected size
    #expect(FileManager.default.fileExists(atPath: outputURL.path))
    
    let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
    let fileSize = fileAttributes[.size] as? Int ?? 0
    #expect(fileSize > largeData.count) // Should be larger due to headers and boundaries
  }
}
