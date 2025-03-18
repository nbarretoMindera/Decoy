import Foundation

/// A subclass of `URLSessionDataTask` that intercepts network requests and checks for mocked responses.
///
/// This class is responsible for:
/// - Checking if a mocked response exists for the requested URL.
/// - Returning the mocked response if available.
/// - Resuming the original network request if no mock exists.
/// - Handling different Decoy modes, such as `record`, `forceOffline`, and `liveIfUnmocked`.
///
/// If the request is running outside of the UI testing environment, it defaults to standard `URLSessionDataTask` behavior.
class DataTask: URLSessionDataTask, @unchecked Sendable {

  /// A type alias for the completion handler used in network responses.
  ///
  /// This closure takes in a tuple containing:
  /// - `Data?`: The response data, if available.
  /// - `URLResponse?`: The URL response metadata.
  /// - `Error?`: Any error encountered during the request.
  typealias CompletionHandler = ((Data?, URLResponse?, Error?)) -> Void

  /// The original `URLSessionDataTask` being wrapped.
  ///
  /// This task is used when no mocked response is found, allowing the request to proceed normally.
  let task: URLSessionDataTask

  /// The mode defining how the `DataTask` should behave.
  ///
  /// This determines whether the request should:
  /// - Record responses (`.record` mode).
  /// - Use only mocked responses (`.forceOffline` mode).
  /// - Use mocked responses if available, otherwise proceed with live requests (`.liveIfUnmocked` mode).
  let mode: Decoy.Mode

  /// The completion handler that will be called with the response data.
  ///
  /// This closure is responsible for delivering either mocked or real responses to the caller.
  let completionHandler: CompletionHandler

  /// Initializes a `DataTask` instance that wraps another `URLSessionDataTask` and can mock its behavior.
  ///
  /// - Parameters:
  ///   - task: The underlying `URLSessionDataTask` being wrapped.
  ///   - mode: The `Decoy.Mode` defining how the task should behave.
  ///   - completionHandler: The closure to be called with either mocked or real data.
  ///
  /// This initializer stores the original `task`, assigns the mode, and sets up the completion handler.
  init(mocking task: URLSessionDataTask, mode: Decoy.Mode, completionHandler: @escaping CompletionHandler) {
    self.task = task
    self.mode = mode
    self.completionHandler = completionHandler
  }

  /// Resumes the network task.
  ///
  /// This method overrides `URLSessionDataTask.resume()` to allow for mocked responses when appropriate.
  ///
  /// - If the task is running in a UI test environment, it calls `resume(processInfo:)`.
  /// - Otherwise, it proceeds with normal network request execution.
  override func resume() {
    self.resume(processInfo: .processInfo)
  }

  /// Begins executing the task, checking for mocked responses before making a real network request.
  ///
  /// - Parameter processInfo: The `ProcessInfo` instance used to determine if the request is running in a UI test.
  ///
  /// This method:
  /// 1. Checks if the request is running in an `XCUI` test environment.
  /// 2. Retrieves the request URL to determine if a mocked response is available.
  /// 3. Depending on the mode, it either:
  ///    - **Records** the request and proceeds with the real network call.
  ///    - **Returns a mocked response** if available in `forceOffline` mode.
  ///    - **Uses a mock or falls back to a real request** in `liveIfUnmocked` mode.
  func resume(processInfo: ProcessInfo = .processInfo) {
    guard let url = task.currentRequest?.url, Decoy.isXCUI(processInfo: processInfo) else {
      // Not running in the UI test environment or no valid URL, so proceed with the real network call.
      return task.resume()
    }

    switch mode {
    case .record:
      // Always resume the task to record the real network response.
      task.resume()

    case .forceOffline:
      // In forceOffline mode, a mocked response must exist.
      if !Decoy.dispatchNextQueuedResponse(for: url, to: completionHandler) {
        let error = NSError(
          domain: "DecoyErrorDomain",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "No mocked response for URL \(url) in forceOffline mode"]
        )
        completionHandler((nil, nil, error))
      }

    case .liveIfUnmocked:
      // Use a mocked response if available; otherwise, proceed with the real network call.
      if !Decoy.dispatchNextQueuedResponse(for: url, to: completionHandler) {
        task.resume()
      }
    }
  }
}
