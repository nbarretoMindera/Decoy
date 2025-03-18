@testable import Decoy
import Foundation

struct FailingLoader: LoaderInterface {
  func loadJSON(from url: URL) -> [Stub]? {
    nil
  }
}
