@testable import Decoy
import Foundation
import XCTest

enum RecorderWaiter {
  static func waitForFlush(timeout: TimeInterval = 2) {
    let expectation = XCTestExpectation(description: "Recorder flushed")
    Decoy.recorder.flush {
      expectation.fulfill()
    }
    XCTWaiter().wait(for: [expectation], timeout: timeout)
  }
}
