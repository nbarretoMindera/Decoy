import XCTest
import Decoy

open class DecoyTestCase: XCTestCase {
  public var app: XCUIApplication!

  public func setUp(path: String = #filePath, recording: Bool) {
    super.setUp()

    guard let directory = buildDirectoryForStub(path: path, recording: recording) else {
      return XCTFail("Could not generate path to which to write stub.")
    }

    app = appWithConfiguredLaunchEnvironment(directory: directory, recording: recording)
  }

  private func buildDirectoryForStub(path: String, recording: Bool) -> String? {
    var url = URL(string: path)?.deletingLastPathComponent()
    url?.safeAppend(path: Decoy.Constants.mocksFolder)
    return url?.absoluteString
  }

  private func appWithConfiguredLaunchEnvironment(directory: String, recording: Bool) -> XCUIApplication {
    let app = XCUIApplication()

    app.launchEnvironment[Decoy.Constants.isRecording] = String(recording)
    app.launchEnvironment[Decoy.Constants.isXCUI] = String(true)
    app.launchEnvironment[Decoy.Constants.mockDirectory] = directory
    app.launchEnvironment[Decoy.Constants.mockFilename] = "\(mockName).json"

    return app
  }
}

public extension DecoyTestCase {
  var mockName: String {
    let split = name.split(separator: " ")
    guard let last = split.last else { return "Unknown" }
    return last.replacingOccurrences(of: "]", with: "")
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
      append(path: path)
    } else {
      appendPathComponent(path)
    }
  }
}
