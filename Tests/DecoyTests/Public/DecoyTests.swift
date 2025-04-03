@testable import Decoy
import XCTest
import Foundation

final class DecoyTests: XCTestCase {
  override func setUp() {
    super.setUp()
    Decoy.queue.queuedResponses.removeAll()
  }

  func test_urlSession_shouldReturnAURLSession() {
    let session = Decoy.urlSession
    XCTAssertNotNil(session)
  }

  func test_urlSession_configuration_includesDecoyURLProtocol() {
    let session = Decoy.urlSession
    let config = session.configuration
    let containsDecoyProtocol = config.protocolClasses?.contains(where: { $0 == DecoyURLProtocol.self }) ?? false
    XCTAssert(containsDecoyProtocol, "Decoy.urlSession configuration should include DecoyURLProtocol")
  }

  func test_mode_returns_liveIfUnmocked_whenInvalidModeRawValue() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [Decoy.Constants.mode: "invalid"]

    let mode = Decoy.mode(for: processInfo)
    XCTAssertEqual(mode, .liveIfUnmocked, "An   mode should default to .liveIfUnmocked")
  }

  func test_setUp_shouldNotQueue_whenLoaderFails() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mockDirectory: "https://example.com",
      Decoy.Constants.mockFilename: "nonexistent.json"
    ]

    let originalLoader = Decoy.loader
    Decoy.loader = FailingLoader()

    Decoy.setUp(processInfo: processInfo)
    XCTAssert(Decoy.queue.queuedResponses.isEmpty, "Queue should remain empty when Loader fails to load JSON")

    Decoy.loader = originalLoader
  }

  func test_isXCUI_shouldReturnTrue_whenEnvironmentIsSet() {
    let mockedProcessInfo = MockProcessInfo()
    mockedProcessInfo.mockedIsRunningXCUI = true
    XCTAssert(Decoy.isXCUI(processInfo: mockedProcessInfo))
  }

  func test_isXCUI_shouldReturnFalse_whenEnvironmentIsNotSet() {
    let mockedProcessInfo = MockProcessInfo()
    mockedProcessInfo.mockedIsRunningXCUI = false
    XCTAssertFalse(Decoy.isXCUI(processInfo: mockedProcessInfo))
  }

  func test_mode_defaults_to_liveIfUnmocked_whenNotSet() {
    let processInfo = MockProcessInfo()
    XCTAssertEqual(Decoy.mode(for: processInfo), .liveIfUnmocked)
  }

  func test_mode_returns_record_whenSet() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [Decoy.Constants.mode: "record"]
    XCTAssertEqual(Decoy.mode(for: processInfo), .record)
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
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mockFilename: "B"
    ]
    Decoy.setUp(processInfo: processInfo)
    XCTAssert(Decoy.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldNotQueue_whenMockFilenameIsNotSet() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mockDirectory: "B"
    ]
    Decoy.setUp(processInfo: processInfo)
    XCTAssert(Decoy.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldLoadJSON_whenURLContainsValidJSON() {
    let url = Bundle.testing()!

    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.mode: "record",
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mockDirectory: url.absoluteString,
      Decoy.Constants.mockFilename: "LoaderTest.json"
    ]

    Decoy.setUp(processInfo: processInfo)
    XCTAssertFalse(Decoy.queue.queuedResponses.isEmpty)
  }
}
