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
    let largeData = Data(repeating: 0x42, count: 11_000_000) // 11MB, exceeds 10MB threshold
    formData.append("large", largeData)

    #expect(formData.contentLength > FormData.encodingMemoryThreshold)
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)
  }

  @Test func testFetchWithSmallFormDataNoOptimization() async throws {
    // Test that small FormData doesn't trigger optimization
    let formData = FormData()
    let smallData = Data(repeating: 0x42, count: 1_000_000) // 1MB, below 10MB threshold
    formData.append("small", smallData)

    #expect(formData.contentLength < FormData.encodingMemoryThreshold)
    let encoded = try formData.encode()
    #expect(!encoded.isEmpty)
  }
}
