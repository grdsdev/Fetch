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

  @Test func downloadFileWithNewMethod() async throws {
    let response = try await fetch.download(
      "https://github.com/grdsdev/Fetch/archive/refs/heads/main.zip"
    ) { _ in }
    #expect(response.status == 200)
    #expect(await response.blob().count > 0)
  }

  @Test func downloadFileWithOptions() async throws {
    let response = try await fetch.download(
      "https://httpbin.org/get"
    ) {
      $0.timeoutInterval = 30.0
      $0.headers["X-Custom-Header"] = "test-value"
    }
    #expect(response.status == 200)

    // Verify the custom header was sent
    let json = try await response.json() as! [String: Any]
    let headers = json["headers"] as! [String: Any]
    #expect(headers["X-Custom-Header"] as? String == "test-value")
  }

  @Test func downloadFileWithInvalidURL() async throws {
    do {
      _ = try await fetch.download("invalid-url") { _ in }
      #expect(Bool(false), "Should have thrown an error for invalid URL")
    } catch {
      #expect(error.localizedDescription.contains("unsupported URL"))
    }
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
    // Test that large FormData triggers optimization
    let formData = FormData()
    let largeData = Data(repeating: 0x42, count: 11_000_000)  // 11MB, exceeds 10MB threshold
    formData.append("large", largeData)

    #expect(formData.contentLength > FormData.encodingMemoryThreshold)
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)
  }

  @Test func testFetchWithSmallFormDataNoOptimization() async throws {
    // Test that small FormData doesn't trigger optimization
    let formData = FormData()
    let smallData = Data(repeating: 0x42, count: 1_000_000)  // 1MB, below 10MB threshold
    formData.append("small", smallData)

    #expect(formData.contentLength < FormData.encodingMemoryThreshold)
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)
  }

  // MARK: - Progress Tests

  @Test func testDownloadProgress() async throws {
    let progressCalled = Mutex(false)

    let response = try await fetch.download("https://httpbin.org/bytes/10000") {
      $0.downloadProgressHandler = { progress in
        progressCalled.withLock { $0 = true }

        // Validate progress values
        #expect(progress.bytesReceived >= 0)
        #expect(progress.bytesProcessed >= 0)
        #expect(progress.fractionCompleted >= 0.0)
        #expect(progress.fractionCompleted <= 1.0)
        #expect(progress.bytesReceived == progress.bytesProcessed)
      }
    }

    #expect(response.status == 200)
    #expect(progressCalled.withLock { $0 }, "Should have progress updates")

    let data = await response.blob()
    #expect(data.count >= 10000)
  }

  @Test func testUploadProgress() async throws {
    let testData = Data(repeating: 65, count: 10000)  // 10KB
    let progressCalled = Mutex(false)

    let response = try await fetch("https://httpbin.org/post") {
      $0.method = .post
      $0.body = testData
      $0.uploadProgressHandler = { progress in
        progressCalled.withLock { $0 = true }

        #expect(progress.bytesSent >= 0)
        #expect(progress.bytesProcessed >= 0)
        #expect(progress.fractionCompleted >= 0.0)
        #expect(progress.fractionCompleted <= 1.0)
        #expect(progress.bytesSent == progress.bytesProcessed)
      }
    }

    #expect(response.status == 200)
    #expect(progressCalled.withLock { $0 }, "Should have upload progress")
  }

  @Test func testFileUploadProgress() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).txt")
    let content = String(repeating: "test ", count: 2500)  // ~10KB
    try content.write(to: tempFile, atomically: true, encoding: .utf8)

    defer { try? FileManager.default.removeItem(at: tempFile) }

    let progressCalled = Mutex(false)
    let maxBytesSent = Mutex(Int64(0))

    let response = try await fetch("https://httpbin.org/post") {
      $0.method = .post
      $0.body = tempFile
      $0.uploadProgressHandler = { progress in
        progressCalled.withLock { $0 = true }
        maxBytesSent.withLock { $0 = max($0, progress.bytesSent) }
        #expect(progress.bytesSent >= 0)
        #expect(progress.fractionCompleted >= 0.0)
        #expect(progress.fractionCompleted <= 1.0)
      }
    }

    #expect(response.status == 200)
    #expect(progressCalled.withLock { $0 }, "File upload should have progress")
    #expect(maxBytesSent.withLock { $0 } >= 10000, "Should have sent significant data")
  }

  @Test func testCombinedProgress() async throws {
    let uploadData = Data(repeating: 68, count: 5000)
    let uploadProgressCalled = Mutex(false)
    let downloadProgressCalled = Mutex(false)

    let response = try await fetch("https://httpbin.org/post") {
      $0.method = .post
      $0.body = uploadData
      $0.uploadProgressHandler = { progress in
        uploadProgressCalled.withLock { $0 = true }
        #expect(progress.bytesSent >= 0)
      }
      $0.downloadProgressHandler = { progress in
        downloadProgressCalled.withLock { $0 = true }
        #expect(progress.bytesReceived >= 0)
      }
    }

    #expect(response.status == 200)
    #expect(uploadProgressCalled.withLock { $0 }, "Should have upload progress")
    #expect(downloadProgressCalled.withLock { $0 }, "Should have download progress")
  }

  @Test func testProgressPropertyConsistency() async throws {
    let testData = Data(repeating: 69, count: 1000)

    let response = try await fetch("https://httpbin.org/post") {
      $0.method = .post
      $0.body = testData
      $0.uploadProgressHandler = { progress in
        // Test convenience properties
        #expect(progress.bytesSent == progress.bytesProcessed)
        #expect(progress.bytesReceived == progress.bytesProcessed)

        // Test fraction calculation
        if progress.totalBytesExpected > 0 {
          let expected = Double(progress.bytesProcessed) / Double(progress.totalBytesExpected)
          #expect(abs(progress.fractionCompleted - expected) < 0.001)
        }
      }
    }

    #expect(response.status == 200)
  }
}
