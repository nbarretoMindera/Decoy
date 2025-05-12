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

  /// Log streamer used to parse logs saved to /tmp/ by Decoy and display them neatly in the XCTest output.
  var logStream: LogStream!

  /// Sets up the test environment with a specified mock directory and mode.
  ///
  /// - Parameters:
  ///   - path: The file path of the calling test case. Defaults to `#filePath` to determine the calling file dynamically.
  ///   - mode: The `Decoy.Mode` to use for handling network responses. Defaults to `.liveIfUnmocked`.
  ///
  /// This method:
  /// 1. Calls `super.setUp()` to ensure the XCTest lifecycle functions correctly.
  /// 2. Assigns a logger to be able to print useful output to the console during UI testing, which occurs in a separate process.
  /// 3. Determines the directory where mock data should be stored.
  /// 4. Configures the `XCUIApplication` instance with the correct launch environment for mock data usage.
  public func setUp(
    testSpecificMocksPath: String = #filePath,
    suiteSpecificMocksPath: String? = nil,
    mode: Decoy.Mode = .liveIfUnmocked
  ) {
    super.setUp()

    // Set up our log stream to begin reading from /tmp/.
    logStream = LogStream(testCase: self)

    // Ensure we have a directory to write stubs to.
    guard let directory = buildDirectoryForStub(path: testSpecificMocksPath) else {
      return XCTFail("Could not generate path to which to write stub.")
    }

    var sharedMocksDirectory: String?
    if let suiteSpecificMocksPath {
      sharedMocksDirectory = buildSharedMocksDirectory(path: suiteSpecificMocksPath)
    }

    // If recording, wipe the previous mock file before making a new one.
    if mode == .record {
      guard let directory = buildDirectoryForStub(path: testSpecificMocksPath) else {
        return XCTFail("Record mode was specified, but could not clear existing decoys.")
      }
      let path = directory + "/\(mockName).json"
      try? FileManager.default.removeItem(atPath: path)
    }

    // Configure and make the app available to tests.
    app = appWithConfiguredLaunchEnvironment(
      mockDirectory: directory,
      sharedMockDirectory: sharedMocksDirectory,
      mode: mode
    )
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
  private func buildDirectoryForStub(path: String) -> String? {
    var url = URL(string: path)?.deletingLastPathComponent()
    url?.safeAppend(path: Decoy.Constants.mocksFolder)
    return url?.absoluteString
  }

  private func buildSharedMocksDirectory(path: String) -> String {
    let testRoot = URL(fileURLWithPath: path)
    let sharedPath = testRoot
      .appendingPathComponent("__Decoys__")

    print(sharedPath.path)

    return sharedPath.path
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
  ///    - `Decoy.Constants.mockDirectory` → Specifies where mock data is stored.
  ///    - `Decoy.Constants.mockFilename` → Defines the filename for mock data storage.
  private func appWithConfiguredLaunchEnvironment(
    mockDirectory: String,
    sharedMockDirectory: String?,
    mode: Decoy.Mode
  ) -> XCUIApplication {
    let app = XCUIApplication()

    print(mockDirectory)
    print(sharedMockDirectory)

    app.launchEnvironment[Decoy.Constants.mode] = mode.rawValue
    app.launchEnvironment[Decoy.Constants.isXCUI] = String(true)
    app.launchEnvironment[Decoy.Constants.mockDirectory] = mockDirectory
    app.launchEnvironment[Decoy.Constants.sharedMockDirectory] = sharedMockDirectory
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

