import Foundation

/// A protocol defining a queue system for managing mocked responses.
///
/// Implementations of this protocol allow network requests to be matched with pre-configured responses,
/// enabling controlled testing scenarios.
protocol QueueInterface {

  /// A dictionary storing queued responses for specific URLs.
  ///
  /// Each key represents a URL, and the value is an array of `Stub.Response` objects that will
  /// be returned sequentially when the URL is requested.
  var queuedResponses: [URL: [Stub.Response]] { get set }

  /// Adds a mocked response to the queue for a specific URL.
  ///
  /// - Parameter Stub: The `Stub` instance containing the URL and associated response data.
  func queue(Stub: Stub)

  /// Dispatches the next queued response for a given URL.
  ///
  /// - Parameters:
  ///   - url: The URL for which a response should be returned.
  ///   - completion: A closure that receives the dispatched response, including data, URL response, and error.
  /// - Returns: `true` if a queued response was dispatched, otherwise `false`.
  func dispatchNextQueuedResponse(for url: URL, to completion: @escaping DataTask.CompletionHandler) -> Bool
}

/// A class responsible for managing a queue of mocked responses for network requests.
///
/// This queue stores `Stub` responses for specific URLs and returns them sequentially when requested.
/// It enables deterministic testing of network behavior by controlling how responses are delivered.
class Queue: QueueInterface {

  /// A dictionary mapping URLs to their queued mocked responses.
  ///
  /// Each URL key has an associated array of `Stub.Response` objects, which are returned in a
  /// first-in-last-out (stack-like) order when requests for that URL are made.
  var queuedResponses = [URL: [Stub.Response]]()

  /// Adds a mocked response to the queue for a specific URL.
  ///
  /// - Parameter Stub: The `Stub` instance containing the URL and its response data.
  ///
  /// This method:
  /// 1. Checks if there are existing responses for the given URL.
  /// 2. If none exist, it initializes an empty array.
  /// 3. Inserts the new response at the **front** of the array, ensuring the most recent mock is returned first.
  func queue(Stub: Stub) {
    if queuedResponses[Stub.url] == nil {
      queuedResponses[Stub.url] = []
    }

    // Insert the new response at the beginning of the queue.
    queuedResponses[Stub.url]?.insert(Stub.response, at: 0)
  }

  /// Dispatches the next queued response for a given URL.
  ///
  /// - Parameters:
  ///   - url: The URL for which a response should be returned.
  ///   - completion: A closure that receives the response, including data, URL response, and error.
  /// - Returns: `true` if a queued response was successfully dispatched, otherwise `false`.
  ///
  /// This method:
  /// 1. Checks if there are any queued responses for the given URL.
  /// 2. If a response exists, it removes the **most recent** response (last added) and passes it to the completion handler.
  /// 3. If no responses exist, it returns `false`.
  func dispatchNextQueuedResponse(for url: URL, to completion: @escaping DataTask.CompletionHandler) -> Bool {
    guard let next = queuedResponses[url]?.popLast() else {
      return false
    }

    // Execute the completion handler with the retrieved response.
    completion((next.data, nil, nil))

    return true
  }
}
