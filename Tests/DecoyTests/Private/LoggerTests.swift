import XCTest
@testable import Decoy

final class LoggerTests: XCTestCase {
  func test_log_logsMessageWithPrefix() {
    // Given: A TestLogger and a Log instance that uses it.
    let testLogger = TestLogger()
    let logUtility = Log(logger: testLogger)

    // When: We log a message.
    logUtility.log("Hello, world!")

    // Then: The TestLogger should record the message with the expected prefix.
    XCTAssertEqual(testLogger.messages.first, "🦆 Decoy: Hello, world!")
  }

  func test_log_logsMultipleMessages() {
    let testLogger = TestLogger()
    let logUtility = Log(logger: testLogger)

    logUtility.log("Message One")
    logUtility.log("Message Two")

    XCTAssertEqual(testLogger.messages, ["🦆 Decoy: Message One", "🦆 Decoy: Message Two"])
  }
}
