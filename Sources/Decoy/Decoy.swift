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
    /// Environment variable key for the directory where mock files specific to the current test case are stored.
    public static let mockDirectory = "DECOY_MOCK_DIRECTORY"
    /// Environment variable key for the directory where shared mocks across all test cases in the suite are stored.
    public static let sharedMockDirectory = "DECOY_SHARED_MOCK_DIRECTORY"
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
  var queue: QueueInterface

  /// The loader used to read mocks from a JSON file.
  var loader: LoaderInterface

  /// The log used to print debug statements that can be read while running tests in a separate sandbox.
  let logger: LoggerInterface

  /// The recorder that writes out live network responses.
  let recorder: RecorderInterface

  /// The `ProcessInfo` instance used to access environment variables.
  let processInfo: ProcessInfo

  /// A singleton used to facilitate init-less usage of Decoy in apps. Uses default `processInfo`, etc.
  public static var shared: Decoy = .init()

  /// Logs an informational message.
  /// - Parameter message: The message to log.
  public func logInfo(_ message: String) { logger.info(message) }

  /// Logs a warning message.
  /// - Parameter message: The message to log.
  public func logWarning(_ message: String) { logger.warning(message) }

  /// Logs an error message.
  /// - Parameter message: The message to log.
  public func logError(_ message: String) { logger.error(message) }

  /// An accessor used by GraphQL interceptors to fetch the next queued response.
  public func nextQueuedResponse(for identifier: Stub.Identifier) -> Stub.Response? {
    queue.nextQueuedResponse(for: identifier)
  }

  /// An accessor used by GraphQL interceptors to record a response.
  public func record(identifier: Stub.Identifier, data: Data?, response: HTTPURLResponse?, error: Error?) {
    recorder.record(identifier: identifier, data: data, response: response, error: error)
  }

  /// Initializes a new Decoy instance with default components.
  ///
  /// This initializer is intended for typical usage where Decoy manages its own dependencies.
  public convenience init() {
    let logger = Logger()

    self.init(
      recorder: Recorder(processInfo: .processInfo, writer: Writer(processInfo: .processInfo, logger: logger), logger: logger),
      queue: Queue(isXCUI: Decoy.isXCUI, logger: logger),
      loader: Loader(isXCUI: Decoy.isXCUI),
      logger: logger,
      processInfo: .processInfo
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
    self.logger = logger
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

  public static func setUp() {
    guard Decoy.isXCUI else { return }
    Decoy.shared.setUp()
  }

  /// Indicates whether the app is running in a UI test environment without needing to instantiate a Decoy instance.
  ///
  /// This property reads the `DECOY_IS_XCUI` environment variable from the stock `processInfo` instance
  /// and returns `true` if it is set to `"true"`. It is used in app codebases to early exit from Decoy.
  public static var isXCUI: Bool {
    ProcessInfo.processInfo.environment[Constants.isXCUI] == "true"
  }
}

/// This extension contains internal methods not to be used publicly, but which may be used in testing.
extension Decoy {
  /// Indicates whether the app is running in a UI test environment.
  ///
  /// This property reads the `DECOY_IS_XCUI` environment variable and returns `true` if it is set to `"true"`.
  /// It is used internally to determine whether to activate Decoy's mocking behavior.
  var isXCUI: Bool {
    processInfo.environment[Constants.isXCUI] == "true"
  }

  /// Returns a `URLSession` configured to intercept network requests.
  ///
  /// When running in UI tests, your app should use this session so that all network requests
  /// are intercepted by Decoy's interception mechanisms (e.g., `DecoyURLProtocol`), ensuring that
  /// mock responses are returned or live responses are recorded as needed.
  ///
  /// - Note: This session configuration prepends Decoy's protocol to the session's protocol classes.
  static var urlSession: URLSession {
    let config = URLSessionConfiguration.default

    /// Prepend Decoy's interception mechanism (e.g., DecoyURLProtocol) to intercept requests.
    if Decoy.isXCUI {
      config.protocolClasses?.insert(DecoyURLProtocol.self, at: 0)
    }

    return URLSession(configuration: config)
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
  func setUp() {
    /// Only proceed if the app is running in a UI test environment.
    guard isXCUI else { return }

    /// Register the URL protocol.
    DecoyURLProtocol.register(decoy: self)

    /// Retrieve the directory and filename for the mocks from environment variables.
    guard let directory = processInfo.environment[Constants.mockDirectory],
          let filename = processInfo.environment[Constants.mockFilename] else {
      logError("setUp: Missing environment variables for mock directory or filename.")
      return
    }

    /// Create a URL for the mock file using safe URL initializers.
    var testSpecificMocksURL = URL(safePath: directory)
    testSpecificMocksURL.safeAppend(path: filename)

    /// If a path to shared mocks (i.e. those which should be applied to the entire suite) was provided,
    /// load them first to ensure that any test-specific mocks will override them in the FILO queue.
    if let sharedMocksDirectory = processInfo.environment[Constants.sharedMockDirectory] {
      var sharedMocksURL = URL(safePath: sharedMocksDirectory)
      sharedMocksURL.safeAppend(path: "shared.json")

      do {
        try loader.loadJSON(from: sharedMocksURL)?.forEach { stub in
          queue.queue(stub: stub)
          logInfo("setUp: Queued shared decoy for \(stub.identifier)")
        }
      } catch {
        logError("setUp: Failed to load shared mocks: \(error.localizedDescription)")
      }
    } else {
      logInfo("setUp: No shared decoys found – path not provided.")
    }

    /// Queue each loaded test-specific stub for later retrieval.
      do {
        try loader.loadJSON(from: testSpecificMocksURL)?.forEach { stub in
          queue.queue(stub: stub)
          logInfo("setUp: Queued decoy for \(stub.identifier)")
         }
      } catch {
        logError("setUp: Failed to load specific mocks: \(error.localizedDescription)")
      }
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
}

public extension URLSession {
  static var decoy: URLSession {
    Decoy.urlSession
  }
}

public extension URLSessionConfiguration {
  func insertDecoy() {
    guard Decoy.isXCUI else { return }
    protocolClasses = [DecoyURLProtocol.self] + (protocolClasses ?? [])
  }
}
