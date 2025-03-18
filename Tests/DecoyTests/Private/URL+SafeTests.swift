@testable import Decoy
import Foundation
import XCTest

final class URLSafeTests: XCTestCase {
  func test_safePath_initialization_usesFilePath_onNewerVersions() {
    let url = URL(safePath: "/test/path", useNewAPI: true)
    XCTAssertEqual(url.path, "/test/path")
  }

  func test_safePath_initialization_usesFileURLWithPath_onOlderVersions() {
    let url = URL(safePath: "/test/path", useNewAPI: false)
    XCTAssertEqual(url.path, "/test/path")
  }

  func test_safeAppend_usesAppendPath_onNewerVersions() {
    var url = URL(safePath: "/test", useNewAPI: true)
    url.safeAppend(path: "appended", useNewAPI: true)
    XCTAssertEqual(url.path, "/test/appended")
  }

  func test_safeAppend_usesAppendPathComponent_onOlderVersions() {
    var url = URL(safePath: "/test", useNewAPI: false)
    url.safeAppend(path: "appended", useNewAPI: false)
    XCTAssertEqual(url.path, "/test/appended")
  }
}
