@testable import Decoy
import Foundation

public class FailingLoader: LoaderInterface {
  public init() {}

  public func loadJSON(from url: URL) -> [Stub]? {
    nil
  }
}
