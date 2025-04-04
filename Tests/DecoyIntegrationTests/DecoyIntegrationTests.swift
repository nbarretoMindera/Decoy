import XCTest
@testable import Decoy

class DecoyIntegrationTests: XCTestCase {
  var fileURL: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("mock.json")

    let processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = true
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mode: "record",
      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.absoluteString,
      Decoy.Constants.mockFilename: "mock.json"
    ]

    Decoy.queue.clear()
    Decoy.setUp(processInfo: processInfo)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: fileURL)
    super.tearDown()
  }

  func test_URLProtocolInterceptsURLRequestIntegration() {
    MockURLProtocol.dataToReturn = exampleBody
    DecoyURLProtocol.liveSessionProvider = {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [MockURLProtocol.self]
      return URLSession(configuration: config)
    }

    let expectation = self.expectation(description: "Request intercepted and recorded")
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [DecoyURLProtocol.self]

    let session = URLSession(configuration: configuration)
    let testURL = URL(string: "https://example.com/api/test")!
    let request = URLRequest(url: testURL)
    session.dataTask(with: request) { _, _, _ in expectation.fulfill() }.resume()

    waitForExpectations(timeout: 1, handler: nil)
    waitForMocksToBeWritten(at: fileURL)

    guard let stubs = Loader().loadJSON(from: fileURL) else {
      return XCTFail("Failed to load stubs from disk")
    }

    let stub = stubs.first { stub in
      if case .url(let recordedURL) = stub.identifier, recordedURL.absoluteString == testURL.absoluteString {
        return true
      } else {
        return false
      }
    }

    guard let stub else {
      return XCTFail("Expected a recorded stub for \(testURL) to exist.")
    }

    if case .url(let recordedURL) = stub.identifier {
      XCTAssertEqual(recordedURL.absoluteString, testURL.absoluteString)
    } else {
      return XCTFail("Expected a recorded stub for \(testURL) to exist.")
    }

    let mock = (stub.asJSON)["mock"] as? [String: Any]
    let json = mock?["json"] as? [String: Any]
    let result = json?["result"] as? [String: Any]

    XCTAssertEqual(result?["a"] as? String, "b")
  }
}

private extension DecoyIntegrationTests {
  var exampleBody: Data {
    """
    {
      "result": {
        "a": "b"
      }
    }
    """
      .data(using: .utf8)!
  }

  /// Polls the given file URL until the Loader returns at least one stub, or the timeout expires.
  func waitForMocksToBeWritten(at url: URL, timeout: TimeInterval = 5) {
    let startTime = Date()
    let loader = Loader()
    while Date().timeIntervalSince(startTime) < timeout {
      if let stubs = loader.loadJSON(from: url), !stubs.isEmpty {
        return
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    XCTFail("Timed out waiting for mocks to be written to disk")
  }
}
