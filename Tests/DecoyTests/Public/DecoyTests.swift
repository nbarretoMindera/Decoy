@testable import Decoy
import XCTest
import Foundation

final class DecoyTests: XCTestCase {
  override func setUp() {
    super.setUp()
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

    let decoy = Decoy(processInfo: processInfo)
    XCTAssertEqual(decoy.mode, .liveIfUnmocked, "An   mode should default to .liveIfUnmocked")
  }

  func test_setUp_shouldNotQueue_whenLoaderFails() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mockDirectory: "https://example.com",
      Decoy.Constants.mockFilename: "nonexistent.json"
    ]

    let decoy = Decoy(processInfo: processInfo)

    let originalLoader = decoy.loader
    decoy.loader = FailingLoader()

    decoy.setUp()
    XCTAssert(decoy.queue.queuedResponses.isEmpty, "Queue should remain empty when Loader fails to load JSON")

    decoy.loader = originalLoader
  }

  func test_isXCUI_shouldReturnTrue_whenEnvironmentIsSet() {
    let mockedProcessInfo = MockProcessInfo()
    mockedProcessInfo.mockedIsRunningXCUI = true
    let decoy = Decoy(processInfo: mockedProcessInfo)
    XCTAssert(decoy.isXCUI)
  }

  func test_isXCUI_shouldReturnFalse_whenEnvironmentIsNotSet() {
    let mockedProcessInfo = MockProcessInfo()
    mockedProcessInfo.mockedIsRunningXCUI = false
    let decoy = Decoy(processInfo: mockedProcessInfo)
    XCTAssertFalse(decoy.isXCUI)
  }

  func test_mode_defaults_to_liveIfUnmocked_whenNotSet() {
    let processInfo = MockProcessInfo()
    let decoy = Decoy(processInfo: processInfo)
    XCTAssertEqual(decoy.mode, .liveIfUnmocked)
  }

  func test_mode_returns_record_whenSet() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [Decoy.Constants.mode: "record"]
    let decoy = Decoy(processInfo: processInfo)
    XCTAssertEqual(decoy.mode, .record)
  }

  func test_setUp_shouldNotLoadJSON_whenXCUIIsNotRunning() {
    let processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = false
    let decoy = Decoy(processInfo: processInfo)
    XCTAssert(decoy.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldNotLoadJSON_whenMockDirectoryIsNotSet() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mockFilename: "B"
    ]
    let decoy = Decoy(processInfo: processInfo)
    XCTAssert(decoy.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldNotQueue_whenMockFilenameIsNotSet() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mockDirectory: "B"
    ]
    let decoy = Decoy(processInfo: processInfo)
    XCTAssert(decoy.queue.queuedResponses.isEmpty)
  }

  func test_setUp_shouldLoadJSON_whenURLContainsValidJSON() {
    let url = Bundle.testing()!

    let processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = true
    processInfo.mockedEnvironment = [
      Decoy.Constants.mode: "record",
      Decoy.Constants.mockDirectory: url.absoluteString,
      Decoy.Constants.mockFilename: "LoaderTest.json"
    ]

    let decoy = Decoy(processInfo: processInfo)
    XCTAssertFalse(decoy.queue.queuedResponses.isEmpty)
  }
}
