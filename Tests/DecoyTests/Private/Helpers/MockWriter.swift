@testable import Decoy
import Foundation

class MockWriter: WriterInterface {
  var writeWasCalled = false

  func write(recordings: [[String: Any]]) {
    writeWasCalled = true
  }
}
