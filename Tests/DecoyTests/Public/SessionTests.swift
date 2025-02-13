import Foundation
import XCTest
@testable import Decoy

final class SessionTests: XCTestCase {

  private var mockURLSession: MockSession!
  private var DecoySession: Session!

  override func setUp() {
    super.setUp()
    mockURLSession = MockSession()
    Decoy.shared.recorder.recordings.removeAll()
    DecoySession = Session(mocking: mockURLSession)
  }

  override func tearDown() {
    DecoySession = nil
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
    let task = DecoySession.dataTask(with: urlRequest, completionHandler: completion)
    XCTAssert(task is DataTask)
  }

  func test_dataTaskWithURLRequest_shouldDeferCompletionHandlerToSuperclass() {
    _ = DecoySession.dataTask(with: urlRequest) { data, _, _ in
      XCTAssertEqual(data!, self.stringData)
    }
  }

  func test_dataTaskWithURLRequest_shouldNotRecordWhenRecordingIsDisabled() {
    _ = DecoySession.dataTask(with: url) { _, _, _ in }
    XCTAssert(mockURLSession.didCallDataTaskWithURL)
    XCTAssert(Decoy.shared.recorder.recordings.isEmpty)
  }

  func test_dataTaskWithURLRequest_shouldRecordWhenRecordingIsEnabled() {
    let mockRecorder = MockRecorder()
    mockRecorder.mockedShouldRecord = true

    DecoySession.recorder = mockRecorder
    _ = DecoySession.dataTask(with: urlRequest) { _, _, _ in }
    XCTAssert(mockRecorder.didCallRecord)
  }

  // MARK: - dataTaskWithURL

  func test_dataTaskWithURL_shouldDeferResponseFromSuperclass() {
    _ = DecoySession.dataTask(with: url) { _, _, _ in }
    XCTAssert(mockURLSession.didCallDataTaskWithURL)
  }

  func test_dataTaskWithURL_shouldDeferCompletionHandlerToSuperclass() {
    _ = DecoySession.dataTask(with: url) { data, _, _ in
      XCTAssertEqual(data!, self.stringData)
    }
  }

  func test_dataTaskWithURL_shouldRecordWhenRecordingIsEnabled() {
    let mockRecorder = MockRecorder()
    mockRecorder.mockedShouldRecord = true

    DecoySession.recorder = mockRecorder
    _ = DecoySession.dataTask(with: url) { _, _, _ in }
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
