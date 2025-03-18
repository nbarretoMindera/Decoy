import Foundation
import XCTest
@testable import Decoy

final class QueueTests: XCTestCase {
  var queue: Queue!

  override func setUp() {
    super.setUp()
    queue = Queue()
  }

  override func tearDown() {
    queue = nil
    super.tearDown()
  }

  func test_queue_shouldCreateKey_whenItDoesNotExist() {
    queue.queue(stub: Stub(url: url, response: .init(data: nil, urlResponse: nil, error: nil)))
    XCTAssertNotNil(queue.queuedResponses[url])
  }

  func test_queue_shouldSaveResponse() {
    let response: Stub.Response = .init(data: testData1, urlResponse: nil, error: nil)
    queue.queue(stub: Stub(url: url, response: response))
    XCTAssertEqual(queue.queuedResponses[url]?.first?.data, testData1)
  }

  func test_queue_shouldInsertResponseAtPositionZero() {
    let response1: Stub.Response = .init(data: testData1, urlResponse: nil, error: nil)
    let response2: Stub.Response = .init(data: testData2, urlResponse: nil, error: nil)
    queue.queue(stub: Stub(url: url, response: response1))
    queue.queue(stub: Stub(url: url, response: response2))
    XCTAssertEqual(queue.queuedResponses[url]?[0].data, testData2)
    XCTAssertEqual(queue.queuedResponses[url]?[1].data, testData1)
  }

  func test_queue_shouldPreserveStatusCode() {
    let response: Stub.Response = .init(data: nil, urlResponse: urlResponse, error: nil)
    queue.queue(stub: Stub(url: url, response: response))

    let statusCode = queue.queuedResponses[url]?.first?.urlResponse?.statusCode
    XCTAssertEqual(url, urlResponse.url)
    XCTAssertEqual(statusCode, urlResponse.statusCode)
  }

  func test_queue_shouldPreserveError() {
    let response: Stub.Response = .init(data: nil, urlResponse: nil, error: error)
    queue.queue(stub: Stub(url: url, response: response))

    guard let savedError = queue.queuedResponses[url]?.first?.error else {
      return XCTFail(#function)
    }

    XCTAssertEqual(savedError["domain"] as? String, error["domain"] as? String)
    XCTAssertEqual(savedError["code"] as? Int, error["code"] as? Int)
  }

  func test_dispatchNextQueuedResponse_shouldReturnNil_whenURLHasNoQueuedResponses() {
    XCTAssertNil(queue.nextQueuedResponse(for: url))
  }

  func test_dispatchNextQueuedResponse_shouldReturnNonNil_whenURLHasQueuedResponses() {
    queue.queue(stub: Stub(url: url, response: emptyResponse))
    XCTAssertNotNil(queue.nextQueuedResponse(for: url))
  }

  func test_dispatchNextQueuedResponse_shouldReturnTrue_multipleTimes_thenFalse() {
    queue.queue(stub: Stub(url: url, response: emptyResponse))
    queue.queue(stub: Stub(url: url, response: emptyResponse))
    queue.queue(stub: Stub(url: url, response: emptyResponse))
    XCTAssertNotNil(queue.nextQueuedResponse(for: url))
    XCTAssertNotNil(queue.nextQueuedResponse(for: url))
    XCTAssertNotNil(queue.nextQueuedResponse(for: url))
    XCTAssertNil(queue.nextQueuedResponse(for: url))
  }

  var url: URL {
    URL(string: "A")!
  }

  var emptyResponse: Stub.Response {
    Stub.Response(data: nil, urlResponse: nil, error: nil)
  }

  var testData1: Data {
    String("ABC").data(using: .utf8)!
  }

  var testData2: Data {
    String("DEF").data(using: .utf8)!
  }

  var urlResponse: HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: 123, httpVersion: nil, headerFields: nil)!
  }

  var error: [String: Any] {
    [
      "domain": NSURLErrorDomain,
      "code": NSURLErrorNotConnectedToInternet
    ]
  }
}
