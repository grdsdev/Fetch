//
//  ResponseTests.swift
//  Fetch
//
//  Created by Guilherme Souza on 24/05/25.
//
import Fetch
import Foundation
import Testing

struct ResponseTests {
  @Test func responseInitWithProducer() async throws {
    let response = Response.Body { producer in
      producer.yield("hello")
      producer.yield("world")
      producer.finish()
    }

    var chunkes: [Data] = []
    for try await chunk in response {
      chunkes.append(chunk)
    }

    #expect(chunkes == [Data("hello".utf8), Data("world".utf8)])
  }

  @Test func responseInitWithURLAndStatus() async throws {
    let url = URL(string: "https://example.com")!
    let body = Response.Body { producer in
      producer.yield("test")
      producer.finish()
    }

    let response = Response(url: url, status: 200, headers: ["Content-Type": "text/plain"], body: body)

    #expect(response.url == url)
    #expect(response.status == 200)
    #expect(response.headers["Content-Type"] == "text/plain")
    #expect(try await response.text() == "test")
  }

  @Test func responseBodyStreaming() async throws {
    let body = Response.Body { producer in
      producer.yield(Data([1, 2, 3]))
      producer.yield(Data([4, 5, 6]))
      producer.finish()
    }

    var chunks: [Data] = []
    for try await chunk in body {
      chunks.append(chunk)
    }

    #expect(chunks == [Data([1, 2, 3]), Data([4, 5, 6])])
  }

  @Test func responseBlob() async throws {
    let body = Response.Body { producer in
      producer.yield("hello")
      producer.yield("world")
      producer.finish()
    }

    let response = Response(url: nil, status: 200, headers: [:], body: body)
    let blob = await response.blob()

    #expect(blob == Data("helloworld".utf8))
  }

  @Test func responseJSON() async throws {
    let json: [String: Any] = ["name": "John", "age": 30]

    let body = Response.Body { producer in
      try! producer.yield(json)
      producer.finish()
    }

    let response = Response(
      url: nil, status: 200, headers: ["Content-Type": "application/json"], body: body)
    let decoded = try await response.json() as! [String: Any]

    #expect(decoded["name"] as? String == "John")
    #expect(decoded["age"] as? Int == 30)
  }

  @Test func responseDecodable() async throws {
    struct Person: Codable {
      let name: String
      let age: Int
    }

    let person = Person(name: "John", age: 30)

    let body = Response.Body { producer in
      try! producer.yield(person)
      producer.finish()
    }

    let response = Response(
      url: nil, status: 200, headers: ["Content-Type": "application/json"], body: body)
    let decoded = try await response.json() as Person

    #expect(decoded.name == "John")
    #expect(decoded.age == 30)
  }

  @Test func responseText() async throws {
    let body = Response.Body { producer in
      producer.yield("Hello")
      producer.yield(" ")
      producer.yield("World")
      producer.finish()
    }

    let response = Response(
      url: nil, status: 200, headers: ["Content-Type": "text/plain"], body: body)
    let text = try await response.text()

    #expect(text == "Hello World")
  }
}
