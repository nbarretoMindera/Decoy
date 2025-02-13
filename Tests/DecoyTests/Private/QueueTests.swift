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
    queue.queue(Stub: Stub(url: url, response: .init(data: nil, urlResponse: nil, error: nil)))
    XCTAssertNotNil(queue.queuedResponses[url])
  }

  func test_queue_shouldSaveResponse() {
    let response: Stub.Response = .init(data: testData1, urlResponse: nil, error: nil)
    queue.queue(Stub: Stub(url: url, response: response))
    XCTAssertEqual(queue.queuedResponses[url]?.first?.data, testData1)
  }

  func test_queue_shouldInsertResponseAtPositionZero() {
    let response1: Stub.Response = .init(data: testData1, urlResponse: nil, error: nil)
    let response2: Stub.Response = .init(data: testData2, urlResponse: nil, error: nil)
    queue.queue(Stub: Stub(url: url, response: response1))
    queue.queue(Stub: Stub(url: url, response: response2))
    XCTAssertEqual(queue.queuedResponses[url]?[0].data, testData2)
    XCTAssertEqual(queue.queuedResponses[url]?[1].data, testData1)
  }

  func test_queue_shouldPreserveStatusCode() {
    let response: Stub.Response = .init(data: nil, urlResponse: urlResponse, error: nil)
    queue.queue(Stub: Stub(url: url, response: response))

    let statusCode = queue.queuedResponses[url]?.first?.urlResponse?.statusCode
    XCTAssertEqual(url, urlResponse.url)
    XCTAssertEqual(statusCode, urlResponse.statusCode)
  }

  func test_queue_shouldPreserveError() {
    let response: Stub.Response = .init(data: nil, urlResponse: nil, error: error)
    queue.queue(Stub: Stub(url: url, response: response))

    guard let savedError = queue.queuedResponses[url]?.first?.error else {
      return XCTFail(#function)
    }

    XCTAssertEqual(savedError["domain"] as? String, error["domain"] as? String)
    XCTAssertEqual(savedError["code"] as? Int, error["code"] as? Int)
  }

  func test_dispatchNextQueuedResponse_shouldReturnFalse_whenURLHasNoQueuedResponses() {
    XCTAssertFalse(queue.dispatchNextQueuedResponse(for: url, to: { _, _, _ in }))
  }

  func test_dispatchNextQueuedResponse_shouldReturnTrue_whenURLHasQueuedResponses() {
    queue.queue(Stub: Stub(url: url, response: emptyResponse))
    XCTAssertTrue(queue.dispatchNextQueuedResponse(for: url, to: { _, _, _ in }))
  }

  func test_dispatchNextQueuedResponse_shouldReturnTrue_multipleTimes_thenFalse() {
    queue.queue(Stub: Stub(url: url, response: emptyResponse))
    queue.queue(Stub: Stub(url: url, response: emptyResponse))
    queue.queue(Stub: Stub(url: url, response: emptyResponse))
    XCTAssertTrue(queue.dispatchNextQueuedResponse(for: url, to: { _, _, _ in }))
    XCTAssertTrue(queue.dispatchNextQueuedResponse(for: url, to: { _, _, _ in }))
    XCTAssertTrue(queue.dispatchNextQueuedResponse(for: url, to: { _, _, _ in }))
    XCTAssertFalse(queue.dispatchNextQueuedResponse(for: url, to: { _, _, _ in }))
  }

  func test_dispatchNextQueuedResponse_shouldCallCompletion() {
    let exp = expectation(description: #function)
    queue.queue(Stub: Stub(url: url, response: emptyResponse))
    _ = queue.dispatchNextQueuedResponse(for: url) { _ in exp.fulfill() }
    waitForExpectations(timeout: 0.01)
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
