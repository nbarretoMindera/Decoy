import Decoy

class MockQueue: QueueInterface {
  var queuedResponses: [Stub.Identifier : [Stub.Response]] = [:]
  func queue(stub: Stub) {}
  func nextQueuedResponse(for identifier: Stub.Identifier) -> Stub.Response? {
    guard !queuedResponses.isEmpty else { return nil }
    return queuedResponses[identifier]?.first
  }
  func clear() {}
}
