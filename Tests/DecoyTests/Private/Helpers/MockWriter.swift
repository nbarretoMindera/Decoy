@testable import Decoy
import Foundation

class MockWriter: WriterInterface {
  var appendWasCalled = false

  func append(recording: [String : Any]) throws {
    appendWasCalled = true
  }
}
