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
}
