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
}
