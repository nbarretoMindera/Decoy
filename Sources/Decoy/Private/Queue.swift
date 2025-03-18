import Foundation

/// A protocol defining a queue system for managing mocked responses.
protocol QueueInterface {
  /// A dictionary storing queued responses for specific URLs.
  var queuedResponses: [URL: [Stub.Response]] { get set }

  /// Adds a mocked response to the queue for a specific URL.
  func queue(Stub: Stub)

  /// Synchronously returns and removes the next queued response for a given URL.
  func nextQueuedResponse(for url: URL) -> Stub.Response?
}

/// A class responsible for managing a queue of mocked responses.
class Queue: QueueInterface {
  var queuedResponses = [URL: [Stub.Response]]()

  func queue(Stub: Stub) {
    if queuedResponses[Stub.url] == nil {
      queuedResponses[Stub.url] = []
    }
    // Insert the new response at the beginning of the array.
    queuedResponses[Stub.url]?.insert(Stub.response, at: 0)
  }

  func nextQueuedResponse(for url: URL) -> Stub.Response? {
    queuedResponses[url]?.popLast()
  }
}
