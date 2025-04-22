@testable import Decoy
import Foundation

public class MockWriter: WriterInterface {
  public var appendedRecordings: [[String: Any]] = []
  public var appendWasCalled = false

  public init() {}

  public func append(recording: [String : Any]) throws {
    appendWasCalled = true
    appendedRecordings.append(recording)
  }

  public func flush(completion: @escaping () -> Void) { completion() }
}
