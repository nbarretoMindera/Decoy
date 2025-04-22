@testable import Decoy
import Foundation

public class MockRecorder: RecorderInterface {
  public var recordings = [[String: Any]]()
  public var recordCallCount = 0
  public var mockedShouldRecord: Bool = false
  public var shouldRecord: Bool { mockedShouldRecord }

  public init() {}

  public func record(identifier: Stub.Identifier, data: Data?, response: HTTPURLResponse?, error: Error?) {
    recordCallCount += 1
    recordings.insert(["url": identifier.stringValue], at: 0)
  }

  public func flush(completion: @escaping () -> Void) { completion() }
}
