import Foundation
import XCTest
@testable import Decoy
@testable import DecoyApollo

final class DecoyInterceptorTests: XCTestCase {
  func test_id() {
    XCTAssertEqual(DecoyInterceptor().id, "DecoyInterceptor")
  }
}
