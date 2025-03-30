import Foundation

/// The core of the Decoy mocking framework, which intercepts network requests to return
/// pre-configured mock responses or record live responses. Decoy is designed for use
/// primarily in UI tests so that the app can simulate network responses without performing
/// real network calls.
///
/// Decoy works by loading mocks from disk (via a Loader), queuing them for later retrieval,
/// and using a custom URLProtocol (DecoyURLProtocol) to intercept requests and return either
/// the queued mock or a live response (depending on the operating mode).
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
  /// Mocks are enqueued as `Stub` objects keyed by their URL, allowing DecoyURLProtocol to retrieve
  /// and return the appropriate mock for a given request.
  public static var queue: QueueInterface = Queue()

  /// The loader used to read mocks from a JSON file.
  ///
  /// The loader is responsible for reading a JSON file from disk, decoding its contents into an array
  /// of `Stub` objects, and returning them so they can be queued for later use.
  static var loader: LoaderInterface = Loader()

  /// The log used to print debug statements that can be read while running tests.
  ///
  static var log = Log()


  /// The recorder that writes out live network responses.
  ///
  /// When in record mode, live responses are captured by the recorder so that they can be saved and
  /// used as mocks in future test runs.
  public static var recorder: RecorderInterface = Recorder()

  /// Helper to determine the mode from a given ProcessInfo.
  ///
  /// - Parameter processInfo: The ProcessInfo to inspect.
  /// - Returns: The Decoy mode based on the environment variable, defaulting to `.liveIfUnmocked`.
  public static func mode(for processInfo: ProcessInfo = .processInfo) -> Decoy.Mode {
    log.log("Querying mode!!")
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

    // Retrieve the directory and filename for the mocks from environment variables.
    guard let directory = processInfo.environment[Constants.mockDirectory],
          let filename = processInfo.environment[Constants.mockFilename] else {
      print("Decoy.setUp: Missing environment variables for mock directory or filename.")
      return
    }

    // Create a URL for the mock file using safe URL initializers.
    var url = URL(safePath: directory)
    url.safeAppend(path: filename)

    // Load the mocks from the JSON file.
    guard let stubs = loader.loadJSON(from: url) else {
      print("Decoy.setUp: Failed to load mocks from \(url.absoluteString)")
      return
    }

    // Queue each loaded stub for later retrieval.
    stubs.forEach { stub in
      queue.queue(stub: stub)
    }

    print("Decoy.setUp: Loaded and queued \(stubs.count) mocks from \(url.absoluteString)")
  }

  /// Returns a URLSession configured to use DecoyURLProtocol.
  ///
  /// When running in UI tests, your app should use this session so that all network requests
  /// are intercepted by DecoyURLProtocol, allowing mock responses to be returned or live responses
  /// to be recorded as needed.
  public static var urlSession: URLSession {
    let config = URLSessionConfiguration.default
    // Prepend DecoyURLProtocol so that it intercepts requests.
    config.protocolClasses = [DecoyURLProtocol.self] + (config.protocolClasses ?? [])
    return URLSession(configuration: config)
  }

  /// Determines whether the app is running in a UI test environment.
  ///
  /// - Parameter processInfo: The ProcessInfo instance used to read environment variables. Defaults to `.processInfo`.
  /// - Returns: `true` if the environment variable for UI testing is set to "true"; otherwise, `false`.
  public static func isXCUI(processInfo: ProcessInfo = .processInfo) -> Bool {
    return processInfo.environment[Constants.isXCUI] == "true"
  }
}
