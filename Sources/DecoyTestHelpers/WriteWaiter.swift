@testable import Decoy
import Foundation
import XCTest

public enum RecorderWaiter {
  public static func wait(for recorder: RecorderInterface, timeout: TimeInterval = 2) {
    let expectation = XCTestExpectation(description: "Recorder flushed")
    recorder.flush {
      expectation.fulfill()
    }
    XCTWaiter().wait(for: [expectation], timeout: timeout)
  }
}
