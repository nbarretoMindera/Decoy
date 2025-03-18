import Foundation

public enum Decoy {
  /// Constants used throughout Decoy.
  public struct Constants {
    public static let isXCUI = "Decoy_IS_XCUI"
    public static let mode = "Decoy_MODE"
    public static let mockDirectory = "Decoy_MOCK_DIRECTORY"
    public static let mockFilename = "Decoy_MOCK_FILENAME"
    public static let mocksFolder = "__Mocks__"
  }

  /// The operating mode for Decoy.
  public enum Mode: String {
    case record
    case forceOffline
    case liveIfUnmocked
  }

  /// The queue storing mocked responses.
  static var queue: QueueInterface = Queue()

  /// The loader used to read mocks from a JSON file.
  static var loader: LoaderInterface = Loader()

  /// The recorder that writes out recorded responses.
  static var recorder: RecorderInterface = Recorder()

  static var mode: Decoy.Mode {
    guard let modeString = ProcessInfo.processInfo.environment[Constants.mode] else { return .liveIfUnmocked }
    return Decoy.Mode(rawValue: modeString) ?? .liveIfUnmocked
  }

  public static func setUp(session: URLSession = .shared, processInfo: ProcessInfo = .processInfo) {
    // Only proceed if we're running in a UI test environment.
    guard isXCUI(processInfo: processInfo) else { return }

    // Get the directory and filename from environment variables.
    guard let directory = processInfo.environment[Constants.mockDirectory],
          let filename = processInfo.environment[Constants.mockFilename] else {
      print("Decoy.setUp: Missing environment variables for mock directory or filename.")
      return
    }

    // Create a URL from the directory using a safe initializer.
    var url = URL(safePath: directory)
    url.safeAppend(path: filename)

    // Use the Loader to load the JSON mocks.
    guard let stubs = loader.loadJSON(from: url) else {
      print("Decoy.setUp: Failed to load mocks from \(url.absoluteString)")
      return
    }

    // Queue each loaded stub.
    stubs.forEach { stub in
      queue.queue(Stub: stub)
    }

    print("Decoy.setUp: Loaded and queued \(stubs.count) mocks from \(url.absoluteString)")
  }

  /// Returns a URLSession configured to use DecoyURLProtocol.
  ///
  /// In UI tests, your app should use this session so that all requests are intercepted.
  public static var urlSession: URLSession {
    let config = URLSessionConfiguration.default
    // Prepend our custom URLProtocol so it intercepts requests.
    config.protocolClasses = [DecoyURLProtocol.self] + (config.protocolClasses ?? [])
    return URLSession(configuration: config)
  }

  /// Determines whether the app is running in a UI test environment.
  public static func isXCUI(processInfo: ProcessInfo = .processInfo) -> Bool {
    return processInfo.environment[Constants.isXCUI] == "true"
  }
}
