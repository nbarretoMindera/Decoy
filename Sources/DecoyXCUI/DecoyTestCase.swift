import XCTest
import Decoy

/// A base test case to be inherited for tests that use `Decoy` for network request mocking.
///
/// This test case provides a standardized setup for configuring UI tests with mocked network responses.
/// It ensures that UI tests can access the correct mock directory and filename, and configures the app's
/// launch environment accordingly.
open class DecoyTestCase: XCTestCase {
  /// The instance of `XCUIApplication` used to interact with the UI.
  public var app: XCUIApplication!

  /// Sets up the test environment with a specified mock directory and mode.
  ///
  /// - Parameters:
  ///   - path: The file path of the calling test case. Defaults to `#filePath` to determine the calling file dynamically.
  ///   - mode: The `Decoy.Mode` to use for handling network responses. Defaults to `.liveIfUnmocked`.
  ///
  /// This method:
  /// 1. Calls `super.setUp()` to ensure the XCTest lifecycle functions correctly.
  /// 2. Determines the directory where mock data should be stored.
  /// 3. Configures the `XCUIApplication` instance with the correct launch environment for mock data usage.
  public func setUp(path: String = #filePath, mode: Decoy.Mode = .liveIfUnmocked) {
    super.setUp()

    guard let directory = buildDirectoryForStub(path: path, mode: mode) else {
      return XCTFail("Could not generate path to which to write stub.")
    }

    app = appWithConfiguredLaunchEnvironment(directory: directory, mode: mode)
  }

  /// Builds the directory path for storing mock data.
  ///
  /// - Parameters:
  ///   - path: The file path of the test file.
  ///   - mode: The `Decoy.Mode` defining how network responses should be handled.
  /// - Returns: A `String` representing the mock data directory path, or `nil` if the path could not be resolved.
  ///
  /// This method:
  /// 1. Converts the provided `path` into a `URL` (representing the test file's directory).
  /// 2. Appends `Decoy.Constants.mocksFolder` to define the mock storage location.
  /// 3. Returns the absolute string representation of the mock directory path.
  private func buildDirectoryForStub(path: String, mode: Decoy.Mode) -> String? {
    var url = URL(string: path)?.deletingLastPathComponent()
    url?.safeAppend(path: Decoy.Constants.mocksFolder)
    return url?.absoluteString
  }

  /// Configures an `XCUIApplication` instance with the necessary launch environment for Decoy.
  ///
  /// - Parameters:
  ///   - directory: The directory where mock data will be stored.
  ///   - mode: The `Decoy.Mode` to use for handling mock responses.
  /// - Returns: A configured `XCUIApplication` instance ready for UI testing.
  ///
  /// This method:
  /// 1. Creates a new `XCUIApplication` instance.
  /// 2. Sets key environment variables required by `Decoy`, including:
  ///    - `Decoy.Constants.mode` → Defines how requests should be handled.
  ///    - `Decoy.Constants.isXCUI` → Marks that the app is running in an XCUI test.
  ///    - `Decoy.Constants.mockDirectory` → Specifies where mock data is stored.
  ///    - `Decoy.Constants.mockFilename` → Defines the filename for mock data storage.
  private func appWithConfiguredLaunchEnvironment(directory: String, mode: Decoy.Mode) -> XCUIApplication {
    let app = XCUIApplication()

    app.launchEnvironment[Decoy.Constants.mode] = mode.rawValue
    app.launchEnvironment[Decoy.Constants.isXCUI] = String(true)
    app.launchEnvironment[Decoy.Constants.mockDirectory] = directory
    app.launchEnvironment[Decoy.Constants.mockFilename] = "\(mockName).json"

    return app
  }
}

// MARK: - Public Extensions

public extension DecoyTestCase {
  /// Determines the mock filename based on the test case name.
  ///
  /// - Returns: A string representing the mock filename.
  var mockName: String {
    let split = name.split(separator: " ")
    guard let last = split.last else { return "Unknown" }
    return last.replacingOccurrences(of: "]", with: "")
  }
}
