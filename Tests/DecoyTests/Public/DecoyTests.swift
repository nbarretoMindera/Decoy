@testable import Decoy
import Foundation
import XCTest

final class DecoyTests: XCTestCase {
  override func setUp() {
    super.setUp()
    Decoy.queue.queuedResponses.removeAll()
  }

  func test_urlSession_shouldSucceed_whenSessionIsURLSession() {
    Decoy.setUp()
    XCTAssertNotNil(Decoy.urlSession)
  }

  func test_isXCUI_shouldReferToProcessInfo_whenTrue() {
    let mockedProcessInfo = MockProcessInfo()
    mockedProcessInfo.mockedIsRunningXCUI = true
    XCTAssert(Decoy.isXCUI(processInfo: mockedProcessInfo))
  }

  func test_isXCUI_shouldReferToProcessInfo_whenFalse() {
    let mockedProcessInfo = MockProcessInfo()
    mockedProcessInfo.mockedIsRunningXCUI = false
    XCTAssertFalse(Decoy.isXCUI(processInfo: mockedProcessInfo))
  }

  func test_setUp_shouldNotLoadJSON_whenXCUIIsNotRunning() {
    let processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = false
    Decoy.setUp(processInfo: processInfo)
    XCTAssert(Decoy.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldNotLoadJSON_whenMockDirectoryIsNotSet() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: String(true),
      Decoy.Constants.mockFilename: "B"
    ]
    Decoy.setUp(processInfo: processInfo)
    XCTAssert(Decoy.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldNotQueue_whenMockFilenameIsNotSet() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: String(true),
      Decoy.Constants.mockDirectory: "B"
    ]
    Decoy.setUp(processInfo: processInfo)
    XCTAssert(Decoy.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldLoadJSON_whenURLDoesContainJSON() {
    let url = Bundle.testing()

    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.mode: String("record"),
      Decoy.Constants.isXCUI: String(true),
      Decoy.Constants.mockDirectory: url!.absoluteString,
      Decoy.Constants.mockFilename: "LoaderTest.json"
    ]

    Decoy.setUp(processInfo: processInfo)
    XCTAssertFalse(Decoy.queue.queuedResponses.isEmpty)
  }
}

private extension DecoyTests {
  var url: URL {
    URL(string: "A")!
  }
}
