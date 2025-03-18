import Foundation

/// The `Decoy` enum is the core of the library, and allows you to queue mocked responses
/// to calls to specific endpoints via the `queue` and `queueValidResponse` methods.
public enum Decoy {
  public struct Constants {
    public static let isXCUI = "Decoy_IS_XCUI"
    public static let mode = "Decoy_MODE"
    public static let mockDirectory = "Decoy_MOCK_DIRECTORY"
    public static let mockFilename = "Decoy_MOCK_FILENAME"
    public static let mocksFolder = "__Mocks__"
  }

  public enum Mode: String {
    case record
    case forceOffline
    case liveIfUnmocked
  }

  /// A `Session` set to this variable will have its scheduled data tasks checked for suitable mocks.
  public static var session: SessionInterface?

  /// The vanilla `URLSession` inside Decoy, used to pass it into call sites without importing Decoy.
  public static var urlSession: URLSession? {
    session as? URLSession
  }

  /// A queue, handling the management of responses into and out of the response queue.
  static var queue: QueueInterface = Queue()

  /// A loader, used to read data from a JSON mock file and parse it into a mocked response.
  static var loader: LoaderInterface = Loader()

  /// A recorder, used to write recorded mocks out to disk.
  static var recorder: RecorderInterface = Recorder()

  /// Performs initial setup for Decoy. Should be called as soon as possible after your app launches
  /// so that calls made immediately following app launch can be mocked, if required. Early exits
  /// immediately if not in the context of UI testing to avoid unnecessary processing.
  ///
  /// - Parameters:
  ///   - session: An instance of `Session` initialized with a `URLSession` to be mocked. Defaults to `URLSession.shared`.
  ///   - processInfo: An injectable instance of `ProcessInfo` used to check environment variables.
  public static func setUp(
    session: SessionInterface = Session(mocking: .shared),
    processInfo: ProcessInfo = .processInfo
  ) {
    self.session = session

    guard Decoy.isXCUI(processInfo: processInfo) else { return }
    guard let modeString = processInfo.environment[Decoy.Constants.mode] else { return }
    guard let mode = Decoy.Mode(rawValue: modeString) else { return }
    guard let directory = processInfo.environment[Decoy.Constants.mockDirectory] else { return }
    guard let filename = processInfo.environment[Decoy.Constants.mockFilename] else { return }

    var url = URL(safePath: directory)
    url.safeAppend(path: filename)

    guard let json = loader.loadJSON(from: url) else { return }

    json.forEach {
      queue.queue(Stub: Stub(url: $0.url, response: $0.response))
    }
  }

  /// Used to ascertain whether or not Decoy is currently running within the context of a `DecoyTestCase`.
  public static func isXCUI(processInfo: ProcessInfo = .processInfo) -> Bool {
    processInfo.environment[Constants.isXCUI] == String(true)
  }

  /// Dispatches the next queued response for the provided URL. Checks the queued response array for responses
  /// matching the given URL, and returns and removes the most recently added.
  ///
  /// - Parameters:
  ///   - url: The url for which the next queued `response` will return.
  ///   - completion: A closure to be called with the queued response.
  static func dispatchNextQueuedResponse(for url: URL, to completion: @escaping DataTask.CompletionHandler) -> Bool {
    queue.dispatchNextQueuedResponse(for: url, to: completion)
  }
}
