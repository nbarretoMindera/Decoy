import Foundation

/// A protocol defining a queue system for managing mocked responses.
///
/// Implementations of this protocol allow you to store and later retrieve
/// mocked responses for specific URLs, enabling deterministic testing of network calls.
public protocol QueueInterface {
  /// A dictionary mapping URLs to an array of queued mocked responses.
  ///
  /// Each URL key is associated with an array of `Stub.Response` objects,
  /// which are returned in a last-in, first-out (LIFO) order when requested.
  var queuedResponses: [URL: [Stub.Response]] { get set }

  /// Enqueues a mocked response for a specific URL.
  ///
  /// - Parameter Stub: A `Stub` instance containing both the URL and its associated response.
  ///   The response is added to the queue for that URL.
  func queue(stub: Stub)

  /// Synchronously retrieves and removes the next queued response for a given URL.
  ///
  /// - Parameter url: The URL for which to retrieve the next mocked response.
  /// - Returns: An optional `Stub.Response` if one exists in the queue; otherwise, `nil`.
  func nextQueuedResponse(for url: URL) -> Stub.Response?
}

/// A class responsible for managing a queue of mocked responses.
///
/// This class implements `QueueInterface` and stores mock responses in a dictionary keyed by URL.
/// When a network request is intercepted, the next mocked response (if any) is returned.
public class Queue: QueueInterface {
  /// A dictionary mapping URLs to an array of `Stub.Response` objects.
  ///
  /// Each URL key stores an array of responses, where the most recent response (inserted last)
  /// is returned first when requested.
  public var queuedResponses = [URL: [Stub.Response]]()

  /// Enqueues a mocked response for a specific URL.
  ///
  /// - Parameter Stub: A `Stub` instance that contains the URL and the associated response.
  ///   If no responses exist for that URL, an array is created, and then the response is inserted
  ///   at the beginning of the array to maintain a LIFO order.
  public func queue(stub: Stub) {
    if queuedResponses[stub.url] == nil {
      queuedResponses[stub.url] = []
    }
    // Insert the new response at the beginning to maintain LIFO order.
    queuedResponses[stub.url]?.insert(stub.response, at: 0)
  }

  /// Synchronously retrieves and removes the next queued response for a given URL.
  ///
  /// - Parameter url: The URL for which to retrieve the next mocked response.
  /// - Returns: The next `Stub.Response` if available; otherwise, `nil`.
  ///
  /// This method removes and returns the last element of the array for the specified URL,
  /// which corresponds to the most recently added response.
  public func nextQueuedResponse(for url: URL) -> Stub.Response? {
    if let url = queuedResponses[url]?.popLast() {
      Decoy.logInfo("Providing decoy for \(url)")
      return url
    } else {
      Decoy.logWarning("No decoy was queued for \(url)")
      return nil
    }
  }
}
