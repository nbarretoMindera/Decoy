import Apollo
import ApolloAPI
import Foundation
import XCTest
@testable import Decoy
@testable import DecoyApollo
import DecoyTestHelpers

final class DecoyInterceptorTests: XCTestCase {
  private var sut: DecoyInterceptor!
  private var decoy: Decoy!

  override func setUp() {
    super.setUp()

    let processInfo = MockProcessInfo()
    processInfo.mockedIsRunningXCUI = true

    decoy = Decoy(processInfo: processInfo)
    sut = DecoyInterceptor(decoy: decoy)
  }

  override func tearDown() {
    sut = nil
    decoy = nil
    super.tearDown()
  }

  func test_id() {
    XCTAssertEqual(sut.id, "DecoyInterceptor")
  }

  func test_interceptAsync_shouldFail_whenRequestCannotBeConvertedToURLRequest() {
    let exp = expectation(description: "Completion")

    sut.interceptAsync(chain: MockChain(), request: badHTTPRequest, response: nil) { result in
      if case .success = result { return XCTFail("Should've failed.") }
      exp.fulfill()
    }
    wait(for: [exp], timeout: 1)
  }
}

private extension DecoyInterceptorTests {
  var badHTTPRequest: BadHTTPRequest<MockGraphQLOperation> {
    BadHTTPRequest(
      graphQLEndpoint: URL(string: "💩")!,
      operation: MockGraphQLOperation(),
      contentType: "A",
      clientName: "B",
      clientVersion: "C",
      additionalHeaders: [:]
    )
  }

  var goodHTTPRequest: HTTPRequest<MockGraphQLOperation> {
    Apollo.HTTPRequest(
      graphQLEndpoint: URL(string: "https://totally.real/endpoint")!,
      operation: MockGraphQLOperation(),
      contentType: "A",
      clientName: "B",
      clientVersion: "C",
      additionalHeaders: [:]
    )
  }
}

