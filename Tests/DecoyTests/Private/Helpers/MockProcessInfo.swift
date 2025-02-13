import Foundation
import MockMarks

class MockProcessInfo: ProcessInfo {
  var mockedIsRunningXCUI = false
  var mockedEnvironment: [String: String]?

  override var environment: [String: String] {
    if let mockedEnvironment {
      return mockedEnvironment
    } else {
      return [
        MockMarks.Constants.mockDirectory: "MockMarksTests",
        MockMarks.Constants.isXCUI: String(mockedIsRunningXCUI)
      ]
    }
  }
}
