import Foundation
import XCTest
@testable import MockMarks

final class SessionTests: XCTestCase {

  private var mockURLSession: MockSession!
  private var mockMarksSession: Session!

  override func setUp() {
    super.setUp()
    mockURLSession = MockSession()
    MockMarks.shared.recorder.recordings.removeAll()
    mockMarksSession = Session(mocking: mockURLSession)
  }

  override func tearDown() {
    mockMarksSession = nil
    mockURLSession = nil
    super.tearDown()
  }

  private var urlRequest: URLRequest {
    URLRequest(url: url)
  }

  private var url: URL {
    URL(string: "https://api.com/endpoint")!
  }

  private var stringData: Data {
    "Test".data(using: .utf16)!
  }

  private var completion: (Data?, URLResponse?, Error?) -> Void {
    { _, _, _ in }
  }

  // MARK: - init

  func test_init_shouldStoreURLSession() {
    let sut = Session(mocking: .shared)
    XCTAssertIdentical(sut.urlSession, URLSession.shared)
  }

  // MARK: - dataTaskWithURLRequest

  func test_dataTaskWithURLRequest_shouldReturnAppropriateSubclass() {
    let task = mockMarksSession.dataTask(with: urlRequest, completionHandler: completion)
    XCTAssert(task is DataTask)
  }

  func test_dataTaskWithURLRequest_shouldDeferCompletionHandlerToSuperclass() {
    _ = mockMarksSession.dataTask(with: urlRequest) { data, _, _ in
      XCTAssertEqual(data!, self.stringData)
    }
  }

  func test_dataTaskWithURLRequest_shouldNotRecordWhenRecordingIsDisabled() {
    _ = mockMarksSession.dataTask(with: url) { _, _, _ in }
    XCTAssert(mockURLSession.didCallDataTaskWithURL)
    XCTAssert(MockMarks.shared.recorder.recordings.isEmpty)
  }

  func test_dataTaskWithURLRequest_shouldRecordWhenRecordingIsEnabled() {
    let mockRecorder = MockRecorder()
    mockRecorder.mockedShouldRecord = true

    mockMarksSession.recorder = mockRecorder
    _ = mockMarksSession.dataTask(with: urlRequest) { _, _, _ in }
    XCTAssert(mockRecorder.didCallRecord)
  }

  // MARK: - dataTaskWithURL

  func test_dataTaskWithURL_shouldDeferResponseFromSuperclass() {
    _ = mockMarksSession.dataTask(with: url) { _, _, _ in }
    XCTAssert(mockURLSession.didCallDataTaskWithURL)
  }

  func test_dataTaskWithURL_shouldDeferCompletionHandlerToSuperclass() {
    _ = mockMarksSession.dataTask(with: url) { data, _, _ in
      XCTAssertEqual(data!, self.stringData)
    }
  }

  func test_dataTaskWithURL_shouldRecordWhenRecordingIsEnabled() {
    let mockRecorder = MockRecorder()
    mockRecorder.mockedShouldRecord = true

    mockMarksSession.recorder = mockRecorder
    _ = mockMarksSession.dataTask(with: url) { _, _, _ in }
    XCTAssert(mockRecorder.didCallRecord)
  }
}

private class MockSession: URLSession {
  var didCallDataTaskWithURLRequest = false
  var didCallDataTaskWithURL = false

  override func dataTask(
    with request: URLRequest,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask {
    didCallDataTaskWithURLRequest = true
    let task = URLSession.shared.dataTask(with: request, completionHandler: completionHandler)
    return MockDataTask(mocking: task, completionHandler: completionHandler)
  }

  override func dataTask(
    with url: URL,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask {
    didCallDataTaskWithURL = true
    let task = URLSession.shared.dataTask(with: url, completionHandler: completionHandler)
    return MockDataTask(mocking: task, completionHandler: completionHandler)
  }
}

private class MockDataTask: DataTask {
  override init(mocking task: URLSessionDataTask, completionHandler: @escaping DataTask.CompletionHandler) {
    super.init(mocking: task, completionHandler: completionHandler)
    completionHandler(("Test".data(using: .utf16)!, nil, nil))
  }
}

private class MockRecorder: RecorderInterface {
  var recordings: [[String: Any]] = [[:]]

  var mockedShouldRecord = false

  var shouldRecord: Bool {
    mockedShouldRecord
  }

  var didCallRecord = false

  func record(url: URL, data: Data?, response: URLResponse?, error: Error?) {
    didCallRecord = true
  }
}
