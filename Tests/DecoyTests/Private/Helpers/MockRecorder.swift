@testable import Decoy
import Foundation

class MockRecorder: RecorderInterface {
  var recordings = [[String: Any]]()
  var recordCallCount = 0
  var mockedShouldRecord: Bool = false
  var shouldRecord: Bool { mockedShouldRecord }

  func record(url: URL, data: Data?, response: URLResponse?, error: Error?) {
    recordCallCount += 1
    recordings.insert(["url": url.absoluteString], at: 0)
  }
}
