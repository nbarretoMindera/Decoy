@testable import Decoy
import Foundation
import XCTest

struct WriteWaiter {
  /// Polls the given file URL until the Loader returns at least one stub, or the timeout expires.
  static func waitForMocksToBeWritten(at url: URL, timeout: TimeInterval = 1) {
    let startTime = Date()
    let loader = Loader()
    while Date().timeIntervalSince(startTime) < timeout {
      if let stubs = loader.loadJSON(from: url), !stubs.isEmpty {
        return
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    XCTFail("Timed out waiting for mocks to be written to disk")
  }
}
