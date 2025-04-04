import XCTest
@testable import Decoy

class URLProtocolIntegrationTests: XCTestCase {
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

  func test_urlProtocol_decoys() {
    // Figure the URL protocols – one to return mocked "live" data to be recorded, one for Decoy itself to serve a mock.
    MockURLProtocol.dataToReturn = exampleBody
    DecoyURLProtocol.liveSessionProvider = {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [MockURLProtocol.self]
      return URLSession(configuration: config)
    }

    // Create our URLConfiguration using DecoyURLProtocol.
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [DecoyURLProtocol.self]

    // Create the URLSession and URLRequest as a real app would.
    let session = URLSession(configuration: configuration)
    let testURL = URL(string: "https://example.com/api/test")!
    let request = URLRequest(url: testURL)
    session.dataTask(with: request) { _, _, _ in }.resume()

    // Since mocks are written on a queue, we need a slight delay in the test to simulate real behaviour.
    WriteWaiter.waitForMocksToBeWritten(at: fileURL)

    // Verify that we can load the stubs which have now been read from the URLSession, recorded, and written to disk.
    guard let stubs = Loader().loadJSON(from: fileURL), let stub = stubs.first else {
      return XCTFail("Failed to load stubs from disk")
    }

    // Verify that the stub we created / recorded / wrote matches the original URL we provided.
    guard case .url(let recordedURL) = stub.identifier, recordedURL.absoluteString == testURL.absoluteString else {
      return XCTFail("Expected a recorded stub for \(testURL) to exist.")
    }

    // Parse the response JSON and verify that it matches what was passed in from exampleBody.
    let mock = (stub.asJSON)["mock"] as? [String: Any]
    let json = mock?["json"] as? [String: Any]
    let result = json?["result"] as? [String: Any]
    XCTAssertEqual(result?["a"] as? String, "b")
  }
}

private extension URLProtocolIntegrationTests {
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
