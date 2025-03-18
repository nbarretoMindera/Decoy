import Foundation
import XCTest
@testable import Decoy

final class WriterTests: XCTestCase {
  func test_write_shouldThrowFilePathNotFound_whenPathIsMissing() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.mockFilename: "A"
    ]

    XCTAssertThrowsError(try Writer(processInfo: processInfo).write(recordings: [[:]])) { error in
      XCTAssertEqual(error as? WriterError, .filePathNotFound)
    }
  }

  func test_write_shouldThrowFileNameNotFound_whenFileIsMissing() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.mockDirectory: "A"
    ]

    XCTAssertThrowsError(try Writer(processInfo: processInfo).write(recordings: [[:]])) { error in
      XCTAssertEqual(error as? WriterError, .filePathNotFound)
    }
  }

  func test_write_shouldThrowFilePathNotFound_whenBothPathAndFileAreMissing() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [:]

    XCTAssertThrowsError(try Writer(processInfo: processInfo).write(recordings: [[:]])) { error in
      XCTAssertEqual(error as? WriterError, .filePathNotFound)
    }
  }

  func test_write_shouldAskFileManagerToCreateDirectory() {
    let fileManager = MockFileManager()

    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.mockDirectory: "A",
      Decoy.Constants.mockFilename: "B"
    ]

    try? Writer(processInfo: processInfo, fileManager: fileManager).write(recordings: [[:]])

    XCTAssert(fileManager.didCallCreateDirectory)
  }
}
