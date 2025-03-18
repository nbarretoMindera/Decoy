import Foundation

/// The `Decoy` enum serves as the core of the Decoy library, allowing you to queue and manage
/// mocked responses for network calls. It provides methods to:
/// - Queue mocked responses for specific endpoints.
/// - Intercept network requests and return predefined responses.
/// - Load and record network interactions for UI testing scenarios.
public enum Decoy {

  /// Constants used throughout the Decoy framework.
  public struct Constants {
    /// Indicates whether the application is running within an `XCUI` test environment.
    public static let isXCUI = "Decoy_IS_XCUI"
    /// Defines the mode in which Decoy operates (recording, offline, or live if unmocked).
    public static let mode = "Decoy_MODE"
    /// The directory where Decoy stores mock data.
    public static let mockDirectory = "Decoy_MOCK_DIRECTORY"
    /// The filename of the mock data file.
    public static let mockFilename = "Decoy_MOCK_FILENAME"
    /// The folder used to store mock files.
    public static let mocksFolder = "__Mocks__"
  }

  /// Defines the different operating modes for Decoy.
  public enum Mode: String {
    /// **Record Mode:** Captures real network responses and stores them as mocks.
    case record
    /// **Force Offline Mode:** Only serves responses from stored mock data, never making real network requests.
    case forceOffline
    /// **Live If Unmocked Mode:** Uses stored mocks if available but allows live network requests if no mock exists.
    case liveIfUnmocked
  }

  /// A `Session` instance that intercepts network requests and checks for mock responses.
  public static var session: SessionInterface?

  /// Provides access to the wrapped `URLSession` instance, allowing Decoy to integrate seamlessly.
  public static var urlSession: URLSession? {
    session as? URLSession
  }

  /// Handles the management of queued responses, controlling the order in which mocks are served.
  static var queue: QueueInterface = Queue()

  /// Responsible for loading mock responses from a JSON file.
  static var loader: LoaderInterface = Loader()

  /// Handles recording network responses for future playback.
  static var recorder: RecorderInterface = Recorder()

  /// Sets up Decoy, configuring it for intercepting and mocking network requests.
  ///
  /// This method should be called as soon as possible after the app launches to ensure that network calls
  /// can be mocked immediately. It exits early if not running in an `XCUI` test environment to avoid unnecessary processing.
  ///
  /// - Parameters:
  ///   - session: A `URLSession` instance to be wrapped by Decoy for intercepting network requests. Defaults to `.shared`.
  ///   - processInfo: A `ProcessInfo` instance used to check for relevant environment variables.
  ///
  /// This method:
  /// 1. Initializes a `Session` instance to wrap the provided `URLSession`.
  /// 2. Checks if the app is running within an `XCUI` test environment.
  /// 3. Loads mock data from the file system if applicable.
  /// 4. Queues the loaded mock responses for later use.
  public static func setUp(
    session: URLSession = .shared,
    processInfo: ProcessInfo = .processInfo
  ) {
    // Initialize the Decoy session to wrap the provided URLSession.
    self.session = Session(mocking: session)

    // Exit early if not running in an XCUI test environment.
    guard Decoy.isXCUI(processInfo: processInfo) else { return }

    // Fetch the mock storage directory and filename from the environment variables.
    guard let directory = processInfo.environment[Decoy.Constants.mockDirectory] else { return }
    guard let filename = processInfo.environment[Decoy.Constants.mockFilename] else { return }

    // Construct the URL where the mock file should be loaded.
    var url = URL(safePath: directory)
    url.safeAppend(path: filename)

    // Load JSON mock data and queue responses for future use.
    guard let json = loader.loadJSON(from: url) else { return }
    json.forEach {
      queue.queue(Stub: Stub(url: $0.url, response: $0.response))
    }
  }

  /// Determines whether Decoy is currently running within an `XCUI` test environment.
  ///
  /// - Parameter processInfo: The `ProcessInfo` instance used to check environment variables.
  /// - Returns: `true` if running within an `XCUI` test environment, otherwise `false`.
  ///
  /// This method verifies the `Decoy.Constants.isXCUI` environment variable.
  public static func isXCUI(processInfo: ProcessInfo = .processInfo) -> Bool {
    processInfo.environment[Constants.isXCUI] == String(true)
  }

  /// Dispatches the next queued response for a given URL.
  ///
  /// This method checks the queued response array for a mock response matching the provided URL.
  /// If a matching response exists, it is removed from the queue and passed to the completion handler.
  ///
  /// - Parameters:
  ///   - url: The `URL` for which a mock response should be retrieved.
  ///   - completion: A closure that receives the queued response data.
  /// - Returns: `true` if a queued response was dispatched, otherwise `false`.
  ///
  /// This method allows Decoy to simulate network responses in a controlled manner during UI testing.
  static func dispatchNextQueuedResponse(for url: URL, to completion: @escaping DataTask.CompletionHandler) -> Bool {
    queue.dispatchNextQueuedResponse(for: url, to: completion)
  }
}
