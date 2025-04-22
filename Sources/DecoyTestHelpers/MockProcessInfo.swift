import Foundation
import Decoy

public class MockProcessInfo: ProcessInfo, @unchecked Sendable {
  public var mockedIsRunningXCUI = false
  public var mockedEnvironment: [String: String]?

  public override var environment: [String: String] {
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
