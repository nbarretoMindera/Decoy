import Decoy
import Foundation

class MockProcessInfo: ProcessInfo, @unchecked Sendable {
  var mockedIsRunningXCUI = false
  var mockedEnvironment: [String: String]?

  override var environment: [String: String] {
    if let mockedEnvironment {
      return mockedEnvironment
    } else {
      return [
        Decoy.Constants.mockDirectory: "DecoyTests",
        Decoy.Constants.isXCUI: String(mockedIsRunningXCUI)
      ]
    }
  }
}
