import Foundation
import XCTest
@testable import MockMarks

final class MockMarksTests: XCTestCase {

  override func setUp() {
    super.setUp()
    MockMarks.shared.queue.queuedResponses.removeAll()
  }

  func test_isXCUI_shouldReferToProcessInfo_whenTrue() {
    let mockedProcessInfo = MockProcessInfo()
    mockedProcessInfo.mockedIsRunningXCUI = true
    XCTAssert(MockMarks.shared.isXCUI(processInfo: mockedProcessInfo))
  }

  func test_isXCUI_shouldReferToProcessInfo_whenFalse() {
    let mockedProcessInfo = MockProcessInfo()
    mockedProcessInfo.mockedIsRunningXCUI = false
    XCTAssertFalse(MockMarks.shared.isXCUI(processInfo: mockedProcessInfo))
  }

  func test_setUp_shouldNotLoadJSON_whenXCUIIsNotRunning() {
    let processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = false
    MockMarks.shared.setUp(session: Session(), processInfo: processInfo)
    XCTAssert(MockMarks.shared.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldNotLoadJSON_whenMockDirectoryIsNotSet() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      MockMarks.Constants.isXCUI: String(true),
      MockMarks.Constants.mockFilename: "B"
    ]
    MockMarks.shared.setUp(session: Session(), processInfo: processInfo)
    XCTAssert(MockMarks.shared.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldNotQueue_whenMockFilenameIsNotSet() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      MockMarks.Constants.isXCUI: String(true),
      MockMarks.Constants.mockDirectory: "B"
    ]
    MockMarks.shared.setUp(session: Session(), processInfo: processInfo)
    XCTAssert(MockMarks.shared.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldLoadJSON_whenURLDoesContainJSON() {
    let url = Bundle.module.url(forResource: "LoaderTests", withExtension: "json")
    let dir = url?.deletingLastPathComponent()

    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      MockMarks.Constants.isXCUI: String(true),
      MockMarks.Constants.mockDirectory: dir!.absoluteString,
      MockMarks.Constants.mockFilename: "LoaderTests.json"
    ]

    MockMarks.shared.setUp(session: Session(), processInfo: processInfo)
    XCTAssertFalse(MockMarks.shared.queue.queuedResponses.isEmpty)
  }

  func test_dispatchNextQueuedResponse_shouldCallCompletion() {
    guard let data = try? JSONSerialization.data(withJSONObject: ["A": "B"]) else { return XCTFail(#function) }
    let response = MockMark.Response(data: data, urlResponse: nil, error: nil)
    let mockmark = MockMark(url: url, response: response)

    MockMarks.shared.queue.queue(mockmark: mockmark)
    _ = MockMarks.shared.dispatchNextQueuedResponse(for: url) { data, _, _ in
      guard let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any] else {
        return XCTFail(#function)
      }

      guard let result = json["A"] as? String else { return XCTFail(#function) }

      XCTAssertEqual(result, "B")
    }
  }
}

private extension MockMarksTests {

  var url: URL {
    URL(string: "A")!
  }
}
