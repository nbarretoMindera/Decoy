import Foundation

/// The `Decoy` enum is the core of the library, and allows you to queue mocked responses
/// to calls to specific endpoints via the `queue` and `queueValidResponse` methods.
public class Decoy {
  public struct Constants {
    public static let isXCUI = "Decoy_IS_XCUI"
    public static let isRecording = "Decoy_IS_RECORDING"
    public static let mockDirectory = "Decoy_MOCK_DIRECTORY"
    public static let mockFilename = "Decoy_MOCK_FILENAME"
    public static let mocksFolder = "__Mocks__"
  }

  /// Singleton used to access Decoy from the outside without the need to instantiate it.
  public static let shared = Decoy()

  /// Performs initial setup for Decoy. Should be called as soon as possible after your app launches
  /// so that calls made immediately following app launch can be mocked, if required. Early exits
  /// immediately if not in the context of UI testing to avoid unnecessary processing.
  ///
  /// - Parameters:
  ///   - processInfo: An injectable instance of `ProcessInfo` used to check environment variables.
  public func setUp(session: SessionInterface, processInfo: ProcessInfo = .processInfo) {
    self.session = session

    guard isXCUI(processInfo: processInfo) else { return }
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
  public func isXCUI(processInfo: ProcessInfo = .processInfo) -> Bool {
    processInfo.environment[Constants.isXCUI] == String(true)
  }

  /// Used to ascertain whether or not Decoy is currently running within the context of a `DecoyTestCase`.
  public static func isXCUI(processInfo: ProcessInfo = .processInfo) -> Bool {
    processInfo.environment[Constants.isXCUI] == String(true)
  }

  /// A `URLSession` set to this variable will have its scheduled data tasks checked for suitable mocks.
  public var session: SessionInterface?

  /// A queue, handling the management of responses into and out of the response queue.
  var queue: QueueInterface = Queue()

  /// A loader, used to read data from a JSON mock file and parse it into a mocked response.
  var loader: LoaderInterface = Loader()

  /// A recorder, used to write recorded mocks out to disk.
  var recorder: RecorderInterface = Recorder()

  /// Dispatches the next queued response for the provided URL. Checks the queued response array for responses
  /// matching the given URL, and returns and removes the most recently added.
  ///
  /// - Parameters:
  ///   - url: The url for which the next queued `response` will return.
  ///   - completion: A closure to be called with the queued response.
  func dispatchNextQueuedResponse(for url: URL, to completion: @escaping DataTask.CompletionHandler) -> Bool {
    queue.dispatchNextQueuedResponse(for: url, to: completion)
  }
}
