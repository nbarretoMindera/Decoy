import Foundation

/// The core of the Decoy mocking framework, which intercepts network requests to return
/// pre-configured mock responses or record live responses. Decoy is designed primarily for use
/// in UI tests to simulate network responses without performing real network calls.
///
/// Decoy operates by loading mock responses (stubs) from disk using a `Loader`, queuing them for
/// retrieval, and intercepting network requests via mechanisms such as a custom `URLProtocol`
/// or Apollo interceptors. Depending on the configured operating mode, Decoy can either return
/// queued mocks, perform live network requests, or record live responses for later playback.
///
/// ### Usage
/// To use Decoy, ensure your UI test environment sets the appropriate environment variables
/// (`DECOY_IS_XCUI`, `DECOY_MODE`, `DECOY_MOCK_DIRECTORY`, and `DECOY_MOCK_FILENAME`). At app launch
/// or test setup, call `setUp()` to load and queue mocks. Use `Decoy.urlSession` to obtain a
/// `URLSession` configured to intercept requests. The `reset()` method can be called between tests
/// to clear shared state.
///
/// Decoy integrates with other components like `Loader` (for reading mocks), `Writer` (for saving
/// recorded responses), and `Recorder` (for capturing live responses). It provides a centralized
/// mechanism to control network behavior during UI tests, improving test reliability and speed.
public class Decoy {
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
  /// This queue holds `Stub` objects keyed by their URL or identifier. When a network request is intercepted,
  /// Decoy retrieves the appropriate stub from this queue to return the mocked response instead of performing
  /// a live network request.
  public var queue: QueueInterface

  /// The loader used to read mocks from a JSON file.
  ///
  /// Responsible for reading mock definitions from disk, decoding them into `Stub` objects,
  /// and supplying them to Decoy for queuing and playback.
  var loader: LoaderInterface

  /// The log used to print debug statements that can be read while running tests in a separate sandbox.
  var logger: LoggerInterface = Logger()

  /// Logs an informational message.
  /// - Parameter message: The message to log.
  public func logInfo(_ message: String) { logger.info(message) }
  /// Logs a warning message.
  /// - Parameter message: The message to log.
  public func logWarning(_ message: String) { logger.warning(message) }
  /// Logs an error message.
  /// - Parameter message: The message to log.
  public func logError(_ message: String) { logger.error(message) }

  /// The `ProcessInfo` instance used to access environment variables.
  public var processInfo: ProcessInfo

  /// The recorder that writes out live network responses.
  ///
  /// When Decoy is in `.record` mode, the recorder captures live network responses and saves them
  /// as mock stubs for future test runs, enabling test replays without live network dependencies.
  public let recorder: RecorderInterface

  /// Initializes a new Decoy instance with default components.
  ///
  /// This initializer is intended for typical usage where Decoy manages its own dependencies.
  /// It assumes the current process info and a UI testing environment.
  public convenience init() {
    let logger = Logger()
    let isXCUI = true

    self.init(
      recorder: Recorder(processInfo: .processInfo, writer: Writer(processInfo: .processInfo, logger: logger), logger: logger),
      queue: Queue(isXCUI: isXCUI, logger: logger),
      loader: Loader(isXCUI: isXCUI),
      logger: logger,
      processInfo: .processInfo
    )
  }

  /// Initializes a new Decoy instance with a specified `ProcessInfo`.
  ///
  /// Use this initializer when you want to specify a different process info context, such as in testing environments.
  /// It assumes a UI testing environment.
  /// - Parameter processInfo: The `ProcessInfo` instance to use.
  convenience init(processInfo: ProcessInfo) {
    let logger = Logger()
    let isXCUI = true

    self.init(
      recorder: Recorder(processInfo: processInfo, writer: Writer(processInfo: processInfo, logger: logger), logger: logger),
      queue: Queue(isXCUI: isXCUI, logger: logger),
      loader: Loader(isXCUI: isXCUI),
      logger: logger,
      processInfo: processInfo
    )
  }

  /// Initializes a new Decoy instance with a specified `ProcessInfo` and custom `Recorder`.
  ///
  /// Use this initializer when you want to inject a custom recorder implementation, for example, during testing or when customizing recording behavior.
  /// - Parameters:
  ///   - processInfo: The `ProcessInfo` instance to use.
  ///   - recorder: The custom `RecorderInterface` instance.
  convenience init(processInfo: ProcessInfo, recorder: RecorderInterface) {
    let logger = Logger()
    let isXCUI = true

    self.init(
      recorder: recorder,
      queue: Queue(isXCUI: isXCUI, logger: logger),
      loader: Loader(isXCUI: isXCUI),
      logger: logger,
      processInfo: processInfo
    )
  }

  /// Initializes a new Decoy instance with all dependencies specified.
  ///
  /// This initializer is internal and primarily used for dependency injection and testing.
  /// - Parameters:
  ///   - recorder: The recorder responsible for saving live responses.
  ///   - queue: The queue managing stubbed responses.
  ///   - loader: The loader reading mock files.
  ///   - logger: The logger for debug output.
  ///   - processInfo: The process info for environment access.
  init(
    recorder: RecorderInterface,
    queue: QueueInterface,
    loader: LoaderInterface,
    logger: LoggerInterface,
    processInfo: ProcessInfo
  ) {
    self.recorder = recorder
    self.queue = queue
    self.loader = loader
    self.processInfo = processInfo

    setUp()
  }

  /// The current operating mode of Decoy.
  ///
  /// This property reads the `DECOY_MODE` environment variable to determine how Decoy should behave:
  /// - `.record`: Capture live responses.
  /// - `.forceOffline`: Only use mocks, fail if no mock available.
  /// - `.liveIfUnmocked`: Use live requests if no mock is queued.
  public var mode: Decoy.Mode {
    guard let modeString = processInfo.environment[Constants.mode] else { return .liveIfUnmocked }
    return Decoy.Mode(rawValue: modeString) ?? .liveIfUnmocked
  }

  /// Sets up Decoy by loading mocks from disk and queuing them for later use.
  ///
  /// This method should be called early in the app's launch or test setup phase when running in a UI test environment.
  /// It reads the mock directory and filename from environment variables, loads the mocks using the `Loader`,
  /// and enqueues each stub in the Decoy queue.
  ///
  /// If the environment variables are missing or loading fails, appropriate error messages are logged.
  ///
  /// - Note: This method is a no-op if the app is not running in a UI test environment.
  public func setUp() {
    // Only proceed if the app is running in a UI test environment.
    guard isXCUI else { return }

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

  /// Clears shared state between tests.
  ///
  /// This method empties the stub queue and resets the `DecoyURLProtocol` live session provider
  /// to a default session configuration without Decoy's interception protocol. It should be called
  /// between tests to ensure isolation and prevent state leakage.
  public func reset() {
    queue.clear()
    DecoyURLProtocol.liveSessionProvider = {
      let config = URLSessionConfiguration.default
      config.protocolClasses = config.protocolClasses?.filter { $0 != DecoyURLProtocol.self }
      return URLSession(configuration: config)
    }
  }

  /// Returns a `URLSession` configured to intercept network requests.
  ///
  /// When running in UI tests, your app should use this session so that all network requests
  /// are intercepted by Decoy's interception mechanisms (e.g., `DecoyURLProtocol`), ensuring that
  /// mock responses are returned or live responses are recorded as needed.
  ///
  /// - Note: This session configuration prepends Decoy's protocol to the session's protocol classes.
  public static var urlSession: URLSession {
    let config = URLSessionConfiguration.default
    // Prepend Decoy's interception mechanism (e.g., DecoyURLProtocol) to intercept requests.
    config.protocolClasses?.insert(DecoyURLProtocol.self, at: 0)
    return URLSession(configuration: config)
  }

  /// Indicates whether the app is running in a UI test environment.
  ///
  /// This property reads the `DECOY_IS_XCUI` environment variable and returns `true` if it is set to `"true"`.
  /// It is used internally to determine whether to activate Decoy's mocking behavior.
  public var isXCUI: Bool {
    processInfo.environment[Constants.isXCUI] == "true"
  }
}
