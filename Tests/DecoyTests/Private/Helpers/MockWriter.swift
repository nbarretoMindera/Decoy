@testable import Decoy
import Foundation

class MockWriter: WriterInterface {
  var appendedRecordings: [[String: Any]] = []
  var appendWasCalled = false

  func append(recording: [String : Any]) throws {
    appendWasCalled = true
    appendedRecordings.append(recording)
  }
}
