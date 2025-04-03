import Foundation
import XCTest
@testable import Decoy

final class RecorderTests: XCTestCase {

  // MARK: - shouldRecord Property Tests

  func test_shouldRecord_shouldReadFromProcessInfo_whenRecording() {
    let info = MockProcessInfo()
    info.mockedEnvironment = [Decoy.Constants.mode: Decoy.Mode.record.rawValue]
    XCTAssertTrue(Recorder(processInfo: info).shouldRecord)
  }

  func test_shouldRecord_shouldReadFromProcessInfo_whenLiveIfOffline() {
    let info = MockProcessInfo()
    info.mockedEnvironment = [Decoy.Constants.mode: Decoy.Mode.liveIfUnmocked.rawValue]
    XCTAssertFalse(Recorder(processInfo: info).shouldRecord)
  }

  func test_shouldRecord_shouldReadFromProcessInfo_whenForceOffline() {
    let info = MockProcessInfo()
    info.mockedEnvironment = [Decoy.Constants.mode: Decoy.Mode.forceOffline.rawValue]
    XCTAssertFalse(Recorder(processInfo: info).shouldRecord)
  }

  func test_shouldRecord_shouldDefaultToFalse_whenEnvironmentVariableIsNotSet() {
    let info = MockProcessInfo()
    info.mockedEnvironment = [:]
    XCTAssertFalse(Recorder(processInfo: info).shouldRecord)
  }

  // MARK: - Recording Behavior Tests

  /// Tests that calling record() once results in one call to the writer's append method.
  func test_record_shouldCallWriterAppendOnce() {
    let mockWriter = MockWriter()
    let recorder = Recorder(writer: mockWriter)
    let testURL = URL(string: "A")!

    let expectation = XCTestExpectation(description: "Record completes")

    recorder.record(identifier: .url(testURL), data: nil, response: nil, error: nil)

    // Wait briefly for the asynchronous call to complete.
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
      XCTAssertEqual(mockWriter.appendedRecordings.count, 1)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  /// Tests that multiple calls to record() result in multiple append calls to the writer.
  func test_record_shouldCallWriterAppendMultipleTimes() {
    let mockWriter = MockWriter()
    let recorder = Recorder(writer: mockWriter)
    let testURL = URL(string: "A")!

    let expectation = XCTestExpectation(description: "Multiple records complete")

    recorder.record(identifier: .url(testURL), data: nil, response: nil, error: nil)
    recorder.record(identifier: .url(testURL), data: nil, response: nil, error: nil)
    recorder.record(identifier: .url(testURL), data: nil, response: nil, error: nil)

    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
      XCTAssertEqual(mockWriter.appendedRecordings.count, 3)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  /// Tests that record() produces a valid stub dictionary.
  func test_record_shouldRecordValidStub() {
    let mockWriter = MockWriter()
    let recorder = Recorder(writer: mockWriter)
    let url = URL(string: "A")!
    let jsonObject: [String: String] = ["A": "B"]
    let data = try? JSONSerialization.data(withJSONObject: jsonObject)
    let response = HTTPURLResponse(url: url, statusCode: 123, httpVersion: nil, headerFields: nil)

    recorder.record(identifier: .url(url), data: data, response: response, error: TestError.generic)

    let expectation = XCTestExpectation(description: "Record valid stub")

    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
      guard let recording = mockWriter.appendedRecordings.first else {
        return XCTFail("No recording was appended")
      }

      // Verify the URL is correctly recorded.
      XCTAssertEqual(recording["identifier"] as? String, url.absoluteString)

      // Verify the mock details.
      guard let mock = recording["mock"] as? [String: Any] else {
        return XCTFail("No mock dictionary found")
      }

      // The recorded JSON should match our input.
      if let json = mock["json"] as? [String: String] {
        XCTAssertEqual(json, jsonObject)
      } else {
        XCTFail("Recorded JSON is not valid")
      }

      // Verify the response code is recorded.
      XCTAssertEqual(mock["responseCode"] as? Int, 123)

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  /// Tests that record() calls the writer's append method (i.e. the writer is asked to write).
  func test_record_shouldAskWriterToWrite() {
    let mockWriter = MockWriter()
    let recorder = Recorder(writer: mockWriter)
    let testURL = URL(string: "A")!

    let expectation = XCTestExpectation(description: "Record calls writer")

    recorder.record(identifier: .url(testURL), data: nil, response: nil, error: nil)

    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
      XCTAssertTrue(mockWriter.appendWasCalled)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }
}
