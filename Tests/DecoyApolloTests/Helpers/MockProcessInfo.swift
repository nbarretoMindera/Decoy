import Foundation
import Decoy

class MockProcessInfo: ProcessInfo, @unchecked Sendable {
  var mockedIsRunningXCUI = false
  var mockedEnvironment: [String: String]?

  override var environment: [String: String] {
    if var mockedEnvironment {
      mockedEnvironment[Decoy.Constants.isXCUI] = String(mockedIsRunningXCUI)
      return mockedEnvironment
    } else {
      return [
        Decoy.Constants.mockDirectory: "DecoyTests",
        Decoy.Constants.isXCUI: String(mockedIsRunningXCUI)
      ]
    }
  }
}
