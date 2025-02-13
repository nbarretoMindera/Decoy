import Foundation
import Decoy

class MockProcessInfo: ProcessInfo {
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
