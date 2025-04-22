@testable import Decoy
import DecoyTestHelpers
import XCTest

class DecoyURLProtocolTests: XCTestCase {
  let decoyModeKey = Decoy.Constants.mode
  var decoy: Decoy!

  override func setUp() {
    super.setUp()

    let mockProcessInfo = MockProcessInfo()
    mockProcessInfo.mockedEnvironment?[Decoy.Constants.mode] = "record"
    mockProcessInfo.mockedIsRunningXCUI = true

    self.decoy = Decoy(processInfo: mockProcessInfo, recorder: MockRecorder())
    DecoyURLProtocol.register(decoy: decoy)

    URLSessionConfiguration.default.protocolClasses = [MockLiveURLProtocol.self, DecoyURLProtocol.self]
    URLProtocol.registerClass(MockLiveURLProtocol.self)
  }

  override func tearDown() {
    URLProtocol.unregisterClass(MockLiveURLProtocol.self)
    DecoyURLProtocol.reset()
    super.tearDown()
  }

  func test_canInitAndCanonicalRequest() {
    let request = URLRequest(url: URL(string: "https://example.com")!)
    XCTAssert(DecoyURLProtocol.canInit(with: request))
    let canonical = DecoyURLProtocol.canonicalRequest(for: request)
    XCTAssertEqual(canonical, request)
  }

  func test_nilURL() {
    var request = URLRequest(url: URL(string: "https://example.com")!)
    request.url = nil
    let client = FakeURLProtocolClient()
    let protocolInstance = DecoyURLProtocol(request: request, cachedResponse: nil, client: client)

    protocolInstance.startLoading()

    XCTAssertNotNil(client.receivedError)
    if let error = client.receivedError as? URLError {
      XCTAssertEqual(error.code, .badURL)
    }
  }

  func test_handleMockResponse() {
    let url = URL(string: "https://example.com/mock")!
    let expectedData = "mock data".data(using: .utf8)
    let expectedResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
    let stubResponse = Stub.Response(data: expectedData, urlResponse: expectedResponse, error: nil)

    decoy.queue.queuedResponses[.url(url)] = [stubResponse]

    let testRecorder = decoy.recorder as! MockRecorder
    testRecorder.mockedShouldRecord = true

    let request = URLRequest(url: url)
    let client = FakeURLProtocolClient()
    let protocolInstance = DecoyURLProtocol(request: request, cachedResponse: nil, client: client)

    protocolInstance.startLoading()

    XCTAssertEqual(client.loadedData, expectedData)
    XCTAssertNotNil(client.receivedResponse)

    if let httpResponse = client.receivedResponse as? HTTPURLResponse {
      XCTAssertEqual(httpResponse.statusCode, 200)
    }
    XCTAssert(client.finishLoadingCalled)

    XCTAssertEqual(testRecorder.recordCallCount, 1)
  }

  func test_sendForceOfflineError() {
    let url = URL(string: "https://example.com/offline")!
    let request = URLRequest(url: url)

    let mockProcessInfo = MockProcessInfo()
    mockProcessInfo.mockedIsRunningXCUI = true
    mockProcessInfo.mockedEnvironment = [Decoy.Constants.mode: "forceOffline"]

    let decoy = Decoy(processInfo: mockProcessInfo)
    decoy.queue.queuedResponses[.url(url)] = nil
    DecoyURLProtocol.register(decoy: decoy)

    let client = FakeURLProtocolClient()
    let protocolInstance = DecoyURLProtocol(request: request, cachedResponse: nil, client: client)

    protocolInstance.startLoading()

    XCTAssertNotNil(client.receivedError)
    if let nsError = client.receivedError as NSError? {
      XCTAssertEqual(nsError.domain, "DecoyErrorDomain")
      XCTAssertEqual(nsError.code, -1)
      XCTAssert(nsError.localizedDescription.contains("No mock available for URL"))
    }
  }
}
