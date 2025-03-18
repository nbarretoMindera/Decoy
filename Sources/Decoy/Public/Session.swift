import Foundation

/// A protocol defining a wrapper around `URLSession` that supports mocking.
///
/// This protocol is designed to be implemented by a class that wraps `URLSession`,
/// allowing the creation of mockable data tasks.
public protocol SessionInterface {

  /// Initializes a new session that wraps an existing `URLSession`.
  ///
  /// - Parameters:
  ///   - mocking: The `URLSession` instance to be wrapped.
  ///   - processInfo: The `ProcessInfo` instance used to determine the session mode.
  init(mocking: URLSession, processInfo: ProcessInfo)

  /// The underlying `URLSession` instance used for networking.
  var urlSession: URLSession { get }

  /// Creates a data task with a `URLRequest`, returning a `URLSessionDataTask`.
  ///
  /// - Parameters:
  ///   - request: The `URLRequest` to be executed.
  ///   - completionHandler: A closure that handles the response, including data, URL response, and any error.
  /// - Returns: A `URLSessionDataTask` that can be resumed to start the request.
  func dataTask(
    with request: URLRequest,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask

  /// Creates a data task with a `URL`, returning a `URLSessionDataTask`.
  ///
  /// - Parameters:
  ///   - url: The `URL` to be requested.
  ///   - completionHandler: A closure that handles the response, including data, URL response, and any error.
  /// - Returns: A `URLSessionDataTask` that can be resumed to start the request.
  func dataTask(
    with url: URL,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask
}

/// A subclass of `URLSession` that integrates with Decoy for request mocking and response recording.
///
/// This class wraps a `URLSession` instance, overriding `dataTask` methods to inject Decoy's mocked `DataTask` objects.
/// It also records responses if Decoy's recorder is active.
public class Session: URLSession, SessionInterface, @unchecked Sendable {

  /// The underlying `URLSession` instance being wrapped.
  public let urlSession: URLSession

  /// The current mode of this session, determined by `ProcessInfo`.
  ///
  /// The mode is used to decide whether network calls should be mocked, recorded, or passed through as live requests.
  public let mode: Decoy.Mode

  /// The recorder responsible for capturing responses from network requests.
  ///
  /// This allows Decoy to store real responses when necessary for later playback.
  var recorder: RecorderInterface = Decoy.recorder

  /// Initializes a new `Session` instance, wrapping an existing `URLSession`.
  ///
  /// - Parameters:
  ///   - mocking: The `URLSession` instance to be wrapped. Defaults to `.shared`.
  ///   - processInfo: The `ProcessInfo` instance used to determine the Decoy mode. Defaults to `.processInfo`.
  ///
  /// The initialization reads the `Decoy.Constants.mode` environment variable to determine whether requests should
  /// be mocked, recorded, or made live. If no mode is found in the environment, it defaults to `.liveIfUnmocked`.
  required public init(mocking session: URLSession = .shared, processInfo: ProcessInfo = .processInfo) {
    self.urlSession = session
    if let modeString = processInfo.environment[Decoy.Constants.mode],
       let modeEnum = Decoy.Mode(rawValue: modeString) {
      self.mode = modeEnum
    } else {
      self.mode = .liveIfUnmocked
    }
  }

  /// Creates a Decoy-wrapped data task for a `URLRequest`.
  ///
  /// - Parameters:
  ///   - request: The `URLRequest` to be executed.
  ///   - completionHandler: A closure that handles the response, including data, URL response, and any error.
  /// - Returns: A `URLSessionDataTask` that can be resumed to start the request.
  ///
  /// This method:
  /// 1. Calls the original `urlSession.dataTask(with:completionHandler:)` to create a standard data task.
  /// 2. If Decoy is recording responses, it captures the request's response and stores it.
  /// 3. Wraps the standard `URLSessionDataTask` in a `DataTask` to enable Decoy's mocking capabilities.
  override public func dataTask(
    with request: URLRequest,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask {
    let superTask = urlSession.dataTask(with: request, completionHandler: { [weak self] data, response, error in
      guard let self = self else { return }
      if self.recorder.shouldRecord, let url = request.url {
        self.recorder.record(url: url, data: data, response: response, error: error)
      }
      completionHandler(data, response, error)
    })

    return DataTask(mocking: superTask, mode: mode, completionHandler: completionHandler)
  }

  /// Creates a Decoy-wrapped data task for a `URL`.
  ///
  /// - Parameters:
  ///   - url: The `URL` to be requested.
  ///   - completionHandler: A closure that handles the response, including data, URL response, and any error.
  /// - Returns: A `URLSessionDataTask` that can be resumed to start the request.
  ///
  /// This method:
  /// 1. Calls the original `urlSession.dataTask(with:completionHandler:)` to create a standard data task.
  /// 2. If Decoy is recording responses, it captures the request's response and stores it.
  /// 3. Wraps the standard `URLSessionDataTask` in a `DataTask` to enable Decoy's mocking capabilities.
  override public func dataTask(
    with url: URL,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask {
    let superTask = urlSession.dataTask(with: url, completionHandler: { [weak self] data, response, error in
      guard let self = self else { return }
      if self.recorder.shouldRecord {
        self.recorder.record(url: url, data: data, response: response, error: error)
      }
      completionHandler(data, response, error)
    })

    return DataTask(mocking: superTask, mode: mode, completionHandler: completionHandler)
  }
}
