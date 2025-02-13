import Foundation

public protocol SessionInterface {
  init(mocking: URLSession)

  func dataTask(
    with request: URLRequest,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask

  func dataTask(
    with url: URL,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask
}

/// A subclass of `URLSession` which injects MockMarks's subclassed `URLSessionDataTask` objects.
public class Session: URLSession, SessionInterface {
  /// The underlying `URLSession` being mocked.
  let urlSession: URLSession

  /// Used to record responses from calls made to this session.
  var recorder: RecorderInterface = MockMarks.shared.recorder

  /// Initialise a `Session` which wraps another `URLSession` and can mock its data tasks.
  ///
  /// - Parameters:
  ///   - session: The underlying `URLSession` being mocked.
  ///
  /// - Returns: An instance of `Session` which will mock calls as requested.
  required public init(mocking session: URLSession = .shared) {
    self.urlSession = session
  }

  /// Create a `MockMarksURLSessionDataTask` (as a standard `URLSessionDataTask`)
  /// which can be used to return mocked responses from the response queue.
  ///
  /// - Parameters:
  ///   - request: The request to be mocked.
  ///   - completionHandler: A callback which will be called with eithert mocked or real data.
  ///
  /// - Returns: An instance of `MockMarksURLSessionDataTask` typed as a `URLSessionDataTask`.
  override public func dataTask(
    with request: URLRequest,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask {
    let superTask = urlSession.dataTask(with: request, completionHandler: { [weak self] data, response, error in
      guard let self else { return }
      if self.recorder.shouldRecord, let url = request.url {
        self.recorder.record(url: url, data: data, response: response, error: error)
      }
      completionHandler(data, response, error)
    })

    return DataTask(mocking: superTask, completionHandler: completionHandler)
  }

  /// Create a `MockMarksURLSessionDataTask` (as a standard `URLSessionDataTask`)
  /// which can be used to return mocked responses from the response queue.
  ///
  /// - Parameters:
  ///   - url: The URL from which responses will be mocked.
  ///   - completionHandler: A callback which will be called with eithert mocked or real data.
  ///
  /// - Returns: An instance of `MockMarksURLSessionDataTask` typed as a `URLSessionDataTask`.
  override public func dataTask(
    with url: URL,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask {
    DataTask(
      mocking: urlSession.dataTask(with: url, completionHandler: { [weak self] data, response, error in
        guard let self else { return }
        if self.recorder.shouldRecord {
          self.recorder.record(url: url, data: data, response: response, error: error)
        }
        completionHandler(data, response, error)
      }),
      completionHandler: completionHandler
    )
  }
}
