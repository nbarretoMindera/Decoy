import Foundation

/// A subclass of `URLSessionDataTask` which checks for mocked responses. If mocks are found, they will be
/// passed to the completion handler. If mocks are not found, the superclass will handle the function as standard.
class DataTask: URLSessionDataTask {
  /// Internal extensions used for cleaner-to-read code.
  typealias CompletionHandler = ((Data?, URLResponse?, Error?)) -> Void

  /// The underlying `URLSessionDataTask` being mocked.
  let task: URLSessionDataTask

  /// The closure which will be called, with either mocked or real data.
  let completionHandler: CompletionHandler

  /// Initialise a `DataTask` which wraps another `URLSessionDataTask` and can mock it.
  ///
  /// - Parameters:
  ///   - task: The underlying `URLSessionDataTask` being mocked.
  ///   - completionHandler: The closure which will be called, with either mocked or real data.
  ///
  /// - Returns: An instance of `DataTask` which will mock calls if mocked data exists.
  init(mocking task: URLSessionDataTask, completionHandler: @escaping CompletionHandler) {
    self.task = task
    self.completionHandler = completionHandler
  }

  /// Override from `URLSessionDataTask` to allow tasks to be resumed when there is no need to
  /// inject `ProcessInfo`, i.e. when not running Decoy' own unit tests.
  override func resume() {
    self.resume(processInfo: .processInfo)
  }

  /// Begin executing the task. If a mocked response for this task is provided within Decoy's
  /// queued responses, it will be passed to the `completionHandler`. If such a response is
  /// not provided, the superclass will handle the function. We also need to be running UI tests to
  /// proceed with the custom implementation, so we don't interfere with the real app.
  func resume(processInfo: ProcessInfo = .processInfo) {
    guard let url = task.currentRequest?.url, Decoy.shared.isXCUI(processInfo: processInfo) else {
      return task.resume()
    }

    /// Ask Decoy to mock the call. If it has a queued response, it will call the completion
    /// handler. If not, tell the task to resume using the superclass's implementation of `resume`,
    /// which may hit the real network, etc.
    if !Decoy.shared.dispatchNextQueuedResponse(for: url, to: completionHandler) {
      task.resume()
    }
  }
}
