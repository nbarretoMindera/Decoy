import Foundation
import XCTest
@testable import MockMarks

final class WriterTests: XCTestCase {

  func test_write_shouldThrowFilePathNotFound_whenPathIsMissing() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      MockMarks.Constants.mockFilename: "A"
    ]

    XCTAssertThrowsError(try Writer(processInfo: processInfo).write(recordings: [[:]])) { error in
      XCTAssertEqual(error as? WriterError, .filePathNotFound)
    }
  }

  func test_write_shouldThrowFileNameNotFound_whenFileIsMissing() {
    let processInfo = MockProcessInfo()
    processInfo.mockedEnvironment = [
      MockMarks.Constants.mockDirectory: "A"
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
      MockMarks.Constants.mockDirectory: "A",
      MockMarks.Constants.mockFilename: "B"
    ]

    try? Writer(processInfo: processInfo, fileManager: fileManager).write(recordings: [[:]])

    XCTAssert(fileManager.didCallCreateDirectory)
  }
}

private class MockFileManager: FileManager {

  var didCallCreateDirectory = false

  override func createDirectory(
    at url: URL,
    withIntermediateDirectories createIntermediates: Bool,
    attributes: [FileAttributeKey: Any]? = nil
  ) throws {
    didCallCreateDirectory = true
  }
}
