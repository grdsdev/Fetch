import Testing

@testable import Fetch

struct HTTPHeadersTests {
    @Test func testHTTPHeaders() {
        var headers = HTTPHeaders()
        headers["Content-Type"] = "application/json"
        #expect(headers["content-type"] == "application/json")
        #expect(headers["Content-Type"] == "application/json")
        #expect(headers["content-type"] == "application/json")
    }

    @Test func testHTTPHeadersDictionaryLiteral() {
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Content-Length": "123",
        ]
        #expect(headers["content-type"] == "application/json")
        #expect(headers["Content-Type"] == "application/json")
        #expect(headers["content-type"] == "application/json")
        #expect(headers["Content-Length"] == "123")
    }

    @Test func testHTTPHeadersUpdate() {
        var headers = HTTPHeaders()
        headers["Content-Length"] = "123"
        #expect(headers["content-length"] == "123")
        #expect(headers["Content-Length"] == "123")
        #expect(headers["content-length"] == "123")
        headers["content-length"] = "456"
        #expect(headers["content-length"] == "456")
        #expect(headers["Content-Length"] == "456")
        #expect(headers["content-length"] == "456")
    }
}
