import Foundation
import XCTest
@testable import Decoy

final class RecorderTests: XCTestCase {
  func test_shouldRecord_shouldReadFromProcessInfo_whenRecording() {
    let info = MockProcessInfo()
    info.mockedEnvironment = [Decoy.Constants.mode: Decoy.Mode.record.rawValue]
    XCTAssertTrue(Recorder(processInfo: info, writer: Writer(processInfo: info, logger: Logger()), logger: Logger()).shouldRecord)
  }

  func test_shouldRecord_shouldReadFromProcessInfo_whenLiveIfOffline() {
    let info = MockProcessInfo()
    info.mockedEnvironment = [Decoy.Constants.mode: Decoy.Mode.liveIfUnmocked.rawValue]
    XCTAssertFalse(Recorder(processInfo: info, writer: Writer(processInfo: info, logger: Logger()), logger: Logger()).shouldRecord)
  }

  func test_shouldRecord_shouldReadFromProcessInfo_whenForceOffline() {
    let info = MockProcessInfo()
    info.mockedEnvironment = [Decoy.Constants.mode: Decoy.Mode.forceOffline.rawValue]
    XCTAssertFalse(Recorder(processInfo: info, writer: Writer(processInfo: info, logger: Logger()), logger: Logger()).shouldRecord)
  }

  func test_shouldRecord_shouldDefaultToFalse_whenEnvironmentVariableIsNotSet() {
    let info = MockProcessInfo()
    info.mockedEnvironment = [:]
    XCTAssertFalse(Recorder(processInfo: info, writer: Writer(processInfo: info, logger: Logger()), logger: Logger()).shouldRecord)
  }

  func test_record_shouldCallWriterAppendOnce() {
    let mockWriter = MockWriter()
    let recorder = Recorder(processInfo: ProcessInfo(), writer: mockWriter, logger: Logger())
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

  func test_record_shouldCallWriterAppendMultipleTimes() throws {
    let mockWriter = MockWriter()
    let recorder = Recorder(processInfo: ProcessInfo(), writer: mockWriter, logger: Logger())
    let testURL = URL(string: "A")!

    let expectation = XCTestExpectation(description: "Multiple records complete")

    recorder.record(identifier: .url(testURL), data: nil, response: nil, error: nil)
    recorder.record(identifier: .signature(testSignature), data: nil, response: nil, error: nil)
    recorder.record(identifier: .url(testURL), data: nil, response: nil, error: nil)
    recorder.record(identifier: .signature(testSignature), data: nil, response: nil, error: nil)
    recorder.record(identifier: .url(testURL), data: nil, response: nil, error: nil)
    recorder.record(identifier: .signature(testSignature), data: nil, response: nil, error: nil)

    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
      XCTAssertEqual(mockWriter.appendedRecordings.count, 6)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1)
  }

  func test_record_shouldRecordValidStub_forURLType() {
    let mockWriter = MockWriter()
    let recorder = Recorder(processInfo: ProcessInfo(), writer: mockWriter, logger: Logger())
    let url = URL(string: "A")!
    let jsonObject: [String: String] = ["A": "B"]
    let data = try? JSONSerialization.data(withJSONObject: jsonObject)
    let response = HTTPURLResponse(url: url, statusCode: 123, httpVersion: nil, headerFields: nil)

    recorder.record(identifier: .url(url), data: data, response: response, error: TestError.generic)

    let expectation = XCTestExpectation(description: "Record valid stub")

    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
      guard let recording = mockWriter.appendedRecordings.first else { return XCTFail("No recording was appended") }
      XCTAssertEqual(recording["identifier"] as? String, url.absoluteString)

      guard let mock = recording["mock"] as? [String: Any] else { return XCTFail("No mock dictionary found") }

      if let json = mock["json"] as? [String: String] {
        XCTAssertEqual(json, jsonObject)
      } else {
        XCTFail("Recorded JSON is not valid")
      }

      XCTAssertEqual(mock["statusCode"] as? Int, 123)

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1)
  }

  func test_record_shouldRecordValidStub_forSignatureType() {
    let mockWriter = MockWriter()
    let recorder = Recorder(processInfo: ProcessInfo(), writer: mockWriter, logger: Logger())
    let jsonObject: [String: String] = ["A": "B"]
    let data = try? JSONSerialization.data(withJSONObject: jsonObject)
    let response = HTTPURLResponse(url: testSignature.endpoint, statusCode: 123, httpVersion: nil, headerFields: nil)
    recorder.record(identifier: .signature(testSignature), data: data, response: response, error: TestError.generic)

    let expectation = XCTestExpectation(description: "Record valid stub")

    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
      guard let recording = mockWriter.appendedRecordings.first else { return XCTFail("No recording was appended") }
      XCTAssertEqual(recording["identifier"] as? String, "bar_")

      guard let mock = recording["mock"] as? [String: Any] else { return XCTFail("No mock dictionary found") }

      if let json = mock["json"] as? [String: String] {
        XCTAssertEqual(json, jsonObject)
      } else {
        XCTFail("Recorded JSON is not valid")
      }

      XCTAssertEqual(mock["statusCode"] as? Int, 123)

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1)
  }

  func test_record_shouldAskWriterToWriteURLs() {
    let mockWriter = MockWriter()
    let recorder = Recorder(processInfo: ProcessInfo(), writer: mockWriter, logger: Logger())
    let testURL = URL(string: "A")!

    let expectation = XCTestExpectation(description: "Record calls writer")

    recorder.record(identifier: .url(testURL), data: nil, response: nil, error: nil)

    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
      XCTAssertTrue(mockWriter.appendWasCalled)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func test_record_shouldAskWriterToWriteSignatures() {
    let mockWriter = MockWriter()
    let recorder = Recorder(processInfo: ProcessInfo(), writer: mockWriter, logger: Logger())

    let expectation = XCTestExpectation(description: "Record calls writer")

    recorder.record(identifier: .signature(testSignature), data: nil, response: nil, error: nil)

    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
      XCTAssertTrue(mockWriter.appendWasCalled)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }
}
