@testable import Decoy
import Foundation

class MockRecorder: RecorderInterface {
  var recordings = [[String: Any]]()
  var recordCallCount = 0
  var mockedShouldRecord: Bool = false
  var shouldRecord: Bool { mockedShouldRecord }

  func record(identifier: Stub.Identifier, data: Data?, response: HTTPURLResponse?, error: Error?) {
    recordCallCount += 1
    recordings.insert(["url": identifier.stringValue], at: 0)
  }
}
