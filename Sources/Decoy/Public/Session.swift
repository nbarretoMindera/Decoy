import Foundation

public protocol SessionInterface {
  init(mocking: URLSession)
  var urlSession: URLSession { get }
  func dataTask(
    with request: URLRequest,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask
  func dataTask(
    with url: URL,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask
}

/// A subclass of `URLSession` which injects Decoy's subclassed `URLSessionDataTask` objects.
public class Session: URLSession, SessionInterface, @unchecked Sendable {
  /// The underlying `URLSession` being wrapped.
  public let urlSession: URLSession

  /// The mode for this session, determined from ProcessInfo.
  public let mode: Decoy.Mode

  /// Used to record responses from calls made to this session.
  var recorder: RecorderInterface = Decoy.recorder

  /// Initialise a `Session` which wraps another `URLSession` and can mock its data tasks.
  /// Reads the "DECOY_MODE" environment variable to determine the mode, defaulting to `.liveIfUnmocked` if not set.
  required public init(mocking session: URLSession = .shared) {
    self.urlSession = session
    if let modeString = ProcessInfo.processInfo.environment[Decoy.Constants.mode],
       let modeEnum = Decoy.Mode(rawValue: modeString) {
      self.mode = modeEnum
    } else {
      self.mode = .liveIfUnmocked
    }
  }

  /// Create a Decoy data task for a URLRequest.
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

  /// Create a Decoy data task for a URL.
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
