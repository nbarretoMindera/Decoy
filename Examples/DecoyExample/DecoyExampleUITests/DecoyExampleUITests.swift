import DecoyXCUI
import XCTest

final class DecoyExampleUITests: DecoyTestCase {
  /// To use Decoy, all you need to do from the XCUITest side is `import DecoyXCUI`, subclass `DecoyTestCase`, and
  /// override its `setUp` method, passing in your preferred test mode.
  /// If you pass `.record`, Decoy will automatically call your real APIs, capture responses, and record them to disk.
  /// If you pass `.liveIfUnmocked`, Decoy will look for a previously-recorded mock, use it if available, or use the real API if not.
  /// If you pass `.forceOffline`, Decoy will look for mocks, use them if available, and fail if a mock is not available.
  override func setUp() {
    super.setUp(mode: .record)
    app.launch()
  }

  /// The tests themselves are stock `XCUITest`, and no other changes are needed.
  func test_example_oneCallToOneEndpoint() {
    app.buttons["Fetch Apple"].firstMatch.tap()
    XCTAssert(app.staticTexts["Apple"].waitForExistence(timeout: 5))
  }

  func test_example_twoCallsToSameEndpoint() {
    app.buttons["Fetch Apple"].firstMatch.tap()
    XCTAssert(app.staticTexts["Apple"].waitForExistence(timeout: 5))
    app.buttons["Fetch Banana"].firstMatch.tap()
    XCTAssert(app.staticTexts["Banana"].waitForExistence(timeout: 5))
  }

  func test_example_twoCallsToDifferentEndpoints() {
    app.buttons["Fetch Apple"].firstMatch.tap()
    XCTAssert(app.staticTexts["Apple"].waitForExistence(timeout: 5))
    app.buttons["Fetch Cat Fact"].firstMatch.tap()
    XCTAssert(app.staticTexts["..."].waitForNonExistence(timeout: 5))
  }
}
