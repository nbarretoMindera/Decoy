import XCTest
@testable import Decoy

class IntegrationTests: XCTestCase {
  var fileURL: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("mock.json")
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: fileURL)
    try super.tearDownWithError()
  }

  func test_URLProtocolInterceptsURLRequestIntegration() {
    setenv(Decoy.Constants.mode, "record", 1)
    setenv(Decoy.Constants.mockDirectory, FileManager.default.temporaryDirectory.absoluteString, 1)
    setenv(Decoy.Constants.mockFilename, "mock.json", 1)

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



private extension IntegrationTests {
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
}

class MockURLProtocol: URLProtocol {
  static var dataToReturn: Data?
  var httpURLResponseToReturn: HTTPURLResponse?

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    if let dataToReturn = Self.dataToReturn {
      client?.urlProtocol(self, didLoad: dataToReturn)
      client?.urlProtocolDidFinishLoading(self)
    }
  }

  override func stopLoading() {}
}

private extension IntegrationTests {
  /// Polls the given file URL until the Loader returns at least one stub, or the timeout expires.
  func waitForMocksToBeWritten(at url: URL, timeout: TimeInterval = 5) {
    let startTime = Date()
    while Date().timeIntervalSince(startTime) < timeout {
      if let stubs = Loader().loadJSON(from: url), !stubs.isEmpty {
        return
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    XCTFail("Timed out waiting for mocks to be written to disk")
  }
}
