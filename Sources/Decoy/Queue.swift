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
  var queuedResponses: [Stub.Identifier: [Stub.Response]] { get set }

  /// Enqueues a mocked response for a specific URL.
  ///
  /// - Parameter Stub: A `Stub` instance containing both the URL and its associated response.
  ///   The response is added to the queue for that URL.
  func queue(stub: Stub)

  /// Synchronously retrieves and removes the next queued response for a given URL.
  ///
  /// - Parameter url: The URL for which to retrieve the next mocked response.
  /// - Returns: An optional `Stub.Response` if one exists in the queue; otherwise, `nil`.
  func nextQueuedResponse(for identifier: Stub.Identifier) -> Stub.Response?

  /// Removes all queued mocked responses and resets the internal store.
  ///
  /// Use this method to remove all stubbed responses that have been enqueued, returning the queue to an empty state.
  ///
  /// Conforming implementations should use this to ensure a clean test state between test runs or scenarios, preventing cross-test contamination and ensuring deterministic behavior.
  func clear()
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
  public var queuedResponses = [Stub.Identifier: [Stub.Response]]()

  private let isXCUI: Bool

  private let logger: LoggerInterface

  init(isXCUI: Bool, logger: LoggerInterface) {
    self.isXCUI = isXCUI
    self.logger = logger
  }

  /// Enqueues a mocked response for a specific URL.
  ///
  /// - Parameter Stub: A `Stub` instance that contains the URL and the associated response.
  ///   If no responses exist for that URL, an array is created, and then the response is inserted
  ///   at the beginning of the array to maintain a LIFO order.
  public func queue(stub: Stub) {
    if queuedResponses[stub.identifier] == nil {
      queuedResponses[stub.identifier] = []
    }
    // Insert the new response at the beginning to maintain LIFO order.
    queuedResponses[stub.identifier]?.insert(stub.response, at: 0)
  }

  /// Synchronously retrieves and removes the next queued response for a given URL.
  ///
  /// - Parameter url: The URL for which to retrieve the next mocked response.
  /// - Returns: The next `Stub.Response` if available; otherwise, `nil`.
  ///
  /// This method removes and returns the last element of the array for the specified URL,
  /// which corresponds to the most recently added response.
  public func nextQueuedResponse(for identifier: Stub.Identifier) -> Stub.Response? {
    guard isXCUI else { return nil }

    if case .url(let url) = identifier {
        if url.absoluteString.contains("basket") {
            print("🔍 nextQueuedResponse: \(url)")
            queuedResponses.keys.forEach {
                switch $0 {
                case .url(let url):
                    if url.absoluteString.contains("basket") {
                        print("🔍 nextQueuedResponse in queue: \(url)")
                    }
                default:
                    break
                }
                
            }
        }
      if let stub = queuedResponses[.url(url)]?.popLast() {
        logger.info("Providing decoy for url: \(url)")
        return stub
      } else {
        logger.warning("No decoy was queued for url: \(url)")
        return nil
      }
    } else if case .signature(let graphQLSignature) = identifier {
      if let stub = queuedResponses[.signature(graphQLSignature)]?.popLast() {
        logger.info("Providing decoy for graphQLSignature: \(graphQLSignature)")
        return stub
      } else {
        logger.warning("No decoy was queued for graphQLSignature: \(graphQLSignature)")
        return nil
      }
    } else {
      return nil
    }
  }

  /**
   Removes all queued stub responses, effectively resetting the internal response store.
   
   This method clears all stored mocked responses for every URL or signature, returning the queue to an empty state.
   
   Typically, you use this method during test teardown or when you need to reset the `Decoy` queue between test scenarios to ensure isolation and prevent cross-test contamination.
   */
  public func clear() {
    queuedResponses.removeAll()
  }
}
