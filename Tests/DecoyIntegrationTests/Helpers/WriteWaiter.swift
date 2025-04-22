@testable import Decoy
import Foundation
import XCTest

enum RecorderWaiter {
  static func waitForFlush(recorder: RecorderInterface, timeout: TimeInterval = 2) {
    let expectation = XCTestExpectation(description: "Recorder flushed")
    recorder.flush {
      expectation.fulfill()
    }
    XCTWaiter().wait(for: [expectation], timeout: timeout)
  }
}
