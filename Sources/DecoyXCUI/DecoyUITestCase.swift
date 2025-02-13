import XCTest
import Decoy

open class DecoyUITestCase: XCTestCase {

  public var app: XCUIApplication!

  public func setUp(path: String = #filePath, recording: Bool) {
    super.setUp()

    var url = URL(string: path)!.deletingLastPathComponent()
    url.safeAppend(path: Decoy.Constants.mocksFolder)

    app = XCUIApplication()

    app.launchEnvironment[Decoy.Constants.isRecording] = String(recording)
    app.launchEnvironment[Decoy.Constants.isXCUI] = String(true)
    app.launchEnvironment[Decoy.Constants.mockDirectory] = url.absoluteString
    app.launchEnvironment[Decoy.Constants.mockFilename] = "\(mockName).json"

    app.launch()
  }
}

public extension DecoyUITestCase {

  var mockName: String {
    name
      .split(separator: " ")
      .last!
      .replacingOccurrences(of: "]", with: "")
  }
}

private extension URL {

  init(safePath path: String) {
    if #available(iOS 16, *) {
      self.init(filePath: path)
    } else {
      self.init(fileURLWithPath: path)
    }
  }

  mutating func safeAppend(path: String) {
    if #available(iOS 16, *) {
      self.append(path: path)
    } else {
      self.appendPathComponent(path)
    }
  }
}
