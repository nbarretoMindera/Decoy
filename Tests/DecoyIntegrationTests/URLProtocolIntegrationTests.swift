import XCTest
@testable import Decoy

class URLProtocolIntegrationTests: XCTestCase {
  var fileURL: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()

    fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("url-protocol-mock.json")

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

  func test_decoyUrlProtocol_interceptsUrlRequest_recordsResponse_stubsMatchOriginal() {
    // Configure the URL protocols – one to return mocked "live" data to be recorded, one for Decoy itself to serve a mock.
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

  func test_decoyURLProtocol_recordsMultipleDistinctRequests() {
    // Configure the DecoyURLProtocol to use MockURLProtocol for live responses
    MockURLProtocol.dataToReturn = exampleBody
    DecoyURLProtocol.liveSessionProvider = {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [MockURLProtocol.self]
      return URLSession(configuration: config)
    }

    // Create a session using DecoyURLProtocol
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [DecoyURLProtocol.self]
    let session = URLSession(configuration: configuration)

    // Fire two distinct requests to different URLs
    let base = "https://example.com/api/test"
    let urls = [URL(string: "\(base)?1")!, URL(string: "\(base)?2")!]
    let requests = urls.map { URLRequest(url: $0) }

    let expectation = XCTestExpectation(description: "Both requests complete")
    expectation.expectedFulfillmentCount = requests.count

    for request in requests {
      session.dataTask(with: request) { _, _, _ in
        expectation.fulfill()
      }.resume()
    }

    wait(for: [expectation], timeout: 2.0)

    // Wait for writes to complete
    WriteWaiter.waitForMocksToBeWritten(at: fileURL)

    // Load and verify both stubs were recorded
    guard let stubs = Loader().loadJSON(from: fileURL) else {
      return XCTFail("Failed to load stubs from disk")
    }

    let recordedURLs = stubs.compactMap { stub -> String? in
      if case .url(let url) = stub.identifier {
        return url.absoluteString
      }
      return nil
    }

    for url in urls {
      XCTAssertTrue(recordedURLs.contains(url.absoluteString), "Expected stub for \(url) to be recorded.")
    }
  }

  func test_decoyURLProtocol_preservesStatusCodeAndHeaders() {
    let expectedHeaders = ["Content-Type": "application/json", "X-Custom-Header": "TestValue"]
    let expectedStatusCode = 201

    // Configure the mock response
    MockURLProtocol.dataToReturn = exampleBody
    MockURLProtocol.httpURLResponseToReturn = HTTPURLResponse(
      url: URL(string: "https://example.com/api/test")!,
      statusCode: expectedStatusCode,
      httpVersion: "HTTP/1.1",
      headerFields: expectedHeaders
    )

    DecoyURLProtocol.liveSessionProvider = {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [MockURLProtocol.self]
      return URLSession(configuration: config)
    }

    // Session using DecoyURLProtocol
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [DecoyURLProtocol.self]
    let session = URLSession(configuration: config)

    // Perform request
    let testURL = URL(string: "https://example.com/api/test")!
    let expectation = XCTestExpectation(description: "Request completes")
    session.dataTask(with: URLRequest(url: testURL)) { _, _, _ in
      expectation.fulfill()
    }.resume()

    wait(for: [expectation], timeout: 2)
    WriteWaiter.waitForMocksToBeWritten(at: fileURL)

    // Load stub from disk
    guard let stubs = Loader().loadJSON(from: fileURL), let stub = stubs.first, let urlResponse = stub.response.urlResponse else {
      return XCTFail("Failed to load stub with response")
    }

    // Assert status code and headers
    XCTAssertEqual(urlResponse.statusCode, expectedStatusCode)
    XCTAssertEqual(urlResponse.allHeaderFields["X-Custom-Header"] as? String, "TestValue")
    XCTAssertEqual(urlResponse.allHeaderFields["Content-Type"] as? String, "application/json")
  }

  func test_decoyURLProtocol_returnsErrorInForceOfflineModeWhenNoStubAvailable() {
    // Set Decoy to forceOffline mode
    let processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = true
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mode: "forceOffline",
      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.absoluteString,
      Decoy.Constants.mockFilename: "mock.json"
    ]

    Decoy.queue.clear()
    Decoy.setUp(processInfo: processInfo)

    // Create a session using DecoyURLProtocol
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [DecoyURLProtocol.self]
    let session = URLSession(configuration: config)

    // Perform request
    let testURL = URL(string: "https://example.com/api/offline-test")!
    let expectation = XCTestExpectation(description: "Request completes")

    session.dataTask(with: URLRequest(url: testURL)) { _, response, error in
      XCTAssertNil(response)
      XCTAssertNotNil(error)

      let nsError = error as NSError?
      XCTAssertEqual(nsError?.domain, "DecoyErrorDomain")
      XCTAssertEqual(nsError?.code, -1)
      XCTAssertTrue(nsError?.localizedDescription.contains("No mock available") ?? false)

      expectation.fulfill()
    }.resume()

    wait(for: [expectation], timeout: 2)
  }

  func test_decoyURLProtocol_usesStubInLiveIfUnmockedMode() {
    let processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = true
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mode: "liveIfUnmocked",
      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.absoluteString,
      Decoy.Constants.mockFilename: "mock.json"
    ]

    let stubbedURL = URL(string: "https://example.com/api/stubbed")!
    let stub = Stub(
      identifier: .url(stubbedURL),
      response: Stub.Response(
        data: """
        { "result": { "a": "stub" } }
        """.data(using: .utf8),
        urlResponse: HTTPURLResponse(url: stubbedURL, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]),
        error: nil
      )
    )

    Decoy.queue.clear()
    Decoy.setUp(processInfo: processInfo)
    Decoy.queue.queue(stub: stub)

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [DecoyURLProtocol.self]
    let session = URLSession(configuration: config)

    let expectation = XCTestExpectation(description: "Stubbed request completes")

    session.dataTask(with: URLRequest(url: stubbedURL)) { data, _, _ in
      guard
        let data = data,
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let result = json["result"] as? [String: Any],
        let value = result["a"] as? String
      else {
        return XCTFail("Failed to decode stubbed response")
      }

      XCTAssertEqual(value, "stub")
      expectation.fulfill()
    }.resume()

    wait(for: [expectation], timeout: 2)
  }

  func test_decoyURLProtocol_fallsBackToLiveInLiveIfUnmockedMode() {
    let processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = true
    processInfo.mockedEnvironment = [
      Decoy.Constants.isXCUI: "true",
      Decoy.Constants.mode: "liveIfUnmocked",
      Decoy.Constants.mockDirectory: FileManager.default.temporaryDirectory.absoluteString,
      Decoy.Constants.mockFilename: "mock.json"
    ]

    let liveURL = URL(string: "https://example.com/api/live")!

    MockURLProtocol.dataToReturn = """
    { "result": { "a": "live" } }
    """.data(using: .utf8)
    MockURLProtocol.httpURLResponseToReturn = HTTPURLResponse(
      url: liveURL,
      statusCode: 200,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"]
    )

    Decoy.queue.clear()
    Decoy.setUp(processInfo: processInfo)
    DecoyURLProtocol.liveSessionProvider = {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [MockURLProtocol.self]
      return URLSession(configuration: config)
    }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [DecoyURLProtocol.self]
    let session = URLSession(configuration: config)

    let expectation = XCTestExpectation(description: "Live fallback request completes")

    session.dataTask(with: URLRequest(url: liveURL)) { data, _, _ in
      guard
        let data = data,
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let result = json["result"] as? [String: Any],
        let value = result["a"] as? String
      else {
        return XCTFail("Failed to decode live response")
      }

      XCTAssertEqual(value, "live")
      expectation.fulfill()
    }.resume()

    wait(for: [expectation], timeout: 2)
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
