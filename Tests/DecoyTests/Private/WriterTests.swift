import Foundation
import XCTest
@testable import Decoy

final class WriterTests: XCTestCase {
  func test_append_shouldThrowFilePathNotFound_whenPathIsMissing() {
    let processInfo = MockProcessInfo()
    // Only filename is provided; directory is missing.
    processInfo.mockedEnvironment = [
      Decoy.Constants.mockFilename: "A"
    ]

    XCTAssertThrowsError(try Writer(processInfo: processInfo).append(recording: [:])) { error in
      XCTAssertEqual(error as? WriterError, .filePathNotFound)
    }
  }

  func test_append_shouldThrowFilePathNotFound_whenFileIsMissing() {
    let processInfo = MockProcessInfo()
    // Only directory is provided; filename is missing.
    processInfo.mockedEnvironment = [
      Decoy.Constants.mockDirectory: "A"
    ]

    XCTAssertThrowsError(try Writer(processInfo: processInfo).append(recording: [:])) { error in
      XCTAssertEqual(error as? WriterError, .filePathNotFound)
    }
  }

  func test_append_shouldThrowFilePathNotFound_whenBothPathAndFileAreMissing() {
    let processInfo = MockProcessInfo()
    // Neither directory nor filename is provided.
    processInfo.mockedEnvironment = [:]

    XCTAssertThrowsError(try Writer(processInfo: processInfo).append(recording: [:])) { error in
      XCTAssertEqual(error as? WriterError, .filePathNotFound)
    }
  }

  func test_append_shouldAskFileManagerToCreateDirectory() {
    let fileManager = MockFileManager()

    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      Decoy.Constants.mockDirectory: "A",
      Decoy.Constants.mockFilename: "B"
    ]

    // Calling append(recording:) should trigger the creation of the directory.
    try? Writer(processInfo: processInfo, fileManager: fileManager).append(recording: [:])

    XCTAssertTrue(fileManager.didCallCreateDirectory)
  }
}
