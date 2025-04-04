import Foundation

/// The core of the Decoy mocking framework, which intercepts network requests to return
/// pre-configured mock responses or record live responses. Decoy is designed for use
/// primarily in UI tests so that the app can simulate network responses without performing
/// real network calls.
///
/// Decoy works by loading mocks from disk (via a Loader), queuing them for later retrieval,
/// and using either a custom URLProtocol, Apollo interceptors, or another network interception mechanism
/// to intercept requests and return either the queued mock or a live response (depending on the operating mode).
public enum Decoy {
  /// Constants used throughout the Decoy framework.
  public struct Constants {
    /// Environment variable key to determine if the app is running in a UI test environment.
    public static let isXCUI = "DECOY_IS_XCUI"
    /// Environment variable key for specifying Decoy’s operating mode.
    public static let mode = "DECOY_MODE"
    /// Environment variable key for the directory where mock files are stored.
    public static let mockDirectory = "DECOY_MOCK_DIRECTORY"
    /// Environment variable key for the filename of the mock file.
    public static let mockFilename = "DECOY_MOCK_FILENAME"
    /// The folder name used for storing decoys.
    public static let mocksFolder = "__Decoys__"
  }

  /// The operating mode for Decoy.
  ///
  /// - record: Live network responses are recorded for later playback.
  /// - forceOffline: Only queued mocks are used; if a mock is not available, an error is returned.
  /// - liveIfUnmocked: If no mock is available, a live network request is performed.
  public enum Mode: String {
    case record
    case forceOffline
    case liveIfUnmocked
  }

  /// The queue that stores mocked responses.
  ///
  /// Mocks are enqueued as `Stub` objects keyed by their URL, allowing Decoy's interception
  /// mechanisms to retrieve and return the appropriate mock for a given request.
  public static var queue: QueueInterface = Queue()

  /// The loader used to read mocks from a JSON file.
  ///
  /// The loader is responsible for reading a JSON file from disk, decoding its contents into an array
  /// of `Stub` objects, and returning them so they can be queued for later use.
  static var loader: LoaderInterface = Loader()

  /// The log used to print debug statements that can be read while running tests in a separate sandbox.
  static var logger: LoggerInterface = Logger()

  public static func logInfo(_ message: String) { logger.info(message) }
  public static func logWarning(_ message: String) { logger.warning(message) }
  public static func logError(_ message: String) { logger.error(message) }

  public static var processInfo: ProcessInfo = .processInfo

  /// The recorder that writes out live network responses.
  ///
  /// When in record mode, live responses are captured by the recorder so that they can be saved and
  /// used as mocks in future test runs.
  public static var recorder: RecorderInterface = Recorder()

  /// Helper to determine the operating mode from a given ProcessInfo.
  ///
  /// - Parameter processInfo: The ProcessInfo to inspect.
  /// - Returns: The Decoy mode based on the environment variable, defaulting to `.liveIfUnmocked`.
  public static func mode(for processInfo: ProcessInfo = Decoy.processInfo) -> Decoy.Mode {
    guard let modeString = processInfo.environment[Constants.mode] else { return .liveIfUnmocked }
    return Decoy.Mode(rawValue: modeString) ?? .liveIfUnmocked
  }

  /// Sets up Decoy by loading mocks from disk and queuing them for later use.
  ///
  /// This method should be called early in the app's launch (or in test setup) when running in a UI test
  /// environment. It reads the mock directory and filename from environment variables, loads the mocks using
  /// the Loader, and enqueues each stub in the Decoy queue.
  ///
  /// - Parameter processInfo: The ProcessInfo instance used to access environment variables. Defaults to `.processInfo`.
  public static func setUp(processInfo: ProcessInfo = .processInfo) {
    // Only proceed if the app is running in a UI test environment.
    guard isXCUI(processInfo: processInfo) else { return }

    // Store processInfo so others can use it later and it's consistent.
    self.processInfo = processInfo

    // Retrieve the directory and filename for the mocks from environment variables.
    guard let directory = processInfo.environment[Constants.mockDirectory],
          let filename = processInfo.environment[Constants.mockFilename] else {
      logError("setUp: Missing environment variables for mock directory or filename.")
      return
    }

    // Create a URL for the mock file using safe URL initializers.
    var url = URL(safePath: directory)
    url.safeAppend(path: filename)

    // Load the mocks from the JSON file.
    guard let stubs = loader.loadJSON(from: url) else {
      return logError("setUp: Failed to load mocks.")
    }

    // Queue each loaded stub for later retrieval.
    stubs.forEach { stub in
      queue.queue(stub: stub)
      logInfo("setUp: Queued decoy for \(stub.identifier)")
    }
  }

  /// Returns a URLSession configured to intercept network requests.
  ///
  /// When running in UI tests, your app should use this session so that all network requests
  /// are intercepted by Decoy's interception mechanisms - whether that is via a custom URLProtocol,
  /// Apollo interceptors, or another approach - ensuring that mock responses are returned or live
  /// responses are recorded as needed.
  public static var urlSession: URLSession {
    let config = URLSessionConfiguration.default
    // Prepend Decoy's interception mechanism (e.g., DecoyURLProtocol) to intercept requests.
    config.protocolClasses?.insert(DecoyURLProtocol.self, at: 0)
    return URLSession(configuration: config)
  }

  /// Determines whether the app is running in a UI test environment.
  ///
  /// - Parameter processInfo: The ProcessInfo instance used to read environment variables. Defaults to `.processInfo`.
  /// - Returns: `true` if the environment variable for UI testing is set to "true"; otherwise, `false`.
  public static func isXCUI(processInfo: ProcessInfo = Decoy.processInfo) -> Bool {
    return processInfo.environment[Constants.isXCUI] == "true"
  }
}
