@testable import Decoy
import Foundation
import XCTest

final class DecoyTests: XCTestCase {
  override func setUp() {
    super.setUp()
    Decoy.shared.queue.queuedResponses.removeAll()
  }

  func test_isXCUI_shouldReferToProcessInfo_whenTrue() {
    let mockedProcessInfo = MockProcessInfo()
    mockedProcessInfo.mockedIsRunningXCUI = true
    XCTAssert(Decoy.shared.isXCUI(processInfo: mockedProcessInfo))
  }

  func test_isXCUI_shouldReferToProcessInfo_whenFalse() {
    let mockedProcessInfo = MockProcessInfo()
    mockedProcessInfo.mockedIsRunningXCUI = false
    XCTAssertFalse(Decoy.shared.isXCUI(processInfo: mockedProcessInfo))
  }

  func test_setUp_shouldNotLoadJSON_whenXCUIIsNotRunning() {
    let processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = false
    Decoy.shared.setUp(session: Session(), processInfo: processInfo)
    XCTAssert(Decoy.shared.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldNotLoadJSON_whenMockDirectoryIsNotSet() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: String(true),
      Decoy.Constants.mockFilename: "B"
    ]
    Decoy.shared.setUp(session: Session(), processInfo: processInfo)
    XCTAssert(Decoy.shared.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldNotQueue_whenMockFilenameIsNotSet() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: String(true),
      Decoy.Constants.mockDirectory: "B"
    ]
    Decoy.shared.setUp(session: Session(), processInfo: processInfo)
    XCTAssert(Decoy.shared.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldLoadJSON_whenURLDoesContainJSON() {
    let url = Bundle.module.url(forResource: "LoaderTests", withExtension: "json")
    let dir = url?.deletingLastPathComponent()

    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: String(true),
      Decoy.Constants.mockDirectory: dir!.absoluteString,
      Decoy.Constants.mockFilename: "LoaderTests.json"
    ]

    Decoy.shared.setUp(session: Session(), processInfo: processInfo)
    XCTAssertFalse(Decoy.shared.queue.queuedResponses.isEmpty)
  }

  func test_dispatchNextQueuedResponse_shouldCallCompletion() {
    guard let data = try? JSONSerialization.data(withJSONObject: ["A": "B"]) else { return XCTFail(#function) }
    let response = Stub.Response(data: data, urlResponse: nil, error: nil)
    let Stub = Stub(url: url, response: response)

    Decoy.shared.queue.queue(Stub: Stub)
    _ = Decoy.shared.dispatchNextQueuedResponse(for: url) { data, _, _ in
      guard let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any] else {
        return XCTFail(#function)
      }

      guard let result = json["A"] as? String else { return XCTFail(#function) }

      XCTAssertEqual(result, "B")
    }
  }
}

private extension DecoyTests {

  var url: URL {
    URL(string: "A")!
  }
}
