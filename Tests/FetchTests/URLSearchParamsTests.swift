import Foundation
import Testing

@testable import Fetch

struct URLSearchParamsTests {
  @Test
  func initWithURL() {
    let url = URL(string: "https://example.com/path?foo=1&bar=2")!
    let params = URLSearchParams(url)
    #expect(params.description == "foo=1&bar=2")
  }

  @Test
  func initWithStringURL() {
    let params = URLSearchParams("https://example.com/path?foo=1&bar=2")
    #expect(params.description == "foo=1&bar=2")
  }

  @Test
  func initWithQueryString() {
    let params = URLSearchParams("foo=1&bar=2")
    #expect(params.description == "foo=1&bar=2")
  }

  @Test
  func initEmpty() {
    let params = URLSearchParams()
    #expect(params.description == "")
  }

  @Test
  func append() {
    var params = URLSearchParams("foo=1")
    params.append("bar", "2")
    #expect(params.description == "foo=1&bar=2")
  }

  @Test
  func appendEmptyName() {
    var params = URLSearchParams("foo=1")
    params.append("", "2")
    #expect(params.description == "foo=1")
  }

  @Test
  func delete() {
    var params = URLSearchParams("foo=1&bar=2&foo=3")
    params.delete("foo")
    #expect(params.description == "bar=2")
  }

  @Test
  func deleteWithValue() {
    var params = URLSearchParams("foo=1&bar=2&foo=3")
    params.delete("foo", "1")
    #expect(params.description == "bar=2&foo=3")
  }

  @Test
  func get() {
    let params = URLSearchParams("foo=1&bar=2&foo=3")
    #expect(params.get("foo") == "1")
    #expect(params.get("bar") == "2")
    #expect(params.get("baz") == nil)
  }

  @Test
  func getAll() {
    let params = URLSearchParams("foo=1&bar=2&foo=3")
    #expect(params.getAll("foo") == ["1", "3"])
    #expect(params.getAll("bar") == ["2"])
    #expect(params.getAll("baz") == [])
  }

  @Test
  func has() {
    let params = URLSearchParams("foo=1&bar=2")
    #expect(params.has("foo"))
    #expect(params.has("bar"))
    #expect(params.has("baz") == false)
  }

  @Test
  func keys() {
    let params = URLSearchParams("foo=1&bar=2&foo=3")
    let keys = params.keys()
    #expect(keys.count == 2)
    #expect(keys.contains("foo"))
    #expect(keys.contains("bar"))
  }

  @Test
  func sort() {
    var params = URLSearchParams("c=3&a=1&b=2")
    params.sort()
    #expect(params.description == "a=1&b=2&c=3")
  }

  @Test
  func values() {
    let params = URLSearchParams("foo=1&bar=2&foo=3")
    let values = params.values()
    #expect(values.count == 3)
    #expect(values.contains("1"))
    #expect(values.contains("2"))
    #expect(values.contains("3"))
  }

  @Test
  func urlDecoding() {
    let params = URLSearchParams("special%20chars=!%40%23%24%25%5E%26*()")
    #expect(params.get("special chars") == "!@#$%^&*()")
  }

  @Test
  func emptyValue() {
    let params = URLSearchParams("foo=&bar=2")
    #expect(params.get("foo") == "")
    #expect(params.get("bar") == "2")
  }

  @Test
  func noValue() {
    let params = URLSearchParams("foo&bar=2")
    #expect(params.get("foo") == nil)
    #expect(params.get("bar") == "2")
  }

  @Test
  func multipleValues() {
    let params = URLSearchParams("foo=1&foo=2&foo=3")
    #expect(params.getAll("foo") == ["1", "2", "3"])
  }

  @Test
  func urlComponents() {
    var url = URL(string: "https://example.com/path?foo=1&bar=2")!
    var params = url.searchParams
    params.append("baz", "3")
    url.searchParams = params
    #expect(url.absoluteString == "https://example.com/path?foo=1&bar=2&baz=3")
  }
}
